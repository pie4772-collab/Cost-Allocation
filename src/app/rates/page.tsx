"use client";

import { useEffect, useState, useCallback } from "react";
import { PageHeader, StatusBadge, LoadingState } from "@/components/ui/common";
import { ProcessSteps } from "@/components/ui/process-steps";
import { ProjectBanner, ProjectRequired } from "@/components/ui/project-banner";
import { useProjectId, previousImportLabel } from "@/lib/use-project-id";
import { cn, formatPercent } from "@/lib/utils";
import { apiFetch } from "@/lib/api-fetch";
import { requiresExactRateTotal, projectTypeLabel } from "@/lib/period-utils";
import {
  isRateTotalAcceptable,
  isRateOverExcessAcceptable,
  RATE_OVER_TOLERANCE,
} from "@/lib/math";
import { rateReconciliationCompanyLabel } from "@/lib/rate-reconciliation";

interface RateRow {
  id: string;
  companyId: string;
  rate: string;
  company: {
    id: string;
    code: string;
    nameKo: string;
    companyType: string;
  };
}

interface RateVersion {
  id: string;
  version: number;
  status: string;
  totalRate: string;
  rates: RateRow[];
  project?: {
    strictRateValidation: boolean;
    status?: string;
    period?: { label: string };
  };
}

interface CompanyOption {
  id: string;
  code: string;
  nameKo: string;
  companyType: string;
}

interface PreviousRateSource {
  available: boolean;
  periodLabel?: string;
  projectName?: string;
  rateVersionStatus?: string;
  companyCount?: number;
  totalRate?: number;
  message?: string;
}

export default function RatesPage() {
  const { projectId, project, loading: projectLoading, projectRevision } = useProjectId();
  const [versions, setVersions] = useState<RateVersion[]>([]);
  const [allCompanies, setAllCompanies] = useState<CompanyOption[]>([]);
  const [loading, setLoading] = useState(true);
  const [editRates, setEditRates] = useState<Record<string, string>>({});
  const [editCell, setEditCell] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [addCompanyId, setAddCompanyId] = useState("");
  const [actionError, setActionError] = useState("");
  const [previousSource, setPreviousSource] = useState<PreviousRateSource | null>(null);

  const load = useCallback(async () => {
    if (!projectId) { setLoading(false); return; }
    const [rateRes, compRes, prevRes] = await Promise.all([
      fetch(`/api/allocation-rates?projectId=${projectId}`, { credentials: "include" }),
      fetch("/api/companies", { credentials: "include" }),
      fetch(`/api/allocation-rates?projectId=${projectId}&previousSource=true`, { credentials: "include" }),
    ]);
    const data = await rateRes.json();
    setVersions(data);
    setAllCompanies(await compRes.json());
    setPreviousSource(await prevRes.json());
    if (data[0]) {
      const map: Record<string, string> = {};
      for (const r of data[0].rates) {
        map[r.companyId] = (parseFloat(r.rate) * 100).toFixed(6);
      }
      setEditRates(map);
    }
    setLoading(false);
  }, [projectId]);

  useEffect(() => { load(); }, [load, projectRevision]);

  const version = versions[0];
  const strictValidation = requiresExactRateTotal({
    strictRateValidation: version?.project?.strictRateValidation,
    period: project?.period ?? version?.project?.period,
  });
  const totalPercent = Object.values(editRates).reduce(
    (s, r) => s + parseFloat(r || "0"),
    0
  );
  const isExactValid = Math.abs(totalPercent - 100) < 0.000001;
  const isOverExcessAcceptable = isRateOverExcessAcceptable(totalPercent);
  const isValid = isRateTotalAcceptable(totalPercent);
  const canConfirm = strictValidation ? isValid : true;
  const isConfirmed = version?.status === "APPROVED";
  const isEditable = version?.status === "DRAFT" || version?.status === "PENDING_APPROVAL";
  const projectLocked =
    !!project?.status &&
    !["DRAFT", "COST_CONFIRMED", "RATES_APPROVED"].includes(project.status);
  const canImportPrevious =
    previousSource?.available && !projectLocked && isEditable;

  const saveRates = async () => {
    if (!version) return;
    setSaving(true);
    setActionError("");
    try {
      const rates = Object.entries(editRates).map(([companyId, pct]) => ({
        companyId,
        rate: parseFloat(pct) / 100,
      }));
      const res = await apiFetch("/api/allocation-rates", {
        method: "PATCH",
        body: JSON.stringify({
          rateVersionId: version.id,
          action: "update_rates",
          rates,
        }),
      });
      if (!res.ok) {
        const d = await res.json().catch(() => ({}));
        throw new Error((d as { error?: string }).error ?? "저장 실패");
      }
      await load();
    } catch (e) {
      setActionError(e instanceof Error ? e.message : "저장 실패");
    } finally {
      setSaving(false);
    }
  };

  const confirmRates = async () => {
    if (!version || !canConfirm) return;
    setSaving(true);
    setActionError("");
    try {
      await saveRates();
      const res = await apiFetch("/api/allocation-rates", {
        method: "PATCH",
        body: JSON.stringify({ rateVersionId: version.id, action: "confirm" }),
      });
      if (!res.ok) {
        const d = await res.json().catch(() => ({}));
        throw new Error((d as { error?: string }).error ?? "확정 실패");
      }
      await load();
    } catch (e) {
      setActionError(e instanceof Error ? e.message : "확정 실패");
    } finally {
      setSaving(false);
    }
  };

  const importPreviousRates = async () => {
    if (!version || !previousSource?.available) return;
    const msg =
      `${previousSource.periodLabel} (${previousSource.projectName}) 배분율 ` +
      `${previousSource.companyCount}개 법인, 합계 ${previousSource.totalRate?.toFixed(6)}%를 ` +
      `현재 반기에 불러옵니다. 기존 입력값은 덮어씁니다. 계속하시겠습니까?`;
    if (!confirm(msg)) return;

    setSaving(true);
    setActionError("");
    try {
      const res = await apiFetch("/api/allocation-rates", {
        method: "PATCH",
        body: JSON.stringify({
          rateVersionId: version.id,
          action: "import_previous",
        }),
      });
      if (!res.ok) {
        const d = await res.json().catch(() => ({}));
        throw new Error((d as { error?: string }).error ?? "불러오기 실패");
      }
      await load();
    } catch (e) {
      setActionError(e instanceof Error ? e.message : "불러오기 실패");
    } finally {
      setSaving(false);
    }
  };

  const reopenRates = async () => {
    if (!version) return;
    setSaving(true);
    setActionError("");
    try {
      const res = await apiFetch("/api/allocation-rates", {
        method: "PATCH",
        body: JSON.stringify({ rateVersionId: version.id, action: "reopen" }),
      });
      if (!res.ok) {
        const d = await res.json().catch(() => ({}));
        throw new Error((d as { error?: string }).error ?? "수정 모드 전환 실패");
      }
      await load();
    } catch (e) {
      setActionError(e instanceof Error ? e.message : "수정 모드 전환 실패");
    } finally {
      setSaving(false);
    }
  };

  const addCompanyToRates = async () => {
    if (!version || !addCompanyId) return;
    await apiFetch("/api/allocation-rates", {
      method: "PATCH",
      body: JSON.stringify({
        rateVersionId: version.id,
        action: "add_company",
        companyId: addCompanyId,
      }),
    });
    setAddCompanyId("");
    load();
  };

  const updateRate = (companyId: string, value: string) => {
    setEditRates((prev) => ({ ...prev, [companyId]: value }));
  };

  if (projectLoading) return <LoadingState />;

  const includedIds = new Set(version?.rates.map((r) => r.companyId) ?? []);
  const missingCompanies = allCompanies.filter((c) => !includedIds.has(c.id));

  return (
    <>
      <ProjectBanner />
      <ProcessSteps current={2} />

      <ProjectRequired projectId={projectId}>
      {loading ? (
        <LoadingState />
      ) : (
        <>
      <PageHeader
        title="② 배분율 입력"
        description="각 계열사(법인)별 배분율을 입력하고 확정합니다"
        actions={
          <>
            {canImportPrevious && (
              <button
                onClick={importPreviousRates}
                className="btn-secondary"
                disabled={saving}
                title={`${previousSource!.periodLabel} 배분율 불러오기`}
              >
                {previousImportLabel(project?.period ?? null)}
              </button>
            )}
            {isEditable && (
              <button onClick={saveRates} className="btn-secondary" disabled={saving}>
                {saving ? "저장 중..." : "저장"}
              </button>
            )}
            {isEditable && (
              <button onClick={confirmRates} className="btn-primary" disabled={!canConfirm || saving}>
                배분율 확정
              </button>
            )}
            {isConfirmed && !projectLocked && (
              <button onClick={reopenRates} className="btn-secondary" disabled={saving}>
                수정하기
              </button>
            )}
          </>
        }
      />

      {actionError && (
        <div className="mb-4 card border-red-300 bg-red-50 text-red-700 text-sm">{actionError}</div>
      )}

      {version && (
        <div className="mb-4 flex items-center gap-4">
          <StatusBadge status={version.status} />
          <span className="text-sm text-navy-500">버전 {version.version}</span>
          <span className="text-sm text-navy-500">법인 {version.rates.length}개</span>
          {version.project?.period && (
            <span className="text-sm text-navy-500">{version.project.period.label}</span>
          )}
        </div>
      )}

      {canImportPrevious && (
        <div className="mb-4 card border-navy-200 bg-navy-50 text-navy-700 text-sm">
          <strong>{previousSource!.periodLabel}</strong> ({previousSource!.projectName}) 배분율을 불러올 수 있습니다
          — {previousSource!.companyCount}개 법인, 합계 {previousSource!.totalRate?.toFixed(6)}%
          {previousSource!.rateVersionStatus === "APPROVED" ? " (확정본)" : ""}
        </div>
      )}

      {previousSource?.available && isConfirmed && !projectLocked && (
        <div className="mb-4 card border-orange-200 bg-orange-50 text-orange-800 text-sm">
          이전 반기({previousSource.periodLabel}) 배분율을 불러오려면 「수정하기」를 먼저 누르세요.
        </div>
      )}

      {isEditable && previousSource && !previousSource.available && (
        <div className="mb-4 card border-gray-200 bg-gray-50 text-gray-600 text-sm">
          {previousSource.message ?? "불러올 이전 반기 배분율이 없습니다."}
        </div>
      )}

      {isConfirmed && (
        <div className="mb-4 card border-blue-300 bg-blue-50 text-blue-800 text-sm">
          배분율이 확정되었습니다. 수정이 필요하면 「수정하기」를 누르세요.
        </div>
      )}
      {projectLocked && (
        <div className="mb-4 card border-gray-300 bg-gray-50 text-gray-700 text-sm">
          배분 계산이 진행되어 배분율을 수정할 수 없습니다.
        </div>
      )}

      {isEditable && missingCompanies.length > 0 && (
        <div className="card mb-4 flex flex-wrap gap-3 items-end">
          <div>
            <label className="text-xs text-navy-500 block mb-1">배분 대상 법인 추가</label>
            <select className="input" value={addCompanyId} onChange={(e) => setAddCompanyId(e.target.value)}>
              <option value="">선택...</option>
              {missingCompanies.map((c) => (
                <option key={c.id} value={c.id}>{c.nameKo} ({c.code})</option>
              ))}
            </select>
          </div>
          <button onClick={addCompanyToRates} className="btn-secondary" disabled={!addCompanyId}>
            추가
          </button>
        </div>
      )}

      <div className="card overflow-x-auto">
        <table className="data-table">
          <thead>
            <tr>
              <th>No.</th>
              <th>법인명</th>
              <th>구분</th>
              <th className="text-right">배분율 (%)</th>
            </tr>
          </thead>
          <tbody>
            {version?.rates.map((r, idx) => (
              <tr key={r.id}>
                <td>{idx + 1}</td>
                <td>{r.company.nameKo}</td>
                <td>
                  <span className={r.company.companyType === "OVERSEAS" ? "text-orange-600" : "text-green-700"}>
                    {r.company.companyType === "OVERSEAS" ? "해외" : "국내"}
                  </span>
                </td>
                <td
                  className={cn("text-right font-mono min-w-[120px]", isEditable && "cursor-pointer hover:bg-navy-100")}
                  onClick={() => isEditable && setEditCell(r.companyId)}
                >
                  {editCell === r.companyId && isEditable ? (
                    <input
                      className="input text-right w-full font-mono"
                      value={editRates[r.companyId] ?? ""}
                      onChange={(e) => updateRate(r.companyId, e.target.value.replace(/[^0-9.]/g, ""))}
                      onBlur={() => { setEditCell(null); saveRates(); }}
                      onKeyDown={(e) => {
                        if (e.key === "Enter") { setEditCell(null); saveRates(); }
                      }}
                      autoFocus
                    />
                  ) : (
                    editRates[r.companyId] ?? formatPercent(parseFloat(r.rate))
                  )}
                </td>
              </tr>
            ))}
          </tbody>
          <tfoot>
            <tr className="font-bold text-base">
              <td colSpan={3}>합계</td>
              <td className={cn("text-right font-mono", isValid ? "text-green-600" : strictValidation ? "text-red-600" : "text-orange-600")}>
                {totalPercent.toFixed(6)}%
              </td>
            </tr>
          </tfoot>
        </table>
      </div>

      {!strictValidation && !isValid && (
        <div className="mt-4 card border-orange-300 bg-orange-50 text-orange-800 text-sm">
          {version?.project?.period?.label ?? "해당 기간"}(
          {projectTypeLabel(project?.period ?? version?.project?.period)}
          )은 배분율 합계 {totalPercent.toFixed(6)}%를 그대로 확정·배분할 수 있습니다.
        </div>
      )}
      {strictValidation && !isValid && (
        <div className="mt-4 card border-red-300 bg-red-50 text-red-700 text-sm">
          배분율 합계가 {totalPercent.toFixed(6)}%입니다. 정확히 100.000000%이거나 100% 초과 {RATE_OVER_TOLERANCE}% 이내여야 확정할 수 있습니다.
        </div>
      )}
      {strictValidation && isOverExcessAcceptable && isEditable && (
        <div className="mt-4 card border-amber-300 bg-amber-50 text-amber-900 text-sm">
          배분율 합계 {totalPercent.toFixed(6)}% (100% 초과 {(totalPercent - 100).toFixed(6)}%) — 확정 가능.
          배분 계산 시 원가 총액과 배분액 차이는 {rateReconciliationCompanyLabel()} 비용으로 합산·차감됩니다.
        </div>
      )}
      {isExactValid && isEditable && (
        <div className="mt-4 card border-green-300 bg-green-50 text-green-700 text-sm">
          배분율 합계 100.000000% — 확정 가능
        </div>
      )}
        </>
      )}
      </ProjectRequired>
    </>
  );
}

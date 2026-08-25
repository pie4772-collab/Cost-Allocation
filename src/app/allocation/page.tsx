"use client";

import { useEffect, useState, useCallback } from "react";
import { PageHeader, AmountCell, LoadingState } from "@/components/ui/common";
import { ProcessSteps } from "@/components/ui/process-steps";
import { ProjectBanner, ProjectRequired } from "@/components/ui/project-banner";
import { useProjectId, projectHref } from "@/lib/use-project-id";
import { apiJson } from "@/lib/api-fetch";
import { formatAmount } from "@/lib/utils";

type RunData = {
  id: string;
  status: string;
  runType: string;
  totalCost: string;
  totalAllocated: string;
  totalMarkup: string;
  totalBilling: string;
  summaries: Array<{
    company: { code: string; nameKo: string; companyType: string };
    allocationAmount: string;
    markupAmount: string;
    billingAmount: string;
  }>;
  details: Array<{
    companyId: string;
    costAccountId: string;
    allocatedAmount: string;
    company: { nameKo: string };
    costAccount: { nameKo: string };
  }>;
};

export default function AllocationPage() {
  const {
    projectId,
    project,
    loading: projectLoading,
    projectRevision,
    refreshSelectedProject,
  } = useProjectId();
  const [run, setRun] = useState<RunData | null>(null);
  const [loading, setLoading] = useState(true);
  const [executing, setExecuting] = useState(false);
  const [cancelling, setCancelling] = useState(false);
  const [error, setError] = useState("");
  const [selectedCompany, setSelectedCompany] = useState<string | null>(null);

  const loadRun = useCallback(async () => {
    if (!projectId) {
      setLoading(false);
      return;
    }
    setLoading(true);
    setError("");
    try {
      const data = await apiJson<RunData | null>(
        `/api/allocation-runs?projectId=${projectId}&latest=true`
      );
      setRun(data);
    } catch (e) {
      setError(e instanceof Error ? e.message : "배부 결과 로드 실패");
      setRun(null);
    } finally {
      setLoading(false);
    }
  }, [projectId]);

  useEffect(() => { loadRun(); }, [loadRun, projectRevision]);

  const executeRun = async (runType: "PREVIEW" | "FINAL") => {
    if (!projectId) return;
    setExecuting(true);
    setError("");
    try {
      const rates = await apiJson<Array<{ id: string; status: string }>>(
        `/api/allocation-rates?projectId=${projectId}`
      );
      if (!rates[0]) throw new Error("배분율 버전이 없습니다.");

      const rateVersion =
        runType === "FINAL"
          ? rates.find((r) => r.status === "APPROVED") ?? rates[0]
          : rates[0];

      const result = await apiJson<RunData>("/api/allocation-runs", {
        method: "POST",
        body: JSON.stringify({
          projectId,
          rateVersionId: rateVersion.id,
          runType,
        }),
      });
      await refreshSelectedProject(projectId);
      setRun(result);
    } catch (e) {
      setError(e instanceof Error ? e.message : "배부 실행 실패");
    } finally {
      setExecuting(false);
    }
  };

  const cancelRun = async () => {
    if (!projectId || !run) return;
    const msg =
      run.runType === "FINAL"
        ? "최종 배분 계산 결과를 취소합니다. 연결된 대사·청구(미발행) 데이터도 함께 삭제됩니다. 계속하시겠습니까?"
        : "미리보기 배분 계산 결과를 삭제합니다. 계속하시겠습니까?";
    if (!confirm(msg)) return;

    setCancelling(true);
    setError("");
    try {
      await apiJson("/api/allocation-runs", {
        method: "PATCH",
        body: JSON.stringify({
          projectId,
          action: "cancel",
          runId: run.id,
        }),
      });
      await refreshSelectedProject(projectId);
      setRun(null);
      setSelectedCompany(null);
      await loadRun();
    } catch (e) {
      setError(e instanceof Error ? e.message : "배분 계산 취소 실패");
    } finally {
      setCancelling(false);
    }
  };

  const busy = executing || cancelling;

  if (projectLoading) return <LoadingState />;

  return (
    <>
      <ProjectBanner />
      <ProcessSteps current={3} />

      <ProjectRequired projectId={projectId}>
        <PageHeader
          title="③ 배분 계산"
          description="배분율에 따른 청구 금액 산출 — 계정별 원화 절사(ROUNDDOWN) 후 법인별 10원 절사, 해외법인 5% 마크업. 다음 단계: 절사·대사"
          actions={
            <>
              <button
                onClick={() => executeRun("PREVIEW")}
                className="btn-secondary"
                disabled={busy}
              >
                {executing ? "계산 중..." : "미리보기"}
              </button>
              <button
                onClick={() => executeRun("FINAL")}
                className="btn-primary"
                disabled={busy}
              >
                {executing ? "계산 중..." : "최종 실행"}
              </button>
              {run && (
                <button
                  onClick={cancelRun}
                  className="btn-secondary text-red-700 border-red-300 hover:bg-red-50"
                  disabled={busy}
                >
                  {cancelling ? "취소 중..." : "배분 계산 취소"}
                </button>
              )}
            </>
          }
        />

        {project && (
          <div className="mb-4 text-xs text-navy-500 flex flex-wrap gap-3">
            <span>프로젝트 상태: <strong>{project.status}</strong></span>
            <span>· 미리보기: 입력된 원가 기준</span>
            <span>· 최종 실행: 원가 확정 + 배분율 확정 필요</span>
          </div>
        )}

        {error && (
          <div className="mb-4 card border-red-300 bg-red-50 text-red-700 text-sm">
            {error}
          </div>
        )}

        {loading ? (
          <LoadingState />
        ) : !run ? (
          <div className="card text-navy-500">
            배부 실행 결과가 없습니다. <strong>미리보기</strong>를 눌러 계산하세요.
          </div>
        ) : (
          <>
            <div className="mb-2 text-xs text-navy-500">
              {run.runType === "FINAL" ? "최종" : "미리보기"} 실행 · 상태 {run.status}
            </div>
            <div className="grid grid-cols-4 gap-4 mb-6">
              <div className="card"><p className="text-xs text-navy-500">총 원가</p><p className="text-lg font-bold">{formatAmount(run.totalCost)}</p></div>
              <div className="card"><p className="text-xs text-navy-500">배분비용</p><p className="text-lg font-bold">{formatAmount(run.totalAllocated)}</p></div>
              <div className="card"><p className="text-xs text-navy-500">Mark-up</p><p className="text-lg font-bold">{formatAmount(run.totalMarkup)}</p></div>
              <div className="card"><p className="text-xs text-navy-500">총 청구</p><p className="text-lg font-bold">{formatAmount(run.totalBilling)}</p></div>
            </div>

            <div className="card overflow-x-auto">
              <table className="data-table">
                <thead>
                  <tr>
                    <th>법인</th>
                    <th>구분</th>
                    <th className="text-right">배분비용</th>
                    <th className="text-right">Mark-up</th>
                    <th className="text-right">총 청구금액</th>
                  </tr>
                </thead>
                <tbody>
                  {run.summaries.map((s, i) => (
                    <tr
                      key={i}
                      className="cursor-pointer hover:bg-navy-100"
                      onClick={() => setSelectedCompany(s.company.nameKo)}
                    >
                      <td>{s.company.nameKo}</td>
                      <td>{s.company.companyType === "OVERSEAS" ? "해외" : "국내"}</td>
                      <AmountCell value={s.allocationAmount} />
                      <AmountCell value={s.markupAmount} />
                      <AmountCell value={s.billingAmount} />
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            {run?.runType === "FINAL" && run.status !== "PREVIEW" && projectId && (
              <div className="mt-4 text-sm text-navy-600">
                다음:{" "}
                <a
                  href={projectHref("/reconciliation", projectId)}
                  className="text-navy-900 underline font-medium"
                >
                  ④ 절사·대사
                </a>
              </div>
            )}

            {selectedCompany && (
              <div className="card mt-4">
                <h3 className="font-medium mb-2">{selectedCompany} 계산 근거</h3>
                <table className="data-table">
                  <thead>
                    <tr><th>계정</th><th className="text-right">배부액</th></tr>
                  </thead>
                  <tbody>
                    {run.details
                      .filter((d) => d.company.nameKo === selectedCompany)
                      .map((d, i) => (
                        <tr key={i}>
                          <td>{d.costAccount.nameKo}</td>
                          <AmountCell value={d.allocatedAmount} />
                        </tr>
                      ))}
                  </tbody>
                </table>
              </div>
            )}
          </>
        )}
      </ProjectRequired>
    </>
  );
}

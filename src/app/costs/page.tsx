"use client";

import { useEffect, useState, useCallback, useMemo } from "react";
import { PageHeader, AmountCell, LoadingState, ErrorState, StatusBadge } from "@/components/ui/common";
import { ProcessSteps } from "@/components/ui/process-steps";
import { ProjectBanner, ProjectRequired } from "@/components/ui/project-banner";
import { useProjectId, monthsForProject, halfLabel, costTotalLabel, costGrandTotalLabel, isMonthlyPeriod } from "@/lib/use-project-id";
import { cn, formatAmount } from "@/lib/utils";
import { apiFetch, apiJson } from "@/lib/api-fetch";

interface CostRow {
  id: string;
  month: number;
  amount: string;
  status: string;
  costAccount: { id: string; code: string; nameKo: string; description: string | null };
}

interface Account {
  id: string;
  code: string;
  nameKo: string;
  description: string | null;
  sortOrder: number;
}

const CATEGORIES = ["급상여", "복리후생", "기타"];

interface MonthlyCostSourceInfo {
  available: boolean;
  importableCount: number;
  sources: Array<{
    month: number;
    available: boolean;
    periodLabel: string;
    accountCount: number;
    totalAmount: number;
    message?: string;
  }>;
}

export default function CostsPage() {
  const { projectId, project, loading: projectLoading, projectRevision } = useProjectId();
  const [costs, setCosts] = useState<CostRow[]>([]);
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [editCell, setEditCell] = useState<{ accountId: string; month: number } | null>(null);
  const [editValue, setEditValue] = useState("");
  const [activeMonth, setActiveMonth] = useState<number | "all">("all");
  const [saving, setSaving] = useState(false);
  const [showAddForm, setShowAddForm] = useState(false);
  const [newAccount, setNewAccount] = useState({ nameKo: "", description: "기타" });
  const [actionError, setActionError] = useState("");
  const [projectStatus, setProjectStatus] = useState("DRAFT");
  const [monthlySources, setMonthlySources] = useState<MonthlyCostSourceInfo | null>(null);

  const months = useMemo(() => monthsForProject(project?.period ?? null), [project]);
  const monthly = isMonthlyPeriod(project?.period);
  const isCostConfirmed = projectStatus === "COST_CONFIRMED";
  const isLocked = !["DRAFT", "COST_CONFIRMED"].includes(projectStatus);
  const canEdit = !isLocked;

  const load = useCallback(async () => {
    if (!projectId) {
      setLoading(false);
      return;
    }
    setLoading(true);
    try {
      const [costRes, accRes, srcRes] = await Promise.all([
        fetch(`/api/monthly-costs?projectId=${projectId}`, { credentials: "include" }),
        fetch("/api/cost-accounts", { credentials: "include" }),
        !isMonthlyPeriod(project?.period)
          ? fetch(`/api/monthly-costs?projectId=${projectId}&monthlySources=true`, {
              credentials: "include",
            })
          : Promise.resolve(null),
      ]);
      setCosts(await costRes.json());
      setAccounts(await accRes.json());
      if (srcRes) {
        setMonthlySources(await srcRes.json());
      } else {
        setMonthlySources(null);
      }
      if (project?.status) setProjectStatus(project.status);
      else {
        const projs = await fetch("/api/allocation-projects").then((r) => r.json());
        const found = projs.find((p: { id: string }) => p.id === projectId);
        if (found) setProjectStatus(found.status);
      }
    } catch {
      setError("데이터 로드 실패");
    } finally {
      setLoading(false);
    }
  }, [projectId, project?.status, project?.period, projectRevision]);

  useEffect(() => { load(); }, [load]);

  const importFromMonthly = async (months?: number[]) => {
    if (!projectId) return;
    const label = months?.length === 1 ? `${months[0]}월` : "전체 월";
    if (
      !confirm(
        `월별 프로젝트에서 ${label} 원가를 불러옵니다. 해당 월의 기존 반기 입력값은 덮어씁니다. 계속하시겠습니까?`
      )
    ) {
      return;
    }
    setSaving(true);
    setActionError("");
    try {
      const res = await apiFetch("/api/monthly-costs", {
        method: "POST",
        body: JSON.stringify({
          action: "import_from_monthly",
          projectId,
          months,
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

  const reopenCosts = async () => {
    if (!projectId) return;
    setSaving(true);
    setActionError("");
    try {
      await apiJson("/api/invoices", {
        method: "POST",
        body: JSON.stringify({ action: "reopen_costs", projectId }),
      });
      setProjectStatus("DRAFT");
      await load();
    } catch (e) {
      setActionError(e instanceof Error ? e.message : "수정 모드 전환 실패");
    } finally {
      setSaving(false);
    }
  };

  const getAmount = (accountId: string, month: number) => {
    const row = costs.find(
      (c) => c.costAccount.id === accountId && c.month === month
    );
    return row ? Number(row.amount) : 0;
  };

  const getAccountTotal = (accountId: string) =>
    months.reduce((s, m) => s + getAmount(accountId, m), 0);

  const getMonthTotal = (month: number) =>
    accounts.reduce((s, a) => s + getAmount(a.id, month), 0);

  const saveCost = async (accountId: string, month: number, amount: number) => {
    if (!projectId) return;
    setSaving(true);
    setActionError("");
    try {
      await apiFetch("/api/monthly-costs", {
        method: "POST",
        body: JSON.stringify({ projectId, costAccountId: accountId, month, amount }),
      }).then(async (r) => {
        if (!r.ok) {
          const d = await r.json().catch(() => ({}));
          throw new Error((d as { error?: string }).error ?? "저장 실패");
        }
      });
      setEditCell(null);
      await load();
    } catch (e) {
      setActionError(e instanceof Error ? e.message : "저장 실패");
    } finally {
      setSaving(false);
    }
  };

  const confirmCosts = async () => {
    if (!projectId) return;
    setSaving(true);
    setActionError("");
    try {
      await apiJson("/api/invoices", {
        method: "POST",
        body: JSON.stringify({ action: "confirm_costs", projectId }),
      });
      setProjectStatus("COST_CONFIRMED");
      await load();
    } catch (e) {
      setActionError(e instanceof Error ? e.message : "원가 확정 실패");
    } finally {
      setSaving(false);
    }
  };

  const addAccount = async () => {
    if (!newAccount.nameKo.trim()) return;
    setSaving(true);
    const res = await fetch("/api/cost-accounts", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(newAccount),
    });
    if (res.ok) {
      setNewAccount({ nameKo: "", description: "기타" });
      setShowAddForm(false);
      load();
    }
    setSaving(false);
  };

  const categories = [...new Set(accounts.map((a) => a.description ?? "기타"))];
  const grandTotal = accounts.reduce((s, a) => s + getAccountTotal(a.id), 0);
  const displayMonths = activeMonth === "all" ? months : [activeMonth];

  if (projectLoading) return <LoadingState />;

  return (
    <>
      <ProjectBanner />
      <ProcessSteps current={1} />

      <ProjectRequired projectId={projectId}>
        {loading ? (
          <LoadingState />
        ) : error ? (
          <ErrorState message={error} />
        ) : (
          <>
            <PageHeader
              title="① 공동비용(원가) 입력"
              description={`${halfLabel(project?.period ?? null)} 실제 발생액을 계정과목별로 입력하고 확정합니다`}
              actions={
                <>
                  <StatusBadge status={projectStatus} />
                  <span className="text-sm text-navy-500 mr-2">
                    {costTotalLabel(project?.period ?? null)}: <strong>{formatAmount(grandTotal)}</strong>원
                  </span>
                  {canEdit && !monthly && monthlySources?.available && (
                    <button
                      onClick={() => importFromMonthly()}
                      className="btn-secondary"
                      disabled={saving}
                    >
                      월별 원가 불러오기
                    </button>
                  )}
                  {canEdit && (
                    <button onClick={() => setShowAddForm((v) => !v)} className="btn-secondary">
                      원가 항목 추가
                    </button>
                  )}
                  {projectStatus === "DRAFT" && (
                    <button onClick={confirmCosts} className="btn-primary" disabled={saving}>
                      원가 확정
                    </button>
                  )}
                  {isCostConfirmed && (
                    <button onClick={reopenCosts} className="btn-secondary" disabled={saving}>
                      수정하기
                    </button>
                  )}
                </>
              }
            />

            {isCostConfirmed && (
              <div className="mb-4 card border-blue-300 bg-blue-50 text-blue-800 text-sm">
                원가가 확정되었습니다. 수정이 필요하면 「수정하기」를 누르세요.
              </div>
            )}
            {isLocked && (
              <div className="mb-4 card border-gray-300 bg-gray-50 text-gray-700 text-sm">
                배분 계산이 진행되어 원가를 수정할 수 없습니다.
              </div>
            )}

            {actionError && (
              <div className="mb-4 card border-red-300 bg-red-50 text-red-700 text-sm">
                {actionError}
              </div>
            )}

            {!monthly && monthlySources && (
              <div className="mb-4 card border-navy-200 bg-navy-50 text-navy-700 text-sm">
                <p className="font-medium mb-2">월별 원가 연동</p>
                <p className="text-xs text-navy-500 mb-2">
                  월별 프로젝트에 입력한 원가를 반기 프로젝트로 불러올 수 있습니다.
                </p>
                <div className="flex flex-wrap gap-2">
                  {monthlySources.sources.map((s) => (
                    <button
                      key={s.month}
                      type="button"
                      disabled={!s.available || !canEdit || saving}
                      onClick={() => importFromMonthly([s.month])}
                      className={cn(
                        "text-xs px-2 py-1 rounded border",
                        s.available
                          ? "border-green-400 bg-green-50 text-green-800 hover:bg-green-100"
                          : "border-gray-200 bg-gray-100 text-gray-400 cursor-not-allowed"
                      )}
                      title={s.message}
                    >
                      {s.month}월
                      {s.available
                        ? ` (${s.accountCount}건 · ${formatAmount(s.totalAmount)}원)`
                        : ` (${s.message ?? "없음"})`}
                    </button>
                  ))}
                </div>
              </div>
            )}

            {showAddForm && (
              <div className="card mb-4">
                <h3 className="text-sm font-semibold mb-3">새 원가 항목</h3>
                <div className="flex flex-wrap gap-3 items-end">
                  <div>
                    <label className="text-xs text-navy-500 block mb-1">계정과목명</label>
                    <input
                      className="input"
                      value={newAccount.nameKo}
                      onChange={(e) => setNewAccount((p) => ({ ...p, nameKo: e.target.value }))}
                      placeholder="예: 교육훈련비"
                    />
                  </div>
                  <div>
                    <label className="text-xs text-navy-500 block mb-1">분류</label>
                    <select
                      className="input"
                      value={newAccount.description}
                      onChange={(e) => setNewAccount((p) => ({ ...p, description: e.target.value }))}
                    >
                      {CATEGORIES.map((c) => (
                        <option key={c} value={c}>{c}</option>
                      ))}
                    </select>
                  </div>
                  <button onClick={addAccount} className="btn-primary" disabled={saving || !newAccount.nameKo.trim()}>
                    추가
                  </button>
                </div>
              </div>
            )}

            {!monthly && (
              <div className="flex gap-1 mb-4 flex-wrap">
                <button
                  className={cn("btn-secondary text-xs px-3 py-1", activeMonth === "all" && "bg-navy-800 text-white")}
                  onClick={() => setActiveMonth("all")}
                >
                  전체
                </button>
                {months.map((m) => (
                  <button
                    key={m}
                    className={cn("btn-secondary text-xs px-3 py-1", activeMonth === m && "bg-navy-800 text-white")}
                    onClick={() => setActiveMonth(m)}
                  >
                    {m}월
                  </button>
                ))}
              </div>
            )}

            {categories.map((cat) => {
              const catAccounts = accounts.filter((a) => (a.description ?? "기타") === cat);
              if (catAccounts.length === 0) return null;
              return (
                <div key={cat} className="card overflow-x-auto mb-4">
                  <h3 className="text-sm font-semibold text-navy-700 mb-2 px-1">{cat}</h3>
                  <table className="data-table">
                    <thead>
                      <tr>
                        <th>계정과목</th>
                        {displayMonths.map((m) => (
                          <th key={m} className="text-right">{String(m).padStart(2, "0")}월</th>
                        ))}
                        {activeMonth === "all" && (
                          <th className="text-right">{costTotalLabel(project?.period ?? null)}</th>
                        )}
                      </tr>
                    </thead>
                    <tbody>
                      {catAccounts.map((account) => (
                        <tr key={account.id}>
                          <td>{account.nameKo}</td>
                          {displayMonths.map((month) => (
                            <td
                              key={month}
                              className={cn(
                                "amount min-w-[100px]",
                                canEdit && "cursor-pointer hover:bg-navy-100"
                              )}
                              onClick={() => {
                                if (!canEdit) return;
                                setEditCell({ accountId: account.id, month });
                                setEditValue(String(getAmount(account.id, month) || ""));
                              }}
                            >
                              {editCell?.accountId === account.id && editCell?.month === month && canEdit ? (
                                <input
                                  className="input text-right w-full"
                                  value={editValue}
                                  onChange={(e) => setEditValue(e.target.value.replace(/[^0-9-]/g, ""))}
                                  onBlur={() => saveCost(account.id, month, parseInt(editValue) || 0)}
                                  onKeyDown={(e) => {
                                    if (e.key === "Enter") saveCost(account.id, month, parseInt(editValue) || 0);
                                    if (e.key === "Tab") e.preventDefault();
                                  }}
                                  autoFocus
                                />
                              ) : (
                                formatAmount(getAmount(account.id, month)) || "0"
                              )}
                            </td>
                          ))}
                          {activeMonth === "all" && (
                            <AmountCell value={getAccountTotal(account.id)} />
                          )}
                        </tr>
                      ))}
                      <tr className="font-bold bg-navy-50">
                        <td>{cat} 소계</td>
                        {displayMonths.map((m) => (
                          <AmountCell
                            key={m}
                            value={catAccounts.reduce((s, a) => s + getAmount(a.id, m), 0)}
                          />
                        ))}
                        {activeMonth === "all" && (
                          <AmountCell value={catAccounts.reduce((s, a) => s + getAccountTotal(a.id), 0)} />
                        )}
                      </tr>
                    </tbody>
                  </table>
                </div>
              );
            })}

            <div className="card">
              <table className="data-table">
                <tbody>
                  <tr className="font-bold text-base">
                    <td>{costGrandTotalLabel(project?.period ?? null)}</td>
                    {activeMonth === "all" ? (
                      <>
                        {months.map((m) => (
                          <AmountCell key={m} value={getMonthTotal(m)} />
                        ))}
                        <AmountCell value={grandTotal} />
                      </>
                    ) : (
                      <AmountCell value={getMonthTotal(activeMonth as number)} />
                    )}
                  </tr>
                </tbody>
              </table>
            </div>
          </>
        )}
      </ProjectRequired>
    </>
  );
}

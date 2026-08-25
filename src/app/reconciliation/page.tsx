"use client";

import { useEffect, useState, useCallback, useMemo } from "react";
import { PageHeader, AmountCell, LoadingState } from "@/components/ui/common";
import { ProcessSteps } from "@/components/ui/process-steps";
import { ProjectBanner, ProjectRequired } from "@/components/ui/project-banner";
import { useProjectId, projectHref } from "@/lib/use-project-id";
import { apiJson } from "@/lib/api-fetch";
import { formatAmount } from "@/lib/utils";

type ReconView = {
  totalSourceCost: string;
  totalAccountAllocated: string;
  accountRoundingDiff: string;
  totalCompanyAllocated: string;
  companyRoundingDiff: string;
  isBalanced: boolean;
  details: Array<{
    name: string;
    sourceTotal: string;
    allocatedSum: string;
    roundingDiff: string;
  }>;
};

type RunDetail = {
  id: string;
  status: string;
  runType: string;
  reconciliation: ReconView | null;
  details: Array<{
    costAccountId: string;
    accountTotal: string;
    allocatedAmount: string;
    costAccount: { nameKo: string };
  }>;
  summaries: Array<{ allocationAmount: string }>;
};

function buildPreviewFromRun(run: RunDetail): ReconView {
  const byAccount = new Map<
    string,
    { name: string; sourceTotal: bigint; allocatedSum: bigint }
  >();

  for (const d of run.details) {
    const existing = byAccount.get(d.costAccountId) ?? {
      name: d.costAccount.nameKo,
      sourceTotal: BigInt(d.accountTotal),
      allocatedSum: 0n,
    };
    existing.allocatedSum += BigInt(d.allocatedAmount);
    byAccount.set(d.costAccountId, existing);
  }

  const details = [...byAccount.values()].map((row) => ({
    name: row.name,
    sourceTotal: row.sourceTotal.toString(),
    allocatedSum: row.allocatedSum.toString(),
    roundingDiff: (row.sourceTotal - row.allocatedSum).toString(),
  }));

  const totalSourceCost = [...byAccount.values()].reduce(
    (s, r) => s + r.sourceTotal,
    0n
  );
  const totalAccountAllocated = run.details.reduce(
    (s, d) => s + BigInt(d.allocatedAmount),
    0n
  );
  const totalCompanyAllocated = run.summaries.reduce(
    (s, srow) => s + BigInt(srow.allocationAmount),
    0n
  );
  const accountRoundingDiff = totalSourceCost - totalAccountAllocated;
  const companyRoundingDiff = totalAccountAllocated - totalCompanyAllocated;

  return {
    totalSourceCost: totalSourceCost.toString(),
    totalAccountAllocated: totalAccountAllocated.toString(),
    accountRoundingDiff: accountRoundingDiff.toString(),
    totalCompanyAllocated: totalCompanyAllocated.toString(),
    companyRoundingDiff: companyRoundingDiff.toString(),
    isBalanced:
      accountRoundingDiff === companyRoundingDiff ||
      Math.abs(Number(accountRoundingDiff)) < 1_000_000,
    details,
  };
}

function normalizeStoredRecon(
  recon: NonNullable<RunDetail["reconciliation"]>
): ReconView {
  const details = (recon.details as Array<Record<string, string>>).map((d) => ({
    name: d.name ?? d.code ?? "—",
    sourceTotal: d.sourceTotal,
    allocatedSum: d.allocatedSum,
    roundingDiff: d.roundingDiff,
  }));
  return { ...recon, details };
}

export default function ReconciliationPage() {
  const {
    projectId,
    project,
    loading: projectLoading,
    projectRevision,
    refreshSelectedProject,
  } = useProjectId();
  const [run, setRun] = useState<RunDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    if (!projectId) {
      setLoading(false);
      return;
    }
    setLoading(true);
    setError("");
    try {
      const runs = await apiJson<
        Array<{ id: string; runType: string; status: string }>
      >(`/api/allocation-runs?projectId=${projectId}`);
      const finalRun = runs.find(
        (r) =>
          r.runType === "FINAL" && ["EXECUTED", "APPROVED"].includes(r.status)
      );
      if (finalRun) {
        const detail = await apiJson<RunDetail>(
          `/api/allocation-runs?runId=${finalRun.id}`
        );
        setRun(detail);
      } else {
        setRun(null);
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : "데이터 로드 실패");
      setRun(null);
    } finally {
      setLoading(false);
    }
  }, [projectId]);

  useEffect(() => {
    load();
  }, [load, projectRevision]);

  const isConfirmed = !!run?.reconciliation;
  const recon = useMemo(() => {
    if (!run) return null;
    if (run.reconciliation) return normalizeStoredRecon(run.reconciliation);
    return buildPreviewFromRun(run);
  }, [run]);

  const reconcile = async () => {
    if (!run || !projectId) return;
    setBusy(true);
    setError("");
    try {
      await apiJson(`/api/allocation-runs/${run.id}/reconcile`, {
        method: "POST",
      });
      await refreshSelectedProject(projectId);
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : "대사 확정 실패");
    } finally {
      setBusy(false);
    }
  };

  const cancelReconciliation = async () => {
    if (!run || !projectId) return;
    if (
      !confirm(
        "절사·대사 확정을 취소합니다. 연결된 청구서(미발행)도 함께 삭제됩니다. 배분 계산 결과는 유지됩니다. 계속하시겠습니까?"
      )
    ) {
      return;
    }
    setBusy(true);
    setError("");
    try {
      await apiJson(`/api/allocation-runs/${run.id}/reconcile`, {
        method: "DELETE",
      });
      await refreshSelectedProject(projectId);
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : "절사·대사 취소 실패");
    } finally {
      setBusy(false);
    }
  };

  if (projectLoading) return <LoadingState />;

  return (
    <>
      <ProjectBanner />
      <ProcessSteps current={4} />

      <ProjectRequired projectId={projectId}>
        <PageHeader
          title="④ 절사·대사"
          description="배분 계산 후 계정별·법인별 ROUNDDOWN 절사 차이를 확인하고 확정합니다. 다음 단계: 청구서 작성"
          actions={
            run ? (
              isConfirmed ? (
                <button
                  onClick={cancelReconciliation}
                  className="btn-secondary text-red-700 border-red-300 hover:bg-red-50"
                  disabled={busy}
                >
                  {busy ? "처리 중..." : "절사·대사 취소"}
                </button>
              ) : (
                <button
                  onClick={reconcile}
                  className="btn-primary"
                  disabled={busy}
                >
                  {busy ? "처리 중..." : "대사 확정"}
                </button>
              )
            ) : undefined
          }
        />

        {project && (
          <div className="mb-4 text-xs text-navy-500">
            프로젝트 상태: <strong>{project.status}</strong>
            {isConfirmed && (
              <span className="ml-2 text-green-700">· 절사·대사 확정됨</span>
            )}
          </div>
        )}

        {error && (
          <div className="mb-4 card border-red-300 bg-red-50 text-red-700 text-sm">
            {error}
          </div>
        )}

        {loading ? (
          <LoadingState />
        ) : !run || !recon ? (
          <div className="card text-navy-500">
            최종 배분 계산 후 절사·대사를 진행할 수 있습니다.{" "}
            {projectId && (
              <a
                href={projectHref("/allocation", projectId)}
                className="text-navy-800 underline"
              >
                배분 계산으로 이동
              </a>
            )}
          </div>
        ) : (
          <>
            {!isConfirmed && (
              <div className="mb-4 card border-amber-300 bg-amber-50 text-amber-900 text-sm">
                아래는 배분 계산 결과 기준 미리보기입니다. <strong>대사 확정</strong> 후
                청구서를 생성할 수 있습니다.
              </div>
            )}

            <div className="grid grid-cols-3 gap-4 mb-6">
              <div className="card">
                <p className="text-xs text-navy-500">원가 합계</p>
                <p className="text-lg font-bold">
                  {formatAmount(recon.totalSourceCost)}
                </p>
              </div>
              <div className="card">
                <p className="text-xs text-navy-500">계정 절사차</p>
                <p className="text-lg font-bold">
                  {formatAmount(recon.accountRoundingDiff)}
                </p>
              </div>
              <div className="card">
                <p className="text-xs text-navy-500">법인 절사차</p>
                <p className="text-lg font-bold">
                  {formatAmount(recon.companyRoundingDiff)}
                </p>
              </div>
            </div>

            <div className="card overflow-x-auto">
              <table className="data-table">
                <thead>
                  <tr>
                    <th>계정과목</th>
                    <th className="text-right">원가</th>
                    <th className="text-right">배분합</th>
                    <th className="text-right">절사차</th>
                  </tr>
                </thead>
                <tbody>
                  {recon.details.map((d, i) => (
                    <tr key={i}>
                      <td>{d.name}</td>
                      <AmountCell value={d.sourceTotal} />
                      <AmountCell value={d.allocatedSum} />
                      <AmountCell value={d.roundingDiff} />
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            {isConfirmed && projectId && (
              <div className="mt-4 text-sm text-navy-600">
                다음:{" "}
                <a
                  href={projectHref("/invoices", projectId)}
                  className="text-navy-900 underline font-medium"
                >
                  ⑤ 청구서 작성
                </a>
              </div>
            )}
          </>
        )}
      </ProjectRequired>
    </>
  );
}

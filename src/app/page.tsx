"use client";

import { useEffect, useState, useCallback } from "react";
import Link from "next/link";
import {
  PageHeader,
  MetricCard,
  StatusBadge,
  ErrorState,
  LoadingState,
} from "@/components/ui/common";
import { ProjectBanner, ProjectRequired } from "@/components/ui/project-banner";
import { useProjectId, projectHref, projectListPath } from "@/lib/use-project-id";
import { apiJson } from "@/lib/api-fetch";
import { formatAmount } from "@/lib/utils";

type DashboardData = {
  project: {
    id: string;
    name: string;
    status: string;
    period: { label: string; cadence?: string };
  } | null;
  metrics: {
    totalCost: string;
    companyCount: number;
    overseasCount: number;
    totalMarkup: string;
    totalBilling: string;
    rateTotal: number;
    rateValid: boolean;
    roundingDiffAbs: string;
    errorCount: number;
    pendingIssue: number;
  };
  storyInBrief: string;
};

export default function DashboardPage() {
  const {
    projectId,
    project,
    loading: projectLoading,
    projectRevision,
  } = useProjectId();
  const [data, setData] = useState<DashboardData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    if (!projectId) {
      setData(null);
      setLoading(false);
      return;
    }
    setLoading(true);
    setError("");
    try {
      const result = await apiJson<DashboardData>(
        `/api/dashboard?projectId=${projectId}`
      );
      setData(result);
    } catch (e) {
      setError(e instanceof Error ? e.message : "대시보드 로드 실패");
      setData(null);
    } finally {
      setLoading(false);
    }
  }, [projectId]);

  useEffect(() => {
    load();
  }, [load, projectRevision]);

  if (projectLoading) return <LoadingState />;

  if (error && !data) {
    return (
      <>
        <ProjectBanner />
        <PageHeader title="대시보드" description="KBI 그룹 공동비용 배부 현황" />
        <ErrorState message={error} />
      </>
    );
  }

  const metrics = data?.metrics;
  const storyInBrief = data?.storyInBrief;
  const alerts: Array<{ level: "danger" | "warning"; text: string }> = [];

  if (metrics && !metrics.rateValid) {
    alerts.push({
      level: "danger",
      text: `배분율 합계 ${metrics.rateTotal.toFixed(6)}% — 100%가 아니면 배분 계산·청구 발행 불가`,
    });
  }
  if (metrics && metrics.pendingIssue > 0) {
    alerts.push({
      level: "warning",
      text: `발행 대기 청구서 ${metrics.pendingIssue}건`,
    });
  }

  const listPath = projectListPath(project?.period ?? null);

  return (
    <>
      <ProjectBanner />

      <PageHeader
        title="대시보드"
        description={
          project
            ? `선택 프로젝트 기준 — ${project.name} (${project.period.label})`
            : "KBI 그룹 공동비용 배부 현황"
        }
        actions={
          projectId && (
            <Link href={projectHref("/costs", projectId)} className="btn-primary">
              원가 입력
            </Link>
          )
        }
      />

      <ProjectRequired projectId={projectId}>
        {loading ? (
          <LoadingState />
        ) : !metrics || !storyInBrief ? (
          <ErrorState message="대시보드 데이터를 불러올 수 없습니다." />
        ) : (
          <>
            <div className="card mb-6 bg-navy-800 text-white">
              <h2 className="text-sm font-medium text-navy-200">Story in Brief</h2>
              <p className="mt-1">{storyInBrief}</p>
              {project && (
                <p className="text-sm text-navy-300 mt-2">
                  상태: <StatusBadge status={project.status} />
                </p>
              )}
              <p className="text-xs text-navy-400 mt-2">
                사이드바·프로젝트 배너에서 선택한 프로젝트 기준입니다.{" "}
                <Link href={listPath} className="underline text-navy-200">
                  프로젝트 변경
                </Link>
              </p>
            </div>

            {alerts.length > 0 && (
              <div className="space-y-2 mb-6">
                {alerts.map((a, i) => (
                  <div
                    key={i}
                    className={`card text-sm ${
                      a.level === "danger"
                        ? "border-red-300 bg-red-50 text-red-800"
                        : "border-orange-300 bg-orange-50 text-orange-800"
                    }`}
                  >
                    {a.text}
                  </div>
                ))}
              </div>
            )}

            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
              <MetricCard
                label="배부 대상 공동비용"
                value={`${formatAmount(metrics.totalCost)}원`}
              />
              <MetricCard
                label="배부 대상 법인 수"
                value={String(metrics.companyCount)}
                sub={`해외 ${metrics.overseasCount}개`}
              />
              <MetricCard
                label="해외 Mark-up 합계"
                value={`${formatAmount(metrics.totalMarkup)}원`}
              />
              <MetricCard
                label="총 청구 예정액"
                value={`${formatAmount(metrics.totalBilling)}원`}
              />
              <MetricCard
                label="배분율 합계"
                value={`${metrics.rateTotal.toFixed(6)}%`}
                variant={metrics.rateValid ? "success" : "danger"}
              />
              <MetricCard
                label="절사차이 절대합"
                value={`${formatAmount(metrics.roundingDiffAbs)}원`}
              />
              <MetricCard
                label="오류·발행대기"
                value={`${metrics.errorCount} / ${metrics.pendingIssue}`}
                variant={metrics.errorCount > 0 ? "danger" : "default"}
              />
            </div>
          </>
        )}
      </ProjectRequired>
    </>
  );
}

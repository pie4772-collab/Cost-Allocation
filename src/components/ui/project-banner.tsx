"use client";

import Link from "next/link";
import { useProjectContext } from "@/lib/project-context";
import { projectHref, projectListPath, isMonthlyPeriod } from "@/lib/use-project-id";
import { StatusBadge } from "./common";

export function ProjectBanner() {
  const { selectedProject } = useProjectContext();
  const listPath = projectListPath(selectedProject?.period ?? null);

  if (!selectedProject) {
    return (
      <div className="mb-4 card border-amber-300 bg-amber-50 text-amber-900 text-sm flex items-center justify-between gap-4">
        <span>작업할 프로젝트를 먼저 선택하세요 (월별 또는 반기).</span>
        <div className="flex gap-2">
          <Link href="/monthly-projects" className="btn-secondary text-xs whitespace-nowrap">
            월별 프로젝트
          </Link>
          <Link href="/projects" className="btn-secondary text-xs whitespace-nowrap">
            반기 프로젝트
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="mb-4 card bg-navy-50 border-navy-200 flex flex-wrap items-center justify-between gap-3 py-3">
      <div className="flex flex-wrap items-center gap-3">
        <span className="text-xs text-navy-500">
          {isMonthlyPeriod(selectedProject.period) ? "월별 프로젝트" : "반기 프로젝트"}
        </span>
        <span className="font-semibold text-navy-900">{selectedProject.name}</span>
        <span className="text-sm text-navy-600">{selectedProject.period.label}</span>
        <StatusBadge status={selectedProject.status} />
      </div>
      <Link href={listPath} className="text-xs text-navy-600 hover:underline">
        프로젝트 변경
      </Link>
    </div>
  );
}

export function ProjectRequired({
  projectId,
  children,
}: {
  projectId: string | null;
  children: React.ReactNode;
}) {
  if (projectId) return <>{children}</>;

  return (
    <div className="card text-center py-12">
      <p className="text-navy-600 mb-4">프로젝트를 선택해야 이 단계를 진행할 수 있습니다.</p>
      <div className="flex justify-center gap-3">
        <Link href="/monthly-projects" className="btn-primary">
          월별 프로젝트
        </Link>
        <Link href="/projects" className="btn-secondary">
          반기 프로젝트
        </Link>
      </div>
    </div>
  );
}

export { projectHref };

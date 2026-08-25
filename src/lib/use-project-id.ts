"use client";

import { useEffect, useState } from "react";
import { usePathname } from "next/navigation";
import { useProjectContext, type SelectedProject } from "@/lib/project-context";
import {
  monthsForPeriod,
  periodScopeLabel,
  costTotalLabel,
  costGrandTotalLabel,
  isMonthlyPeriod,
  projectListPath,
  type PeriodInfo,
} from "@/lib/period-utils";

export {
  monthsForPeriod as monthsForProject,
  periodScopeLabel as halfLabel,
  costTotalLabel,
  costGrandTotalLabel,
  isMonthlyPeriod,
  projectListPath,
};

export function previousImportLabel(period: PeriodInfo | null | undefined): string {
  return isMonthlyPeriod(period) ? "이전 월 불러오기" : "이전 반기 불러오기";
}

/** URL projectId 우선, 없으면 선택된 프로젝트 사용 */
export function useProjectId(): {
  projectId: string | null;
  project: SelectedProject | null;
  loading: boolean;
  projectRevision: number;
  refreshSelectedProject: (projectId?: string) => Promise<SelectedProject | null>;
} {
  const pathname = usePathname();
  const {
    selectedProject,
    setSelectedProject,
    loading: ctxLoading,
    projectRevision,
    refreshSelectedProject,
  } = useProjectContext();
  const [urlProjectId, setUrlProjectId] = useState<string | null>(null);
  const [fetchedProject, setFetchedProject] = useState<SelectedProject | null>(
    null
  );
  const [fetching, setFetching] = useState(false);

  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    setUrlProjectId(params.get("projectId"));
  }, [pathname]);

  const projectId = urlProjectId ?? selectedProject?.id ?? null;
  const project =
    (projectId === selectedProject?.id ? selectedProject : null) ??
    fetchedProject;

  useEffect(() => {
    if (!projectId) return;
    if (selectedProject?.id === projectId) return;

    setFetching(true);
    fetch("/api/allocation-projects")
      .then((r) => r.json())
      .then((projects: SelectedProject[]) => {
        const found = projects.find((p) => p.id === projectId);
        if (found) {
          setFetchedProject(found);
          setSelectedProject(found);
        }
      })
      .finally(() => setFetching(false));
  }, [projectId, selectedProject?.id, setSelectedProject]);

  return {
    projectId,
    project,
    loading: ctxLoading || fetching,
    projectRevision,
    refreshSelectedProject,
  };
}

export function projectHref(path: string, projectId: string | null): string {
  if (!projectId) return path;
  const sep = path.includes("?") ? "&" : "?";
  return `${path}${sep}projectId=${projectId}`;
}

"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useState,
  type ReactNode,
} from "react";

export interface SelectedProject {
  id: string;
  name: string;
  status: string;
  period: {
    label: string;
    half: number;
    year: number;
    cadence?: string;
    month?: number | null;
  };
}

interface ProjectContextValue {
  selectedProject: SelectedProject | null;
  setSelectedProject: (project: SelectedProject | null) => void;
  loading: boolean;
  projectRevision: number;
  refreshSelectedProject: (projectId?: string) => Promise<SelectedProject | null>;
}

const STORAGE_KEY = "kbi-selected-project-id";

const ProjectContext = createContext<ProjectContextValue | null>(null);

export function ProjectProvider({ children }: { children: ReactNode }) {
  const [selectedProject, setSelectedProjectState] =
    useState<SelectedProject | null>(null);
  const [loading, setLoading] = useState(true);
  const [projectRevision, setProjectRevision] = useState(0);

  const setSelectedProject = useCallback((project: SelectedProject | null) => {
    setSelectedProjectState(project);
    if (project) {
      localStorage.setItem(STORAGE_KEY, project.id);
    } else {
      localStorage.removeItem(STORAGE_KEY);
    }
  }, []);

  const refreshSelectedProject = useCallback(
    async (projectId?: string) => {
      const id = projectId ?? selectedProject?.id;
      if (!id) return null;

      const projects: SelectedProject[] = await fetch(
        "/api/allocation-projects",
        { credentials: "include" }
      ).then((r) => r.json());

      const found = projects.find((p) => p.id === id) ?? null;
      if (found) {
        setSelectedProject(found);
      }
      setProjectRevision((v) => v + 1);
      return found;
    },
    [selectedProject?.id, setSelectedProject]
  );

  useEffect(() => {
    const storedId = localStorage.getItem(STORAGE_KEY);
    if (!storedId) {
      setLoading(false);
      return;
    }

    fetch("/api/allocation-projects")
      .then((r) => r.json())
      .then((projects: SelectedProject[]) => {
        const found = projects.find((p) => p.id === storedId);
        if (found) setSelectedProjectState(found);
        else localStorage.removeItem(STORAGE_KEY);
      })
      .catch(() => localStorage.removeItem(STORAGE_KEY))
      .finally(() => setLoading(false));
  }, []);

  return (
    <ProjectContext.Provider
      value={{
        selectedProject,
        setSelectedProject,
        loading,
        projectRevision,
        refreshSelectedProject,
      }}
    >
      {children}
    </ProjectContext.Provider>
  );
}

export function useProjectContext() {
  const ctx = useContext(ProjectContext);
  if (!ctx) {
    throw new Error("useProjectContext must be used within ProjectProvider");
  }
  return ctx;
}

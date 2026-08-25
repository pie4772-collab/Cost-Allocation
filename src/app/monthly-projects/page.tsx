"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import {
  PageHeader,
  StatusBadge,
  EmptyState,
  LoadingState,
} from "@/components/ui/common";
import { useProjectContext, type SelectedProject } from "@/lib/project-context";
import { apiJson } from "@/lib/api-fetch";
import { cn } from "@/lib/utils";

interface ProjectRow extends SelectedProject {
  _count: { monthlyCosts: number };
  runs: Array<{ id: string; createdAt: string }>;
}

async function parseError(res: Response): Promise<string> {
  try {
    const data = await res.json();
    if (res.status === 403 || res.status === 401) {
      return "로그인이 필요합니다. 다시 로그인해주세요.";
    }
    return data.error ?? "요청에 실패했습니다.";
  } catch {
    return "요청에 실패했습니다.";
  }
}

export default function MonthlyProjectsPage() {
  const router = useRouter();
  const { selectedProject, setSelectedProject } = useProjectContext();
  const [projects, setProjects] = useState<ProjectRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editName, setEditName] = useState("");
  const [form, setForm] = useState({
    year: new Date().getFullYear(),
    month: new Date().getMonth() + 1,
    name: "",
  });

  const load = async () => {
    setLoading(true);
    setError("");
    try {
      const projs = await fetch("/api/allocation-projects?cadence=MONTHLY", {
        credentials: "include",
      }).then((r) => r.json());
      setProjects(projs);
    } catch {
      setError("프로젝트 목록을 불러오지 못했습니다.");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { load(); }, []);

  const selectProject = (project: ProjectRow, navigate = false) => {
    setSelectedProject(project);
    if (navigate) {
      router.push(`/costs?projectId=${project.id}`);
    }
  };

  const createProject = async () => {
    const name =
      form.name.trim() || `${form.year}년 ${form.month}월 공동비용 배부`;
    setSaving(true);
    setError("");
    const res = await fetch("/api/allocation-projects", {
      method: "POST",
      credentials: "include",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        cadence: "MONTHLY",
        year: form.year,
        month: form.month,
        name,
      }),
    });
    if (res.ok) {
      const project = await res.json();
      setShowForm(false);
      setForm({
        year: new Date().getFullYear(),
        month: new Date().getMonth() + 1,
        name: "",
      });
      setSelectedProject(project);
      await load();
      router.push(`/costs?projectId=${project.id}`);
    } else {
      setError(await parseError(res));
    }
    setSaving(false);
  };

  const startEdit = (project: ProjectRow) => {
    setEditingId(project.id);
    setEditName(project.name);
  };

  const saveEdit = async (projectId: string) => {
    if (!editName.trim()) return;
    setSaving(true);
    setError("");
    try {
      const updated = await apiJson<ProjectRow>(`/api/allocation-projects/${projectId}`, {
        method: "PATCH",
        body: JSON.stringify({ name: editName.trim() }),
      });
      setEditingId(null);
      if (selectedProject?.id === projectId) {
        setSelectedProject(updated);
      }
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : "이름 수정 실패");
    } finally {
      setSaving(false);
    }
  };

  if (loading) return <LoadingState />;

  const usedPeriodKeys = new Set(
    projects.map((p) => `${p.period.year}-${p.period.month}`)
  );

  return (
    <>
      <PageHeader
        title="월별 프로젝트"
        description="매월 원가를 입력하고 배분율을 적용합니다 (반기 프로세스와 별도)"
        actions={
          <button onClick={() => setShowForm((v) => !v)} className="btn-primary">
            월별 프로젝트 추가
          </button>
        }
      />

      {error && (
        <div className="mb-4 card border-red-300 bg-red-50 text-red-700 text-sm">
          {error}
        </div>
      )}

      {selectedProject?.period.cadence === "MONTHLY" && (
        <div className="mb-4 card bg-green-50 border-green-300 text-sm flex flex-wrap items-center justify-between gap-3">
          <div>
            <span className="text-green-800 font-medium">작업 중: </span>
            <span className="font-semibold">{selectedProject.name}</span>
            <span className="text-green-700 ml-2">({selectedProject.period.label})</span>
          </div>
          <button
            onClick={() => router.push(`/costs?projectId=${selectedProject.id}`)}
            className="btn-primary text-xs py-1 px-3"
          >
            원가 입력으로 이동
          </button>
        </div>
      )}

      {showForm && (
        <div className="card mb-6">
          <h3 className="text-sm font-semibold mb-3">새 월별 프로젝트</h3>
          <div className="grid grid-cols-1 md:grid-cols-4 gap-3 items-end">
            <div>
              <label className="text-xs text-navy-500 block mb-1">연도</label>
              <input
                type="number"
                className="input w-full"
                value={form.year}
                onChange={(e) =>
                  setForm((p) => ({ ...p, year: parseInt(e.target.value) || p.year }))
                }
              />
            </div>
            <div>
              <label className="text-xs text-navy-500 block mb-1">월</label>
              <select
                className="input w-full"
                value={form.month}
                onChange={(e) =>
                  setForm((p) => ({ ...p, month: parseInt(e.target.value) }))
                }
              >
                {Array.from({ length: 12 }, (_, i) => i + 1).map((m) => (
                  <option key={m} value={m}>{m}월</option>
                ))}
              </select>
            </div>
            <div>
              <label className="text-xs text-navy-500 block mb-1">프로젝트명</label>
              <input
                className="input w-full"
                value={form.name}
                onChange={(e) => setForm((p) => ({ ...p, name: e.target.value }))}
                placeholder={`${form.year}년 ${form.month}월 공동비용 배부`}
              />
            </div>
            <button
              onClick={createProject}
              className="btn-primary"
              disabled={saving || usedPeriodKeys.has(`${form.year}-${form.month}`)}
            >
              {saving ? "생성 중..." : "프로젝트 생성"}
            </button>
          </div>
          {usedPeriodKeys.has(`${form.year}-${form.month}`) && (
            <p className="text-xs text-red-600 mt-2">
              해당 월 프로젝트가 이미 있습니다.
            </p>
          )}
        </div>
      )}

      {projects.length === 0 ? (
        <EmptyState message="월별 프로젝트가 없습니다. 위에서 추가하세요." />
      ) : (
        <div className="card overflow-x-auto">
          <table className="data-table">
            <thead>
              <tr>
                <th>프로젝트명</th>
                <th>대상 월</th>
                <th>상태</th>
                <th>원가 건수</th>
                <th>최근 실행</th>
                <th>작업</th>
              </tr>
            </thead>
            <tbody>
              {projects.map((p) => (
                <tr
                  key={p.id}
                  className={cn(
                    selectedProject?.id === p.id && "bg-navy-50 ring-1 ring-inset ring-navy-200"
                  )}
                >
                  <td className="font-medium min-w-[200px]">
                    {editingId === p.id ? (
                      <div className="flex gap-2 items-center">
                        <input
                          className="input text-sm flex-1"
                          value={editName}
                          onChange={(e) => setEditName(e.target.value)}
                          onKeyDown={(e) => {
                            if (e.key === "Enter") saveEdit(p.id);
                            if (e.key === "Escape") setEditingId(null);
                          }}
                          autoFocus
                        />
                        <button
                          onClick={() => saveEdit(p.id)}
                          className="btn-primary text-xs py-1 px-2"
                          disabled={saving}
                        >
                          저장
                        </button>
                        <button
                          onClick={() => setEditingId(null)}
                          className="btn-secondary text-xs py-1 px-2"
                        >
                          취소
                        </button>
                      </div>
                    ) : (
                      <span>{p.name}</span>
                    )}
                  </td>
                  <td>{p.period.label}</td>
                  <td><StatusBadge status={p.status} /></td>
                  <td>{p._count.monthlyCosts}</td>
                  <td>
                    {p.runs[0]
                      ? new Date(p.runs[0].createdAt).toLocaleDateString("ko-KR")
                      : "-"}
                  </td>
                  <td className="space-x-2 whitespace-nowrap">
                    <button
                      onClick={() => selectProject(p, false)}
                      className={cn(
                        "text-xs py-1 px-2 rounded border",
                        selectedProject?.id === p.id
                          ? "bg-navy-800 text-white border-navy-800"
                          : "btn-secondary"
                      )}
                    >
                      {selectedProject?.id === p.id ? "선택됨" : "선택"}
                    </button>
                    {editingId !== p.id && p.status !== "CLOSED" && (
                      <button
                        onClick={() => startEdit(p)}
                        className="text-navy-600 hover:underline text-xs"
                      >
                        이름 수정
                      </button>
                    )}
                    <button
                      onClick={() => selectProject(p, true)}
                      className="text-navy-600 hover:underline text-xs"
                    >
                      원가 입력
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </>
  );
}

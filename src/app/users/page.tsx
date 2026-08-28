"use client";

import { useEffect, useState } from "react";
import { PageHeader, LoadingState } from "@/components/ui/common";
import { apiFetch } from "@/lib/api-fetch";
import { ALL_ROLES, ROLE_LABELS, type AppRoleName } from "@/lib/role-labels";

interface ManagedUser {
  id: string;
  email: string;
  name: string;
  isActive: boolean;
  createdAt: string;
  roles: AppRoleName[];
}

type FormMode = "none" | "add" | "edit";

type FormData = {
  email: string;
  name: string;
  password: string;
  passwordConfirm: string;
  roles: AppRoleName[];
};

const EMPTY_FORM: FormData = {
  email: "",
  name: "",
  password: "",
  passwordConfirm: "",
  roles: ["Viewer"],
};

export default function UsersPage() {
  const [allowed, setAllowed] = useState<boolean | null>(null);
  const [currentUserId, setCurrentUserId] = useState<string | null>(null);
  const [users, setUsers] = useState<ManagedUser[]>([]);
  const [loading, setLoading] = useState(true);
  const [formMode, setFormMode] = useState<FormMode>("none");
  const [editingId, setEditingId] = useState<string | null>(null);
  const [form, setForm] = useState<FormData>(EMPTY_FORM);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  const load = () => {
    setLoading(true);
    setError("");
    fetch("/api/users", { credentials: "include" })
      .then(async (r) => {
        const data = await r.json();
        if (!r.ok) throw new Error(data.error ?? "목록을 불러오지 못했습니다.");
        setUsers(data);
      })
      .catch((e) => setError(e instanceof Error ? e.message : "목록을 불러오지 못했습니다."))
      .finally(() => setLoading(false));
  };

  useEffect(() => {
    fetch("/api/auth/me", { credentials: "include" })
      .then((r) => r.json())
      .then((me) => {
        const isAdmin = Array.isArray(me?.roles) && me.roles.includes("Admin");
        setAllowed(isAdmin);
        setCurrentUserId(me?.id ?? null);
        if (isAdmin) load();
        else setLoading(false);
      })
      .catch(() => {
        setAllowed(false);
        setLoading(false);
      });
  }, []);

  const openAdd = () => {
    setForm(EMPTY_FORM);
    setEditingId(null);
    setFormMode("add");
    setError("");
  };

  const openEdit = (user: ManagedUser) => {
    setForm({
      email: user.email,
      name: user.name,
      password: "",
      passwordConfirm: "",
      roles: user.roles,
    });
    setEditingId(user.id);
    setFormMode("edit");
    setError("");
  };

  const closeForm = () => {
    setFormMode("none");
    setEditingId(null);
    setForm(EMPTY_FORM);
    setError("");
  };

  const toggleRole = (role: AppRoleName) => {
    setForm((prev) => ({
      ...prev,
      roles: prev.roles.includes(role)
        ? prev.roles.filter((r) => r !== role)
        : [...prev.roles, role],
    }));
  };

  const saveUser = async () => {
    if (!form.name.trim() || form.roles.length === 0) return;
    if (formMode === "add" && !form.email.trim()) return;
    if (form.password || formMode === "add") {
      if (form.password.length < 8) {
        setError("비밀번호는 8자 이상이어야 합니다.");
        return;
      }
      if (form.password !== form.passwordConfirm) {
        setError("비밀번호 확인이 일치하지 않습니다.");
        return;
      }
    }

    setSaving(true);
    setError("");
    try {
      const payload =
        formMode === "add"
          ? {
              email: form.email.trim(),
              name: form.name.trim(),
              password: form.password,
              roles: form.roles,
            }
          : {
              name: form.name.trim(),
              roles: form.roles,
              ...(form.password ? { password: form.password } : {}),
            };

      const res = await apiFetch(
        formMode === "edit" && editingId ? `/api/users/${editingId}` : "/api/users",
        {
          method: formMode === "edit" ? "PATCH" : "POST",
          body: JSON.stringify(payload),
        }
      );
      if (!res.ok) {
        const d = await res.json().catch(() => ({}));
        throw new Error((d as { error?: string }).error ?? "저장 실패");
      }
      closeForm();
      load();
    } catch (e) {
      setError(e instanceof Error ? e.message : "저장 실패");
    } finally {
      setSaving(false);
    }
  };

  const deactivateUser = async (user: ManagedUser) => {
    if (!confirm(`"${user.name}" 계정을 비활성화하시겠습니까?`)) return;
    setSaving(true);
    setError("");
    try {
      const res = await apiFetch(`/api/users/${user.id}`, {
        method: "PATCH",
        body: JSON.stringify({ isActive: false }),
      });
      if (!res.ok) {
        const d = await res.json().catch(() => ({}));
        throw new Error((d as { error?: string }).error ?? "비활성화 실패");
      }
      load();
    } catch (e) {
      setError(e instanceof Error ? e.message : "비활성화 실패");
    } finally {
      setSaving(false);
    }
  };

  const reactivateUser = async (user: ManagedUser) => {
    setSaving(true);
    setError("");
    try {
      const res = await apiFetch(`/api/users/${user.id}`, {
        method: "PATCH",
        body: JSON.stringify({ isActive: true }),
      });
      if (!res.ok) {
        const d = await res.json().catch(() => ({}));
        throw new Error((d as { error?: string }).error ?? "활성화 실패");
      }
      load();
    } catch (e) {
      setError(e instanceof Error ? e.message : "활성화 실패");
    } finally {
      setSaving(false);
    }
  };

  if (loading || allowed === null) return <LoadingState />;

  if (!allowed) {
    return (
      <>
        <PageHeader title="사용자 관리" description="계정 등록은 관리자만 할 수 있습니다." />
        <div className="card border-red-300 bg-red-50 text-red-700 text-sm">
          이 메뉴는 관리자 권한이 필요합니다.
        </div>
      </>
    );
  }

  const adminCount = users.filter((u) => u.isActive && u.roles.includes("Admin")).length;

  return (
    <>
      <PageHeader
        title="사용자 관리"
        description="기존 계정과 관리자는 그대로 두고, 새 사용자를 추가 등록합니다."
        actions={
          <button onClick={openAdd} className="btn-primary" disabled={formMode === "add"}>
            사용자 추가
          </button>
        }
      />

      {error && (
        <div className="mb-4 card border-red-300 bg-red-50 text-red-700 text-sm">{error}</div>
      )}

      {formMode !== "none" && (
        <div className="card mb-4">
          <h3 className="text-sm font-semibold mb-3">
            {formMode === "add" ? "새 사용자 등록" : "사용자 정보 수정"}
          </h3>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            <div>
              <label className="text-xs text-navy-500 block mb-1">이메일</label>
              <input
                type="email"
                className={`input w-full ${formMode === "edit" ? "bg-navy-50" : ""}`}
                value={form.email}
                readOnly={formMode === "edit"}
                onChange={(e) => setForm((p) => ({ ...p, email: e.target.value }))}
                placeholder="name@kbigrp.com"
              />
              {formMode === "edit" && (
                <p className="text-[10px] text-navy-400 mt-1">이메일은 변경할 수 없습니다.</p>
              )}
            </div>
            <div>
              <label className="text-xs text-navy-500 block mb-1">이름</label>
              <input
                className="input w-full"
                value={form.name}
                onChange={(e) => setForm((p) => ({ ...p, name: e.target.value }))}
              />
            </div>
            <div>
              <label className="text-xs text-navy-500 block mb-1">
                {formMode === "edit" ? "새 비밀번호 (선택)" : "비밀번호"}
              </label>
              <input
                type="password"
                className="input w-full"
                value={form.password}
                onChange={(e) => setForm((p) => ({ ...p, password: e.target.value }))}
                placeholder={formMode === "edit" ? "변경할 때만 입력" : "8자 이상"}
                autoComplete="new-password"
              />
            </div>
            <div>
              <label className="text-xs text-navy-500 block mb-1">비밀번호 확인</label>
              <input
                type="password"
                className="input w-full"
                value={form.passwordConfirm}
                onChange={(e) => setForm((p) => ({ ...p, passwordConfirm: e.target.value }))}
                autoComplete="new-password"
              />
            </div>
          </div>
          <div className="mt-4">
            <p className="text-xs text-navy-500 mb-2">역할</p>
            <div className="flex flex-wrap gap-2">
              {ALL_ROLES.map((role) => {
                const checked = form.roles.includes(role);
                return (
                  <label
                    key={role}
                    className={`inline-flex items-center gap-1.5 px-2 py-1 rounded border text-xs cursor-pointer ${
                      checked
                        ? "border-navy-700 bg-navy-50 text-navy-900"
                        : "border-navy-200 text-navy-600"
                    }`}
                  >
                    <input
                      type="checkbox"
                      checked={checked}
                      onChange={() => toggleRole(role)}
                    />
                    {ROLE_LABELS[role]}
                  </label>
                );
              })}
            </div>
          </div>
          <div className="flex gap-2 mt-4">
            <button
              onClick={saveUser}
              className="btn-primary"
              disabled={saving || !form.name.trim() || form.roles.length === 0}
            >
              {saving ? "저장 중..." : "저장"}
            </button>
            <button onClick={closeForm} className="btn-secondary">
              취소
            </button>
          </div>
        </div>
      )}

      <div className="card overflow-x-auto">
        <table className="data-table">
          <thead>
            <tr>
              <th>이름</th>
              <th>이메일</th>
              <th>역할</th>
              <th>상태</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {users.map((user) => {
              const isSelf = user.id === currentUserId;
              const isLastAdmin = user.roles.includes("Admin") && adminCount <= 1;
              return (
                <tr key={user.id} className={!user.isActive ? "opacity-50" : ""}>
                  <td>
                    {user.name}
                    {isSelf && (
                      <span className="ml-2 text-[10px] text-navy-400">본인</span>
                    )}
                  </td>
                  <td className="font-mono text-xs">{user.email}</td>
                  <td className="text-xs">
                    {user.roles.map((role) => ROLE_LABELS[role]).join(", ")}
                  </td>
                  <td>
                    {user.isActive ? (
                      <span className="badge bg-green-100 text-green-700">활성</span>
                    ) : (
                      <span className="badge bg-gray-100 text-gray-600">비활성</span>
                    )}
                  </td>
                  <td className="whitespace-nowrap">
                    {user.isActive ? (
                      <>
                        <button
                          onClick={() => openEdit(user)}
                          className="text-sm text-navy-600 hover:underline mr-2"
                        >
                          수정
                        </button>
                        {!isSelf && !isLastAdmin && (
                          <button
                            onClick={() => deactivateUser(user)}
                            className="text-sm text-red-600 hover:underline"
                          >
                            비활성
                          </button>
                        )}
                      </>
                    ) : (
                      <button
                        onClick={() => reactivateUser(user)}
                        className="text-sm text-navy-600 hover:underline"
                      >
                        활성화
                      </button>
                    )}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </>
  );
}

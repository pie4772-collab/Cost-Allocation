"use client";

import { useEffect, useState } from "react";
import { PageHeader, LoadingState } from "@/components/ui/common";
import { apiFetch } from "@/lib/api-fetch";
import { nextCompanyCodeFromList } from "@/lib/company-utils";

interface CompanyAddress {
  id?: string;
  line1: string;
  line2?: string | null;
  city?: string | null;
  state?: string | null;
  postalCode?: string | null;
  country: string;
}

interface Company {
  id: string;
  code: string;
  nameKo: string;
  nameEn: string | null;
  companyType: string;
  billingLanguage: string;
  currency: string;
  contactEmail: string | null;
  contactPhone: string | null;
  isActive: boolean;
  addresses: CompanyAddress[];
}

type FormData = {
  code: string;
  nameKo: string;
  nameEn: string;
  companyType: "DOMESTIC" | "OVERSEAS";
  billingLanguage: "KO" | "EN";
  currency: string;
  contactEmail: string;
  contactPhone: string;
  addressLine1: string;
  addressLine2: string;
  city: string;
  postalCode: string;
  country: string;
};

const EMPTY_FORM: FormData = {
  code: "",
  nameKo: "",
  nameEn: "",
  companyType: "DOMESTIC",
  billingLanguage: "KO",
  currency: "KRW",
  contactEmail: "",
  contactPhone: "",
  addressLine1: "",
  addressLine2: "",
  city: "",
  postalCode: "",
  country: "KR",
};

function companyToForm(c: Company): FormData {
  const addr = c.addresses[0];
  return {
    code: c.code,
    nameKo: c.nameKo,
    nameEn: c.nameEn ?? "",
    companyType: c.companyType as "DOMESTIC" | "OVERSEAS",
    billingLanguage: c.billingLanguage as "KO" | "EN",
    currency: c.currency,
    contactEmail: c.contactEmail ?? "",
    contactPhone: c.contactPhone ?? "",
    addressLine1: addr?.line1 ?? "",
    addressLine2: addr?.line2 ?? "",
    city: addr?.city ?? "",
    postalCode: addr?.postalCode ?? "",
    country: addr?.country ?? (c.companyType === "OVERSEAS" ? "US" : "KR"),
  };
}

function buildPayload(form: FormData) {
  return {
    code: form.code,
    nameKo: form.nameKo,
    nameEn: form.nameEn || undefined,
    companyType: form.companyType,
    billingLanguage: form.billingLanguage,
    currency: form.currency,
    contactEmail: form.contactEmail || undefined,
    contactPhone: form.contactPhone || undefined,
    address: form.addressLine1
      ? {
          line1: form.addressLine1,
          line2: form.addressLine2 || undefined,
          city: form.city || undefined,
          postalCode: form.postalCode || undefined,
          country: form.country,
        }
      : undefined,
  };
}

export default function CompaniesPage() {
  const [companies, setCompanies] = useState<Company[]>([]);
  const [loading, setLoading] = useState(true);
  const [formMode, setFormMode] = useState<"none" | "add" | "edit">("none");
  const [editingId, setEditingId] = useState<string | null>(null);
  const [form, setForm] = useState<FormData>(EMPTY_FORM);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  const load = () => {
    setLoading(true);
    fetch("/api/companies?active=false", { credentials: "include" })
      .then((r) => r.json())
      .then(setCompanies)
      .finally(() => setLoading(false));
  };

  useEffect(() => { load(); }, []);

  const openAdd = () => {
    setForm({
      ...EMPTY_FORM,
      code: nextCompanyCodeFromList(companies.map((c) => c.code)),
    });
    setEditingId(null);
    setFormMode("add");
    setError("");
  };

  const openEdit = (c: Company) => {
    setForm(companyToForm(c));
    setEditingId(c.id);
    setFormMode("edit");
    setError("");
  };

  const closeForm = () => {
    setFormMode("none");
    setEditingId(null);
    setForm(EMPTY_FORM);
    setError("");
  };

  const saveCompany = async () => {
    if (!form.code.trim() || !form.nameKo.trim()) return;
    setSaving(true);
    setError("");
    try {
      const payload = buildPayload(form);
      const res = await apiFetch(
        formMode === "edit" && editingId
          ? `/api/companies/${editingId}`
          : "/api/companies",
        {
          method: formMode === "edit" ? "PATCH" : "POST",
          body: JSON.stringify({
            ...payload,
            ...(formMode === "add" ? { sortOrder: companies.length + 1 } : {}),
          }),
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

  const deleteCompany = async (c: Company) => {
    if (!confirm(`"${c.nameKo}" 법인을 삭제(비활성)하시겠습니까?`)) return;
    setSaving(true);
    setError("");
    try {
      const res = await apiFetch(`/api/companies/${c.id}`, {
        method: "DELETE",
        credentials: "include",
      });
      if (!res.ok) {
        const d = await res.json().catch(() => ({}));
        throw new Error((d as { error?: string }).error ?? "삭제 실패");
      }
      load();
    } catch (e) {
      setError(e instanceof Error ? e.message : "삭제 실패");
    } finally {
      setSaving(false);
    }
  };

  if (loading) return <LoadingState />;

  return (
    <>
      <PageHeader
        title="청구 대상 법인"
        description="배부·청구 대상 계열사(법인) 정보를 등록·수정·삭제합니다."
        actions={
          <button onClick={openAdd} className="btn-primary" disabled={formMode === "add"}>
            법인 추가
          </button>
        }
      />

      {error && (
        <div className="mb-4 card border-red-300 bg-red-50 text-red-700 text-sm">{error}</div>
      )}

      {formMode !== "none" && (
        <div className="card mb-4">
          <h3 className="text-sm font-semibold mb-3">
            {formMode === "add" ? "새 법인 등록" : "법인 정보 수정"}
          </h3>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
            <div>
              <label className="text-xs text-navy-500 block mb-1">법인코드</label>
              <input
                className="input w-full font-mono bg-navy-50"
                value={form.code}
                readOnly
                placeholder="kbi-01"
              />
              <p className="text-[10px] text-navy-400 mt-1">순서에 따라 자동 부여 (kbi-01 형식)</p>
            </div>
            <div>
              <label className="text-xs text-navy-500 block mb-1">법인명</label>
              <input className="input w-full" value={form.nameKo} onChange={(e) => setForm((p) => ({ ...p, nameKo: e.target.value }))} />
            </div>
            <div>
              <label className="text-xs text-navy-500 block mb-1">영문명</label>
              <input className="input w-full" value={form.nameEn} onChange={(e) => setForm((p) => ({ ...p, nameEn: e.target.value }))} />
            </div>
            <div>
              <label className="text-xs text-navy-500 block mb-1">구분</label>
              <select
                className="input w-full"
                value={form.companyType}
                onChange={(e) => {
                  const t = e.target.value as "DOMESTIC" | "OVERSEAS";
                  setForm((p) => ({
                    ...p,
                    companyType: t,
                    billingLanguage: t === "OVERSEAS" ? "EN" : "KO",
                    country: t === "OVERSEAS" ? "US" : "KR",
                  }));
                }}
              >
                <option value="DOMESTIC">국내</option>
                <option value="OVERSEAS">해외</option>
              </select>
            </div>
            <div>
              <label className="text-xs text-navy-500 block mb-1">청구 언어</label>
              <select className="input w-full" value={form.billingLanguage} onChange={(e) => setForm((p) => ({ ...p, billingLanguage: e.target.value as "KO" | "EN" }))}>
                <option value="KO">한국어</option>
                <option value="EN">English</option>
              </select>
            </div>
            <div>
              <label className="text-xs text-navy-500 block mb-1">통화</label>
              <select className="input w-full" value={form.currency} onChange={(e) => setForm((p) => ({ ...p, currency: e.target.value }))}>
                <option value="KRW">KRW</option>
                <option value="USD">USD</option>
                <option value="EUR">EUR</option>
                <option value="JPY">JPY</option>
                <option value="CNY">CNY</option>
              </select>
            </div>
            <div>
              <label className="text-xs text-navy-500 block mb-1">담당 이메일</label>
              <input type="email" className="input w-full" value={form.contactEmail} onChange={(e) => setForm((p) => ({ ...p, contactEmail: e.target.value }))} />
            </div>
            <div>
              <label className="text-xs text-navy-500 block mb-1">담당 전화</label>
              <input className="input w-full" value={form.contactPhone} onChange={(e) => setForm((p) => ({ ...p, contactPhone: e.target.value }))} />
            </div>
            <div>
              <label className="text-xs text-navy-500 block mb-1">청구서 주소</label>
              <input className="input w-full" value={form.addressLine1} onChange={(e) => setForm((p) => ({ ...p, addressLine1: e.target.value }))} placeholder="주소 1" />
            </div>
            <div>
              <label className="text-xs text-navy-500 block mb-1">상세 주소</label>
              <input className="input w-full" value={form.addressLine2} onChange={(e) => setForm((p) => ({ ...p, addressLine2: e.target.value }))} />
            </div>
            <div>
              <label className="text-xs text-navy-500 block mb-1">도시</label>
              <input className="input w-full" value={form.city} onChange={(e) => setForm((p) => ({ ...p, city: e.target.value }))} />
            </div>
            <div>
              <label className="text-xs text-navy-500 block mb-1">우편번호</label>
              <input className="input w-full" value={form.postalCode} onChange={(e) => setForm((p) => ({ ...p, postalCode: e.target.value }))} />
            </div>
          </div>
          <div className="flex gap-2 mt-4">
            <button onClick={saveCompany} className="btn-primary" disabled={saving || !form.nameKo}>
              {saving ? "저장 중..." : "저장"}
            </button>
            <button onClick={closeForm} className="btn-secondary">취소</button>
          </div>
        </div>
      )}

      <div className="card overflow-x-auto">
        <table className="data-table">
          <thead>
            <tr>
              <th>코드</th>
              <th>법인명</th>
              <th>구분</th>
              <th>청구언어</th>
              <th>통화</th>
              <th>담당 연락처</th>
              <th>청구 주소</th>
              <th>상태</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {companies.map((c) => (
              <tr key={c.id} className={!c.isActive ? "opacity-50" : ""}>
                <td className="font-mono">{c.code}</td>
                <td>
                  <div>{c.nameKo}</div>
                  {c.nameEn && <div className="text-xs text-navy-400">{c.nameEn}</div>}
                </td>
                <td>{c.companyType === "OVERSEAS" ? "해외" : "국내"}</td>
                <td>{c.billingLanguage}</td>
                <td>{c.currency}</td>
                <td className="text-xs">
                  {c.contactEmail && <div>{c.contactEmail}</div>}
                  {c.contactPhone && <div>{c.contactPhone}</div>}
                  {!c.contactEmail && !c.contactPhone && "-"}
                </td>
                <td className="text-xs max-w-[180px] truncate">
                  {c.addresses[0]?.line1 ?? <span className="text-red-500">주소 없음</span>}
                </td>
                <td>
                  {c.isActive ? (
                    <span className="badge bg-green-100 text-green-700">활성</span>
                  ) : (
                    <span className="badge bg-gray-100 text-gray-600">비활성</span>
                  )}
                </td>
                <td className="whitespace-nowrap">
                  {c.isActive && (
                    <>
                      <button onClick={() => openEdit(c)} className="text-sm text-navy-600 hover:underline mr-2">수정</button>
                      <button onClick={() => deleteCompany(c)} className="text-sm text-red-600 hover:underline">삭제</button>
                    </>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  );
}

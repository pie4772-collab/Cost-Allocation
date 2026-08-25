"use client";

import { useEffect, useState, useCallback, useMemo } from "react";
import { X } from "lucide-react";
import { PageHeader, AmountCell, StatusBadge, LoadingState } from "@/components/ui/common";
import { InvoiceFormView } from "@/components/invoices/invoice-form-view";
import { apiJson } from "@/lib/api-fetch";
import type { InvoiceFormData } from "@/lib/invoice-form-config";
import { ProcessSteps } from "@/components/ui/process-steps";
import { ProjectBanner, ProjectRequired } from "@/components/ui/project-banner";
import { useProjectId } from "@/lib/use-project-id";
import { cn, formatAmount } from "@/lib/utils";

interface Invoice {
  id: string;
  invoiceNumber: string | null;
  invoiceType: string;
  status: string;
  periodLabel: string;
  subtotal: string;
  markupAmount: string;
  totalAmount: string;
  company: { code: string; nameKo: string; nameEn: string | null };
  run: { id: string };
  lines: Array<{ lineNumber: number; description: string; amount: string }>;
}

type ListSortKey =
  | "company"
  | "code"
  | "type"
  | "status"
  | "subtotal"
  | "markup"
  | "total";
type SortDir = "asc" | "desc";

const STATUS_FILTER_OPTIONS = [
  { value: "ALL", label: "전체 상태" },
  { value: "DRAFT", label: "작성중" },
  { value: "APPROVED", label: "승인됨" },
  { value: "ISSUED", label: "발행됨" },
] as const;

const TYPE_FILTER_OPTIONS = [
  { value: "ALL", label: "전체 유형" },
  { value: "DOMESTIC", label: "국내" },
  { value: "OVERSEAS", label: "해외" },
] as const;

function SortableTh({
  label,
  active,
  dir,
  onClick,
  className,
}: {
  label: string;
  active: boolean;
  dir: SortDir;
  onClick: () => void;
  className?: string;
}) {
  return (
    <th className={className}>
      <button
        type="button"
        onClick={onClick}
        className={cn(
          "inline-flex items-center gap-1 text-white transition-colors hover:text-white",
          active ? "font-semibold" : "text-white/90 hover:text-white",
          className?.includes("text-right") && "w-full justify-end"
        )}
      >
        {label}
        <span className="text-[10px] text-white/80">
          {active ? (dir === "asc" ? "▲" : "▼") : "↕"}
        </span>
      </button>
    </th>
  );
}

function toggleSort<T extends string>(
  current: { key: T; dir: SortDir },
  key: T
): { key: T; dir: SortDir } {
  if (current.key === key) {
    return { key, dir: current.dir === "asc" ? "desc" : "asc" };
  }
  return { key, dir: "asc" };
}

function compareText(a: string, b: string, dir: SortDir) {
  const cmp = a.localeCompare(b, "ko");
  return dir === "asc" ? cmp : -cmp;
}

function compareAmount(a: string, b: string, dir: SortDir) {
  const diff = BigInt(a) - BigInt(b);
  if (diff === 0n) return 0;
  const sign = diff > 0n ? 1 : -1;
  return dir === "asc" ? sign : -sign;
}

function InvoiceDetailModal({
  invoiceId,
  listInvoice,
  onClose,
  onApprove,
  onIssue,
}: {
  invoiceId: string;
  listInvoice: Invoice;
  onClose: () => void;
  onApprove: (id: string) => void;
  onIssue: (id: string) => void;
}) {
  const [formData, setFormData] = useState<InvoiceFormData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    setLoading(true);
    setError("");
    apiJson<InvoiceFormData>(`/api/invoices/${invoiceId}`)
      .then(setFormData)
      .catch((e) =>
        setError(e instanceof Error ? e.message : "청구서 양식 로드 실패")
      )
      .finally(() => setLoading(false));
  }, [invoiceId, listInvoice.status, listInvoice.invoiceNumber]);

  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
    };
    document.body.style.overflow = "hidden";
    window.addEventListener("keydown", onKeyDown);
    return () => {
      document.body.style.overflow = "";
      window.removeEventListener("keydown", onKeyDown);
    };
  }, [onClose]);

  const title = formData?.billToName ?? listInvoice.company.nameKo;

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4 sm:p-6"
      role="dialog"
      aria-modal="true"
      aria-labelledby="invoice-modal-title"
    >
      <button
        type="button"
        className="absolute inset-0 bg-navy-900/60 backdrop-blur-[1px]"
        aria-label="닫기"
        onClick={onClose}
      />

      <div className="relative w-full max-w-4xl max-h-[min(92vh,920px)] overflow-hidden flex flex-col bg-white rounded-xl shadow-2xl border border-navy-200">
        <div className="flex items-start justify-between gap-4 border-b border-navy-200 px-5 py-3 shrink-0">
          <div>
            <h2 id="invoice-modal-title" className="text-base font-bold text-navy-900">
              {title}
            </h2>
            <div className="flex flex-wrap items-center gap-2 mt-1 text-xs text-navy-600">
              <span>{listInvoice.company.code}</span>
              <StatusBadge status={listInvoice.status} />
            </div>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="p-2 rounded-lg text-navy-500 hover:bg-navy-100 hover:text-navy-900 transition-colors"
            aria-label="닫기"
          >
            <X size={20} />
          </button>
        </div>

        <div className="overflow-y-auto flex-1 px-5 py-4 bg-navy-50/40">
          {loading ? (
            <LoadingState />
          ) : error ? (
            <p className="text-red-600 text-sm">{error}</p>
          ) : formData ? (
            <InvoiceFormView data={formData} />
          ) : null}
        </div>

        <div className="flex flex-wrap gap-2 px-5 py-4 border-t border-navy-200 shrink-0 bg-white">
          {listInvoice.status === "DRAFT" && (
            <button
              type="button"
              className="btn-primary"
              onClick={() => onApprove(invoiceId)}
            >
              승인
            </button>
          )}
          {listInvoice.status === "APPROVED" && (
            <button
              type="button"
              className="btn-primary"
              onClick={() => onIssue(invoiceId)}
            >
              발행
            </button>
          )}
          <a
            href={`/api/exports/pdf?invoiceId=${invoiceId}`}
            className="btn-secondary"
            target="_blank"
            rel="noreferrer"
          >
            PDF
          </a>
          <a
            href={`/api/exports/excel?runId=${listInvoice.run.id}&type=invoices`}
            className="btn-secondary"
          >
            Excel
          </a>
          <button type="button" className="btn-secondary ml-auto" onClick={onClose}>
            닫기
          </button>
        </div>
      </div>
    </div>
  );
}

export default function InvoicesPage() {
  const { projectId, loading: projectLoading, projectRevision } = useProjectId();
  const [invoices, setInvoices] = useState<Invoice[]>([]);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState("ALL");
  const [typeFilter, setTypeFilter] = useState("ALL");
  const [search, setSearch] = useState("");
  const [listSort, setListSort] = useState<{ key: ListSortKey; dir: SortDir }>({
    key: "company",
    dir: "asc",
  });

  const selected = useMemo(
    () => invoices.find((inv) => inv.id === selectedId) ?? null,
    [invoices, selectedId]
  );

  const load = useCallback(() => {
    if (!projectId) {
      setLoading(false);
      return;
    }
    setLoading(true);
    fetch(`/api/invoices?projectId=${projectId}`, { credentials: "include" })
      .then((r) => r.json())
      .then(setInvoices)
      .finally(() => setLoading(false));
  }, [projectId]);

  useEffect(() => {
    load();
  }, [load, projectRevision]);

  useEffect(() => {
    setSelectedId(null);
  }, [projectRevision]);

  const filteredInvoices = useMemo(() => {
    const q = search.trim().toLowerCase();
    return invoices.filter((inv) => {
      if (statusFilter !== "ALL" && inv.status !== statusFilter) return false;
      if (typeFilter !== "ALL" && inv.invoiceType !== typeFilter) return false;
      if (!q) return true;
      const haystack = [
        inv.company.nameKo,
        inv.company.nameEn ?? "",
        inv.company.code,
        inv.invoiceNumber ?? "",
      ]
        .join(" ")
        .toLowerCase();
      return haystack.includes(q);
    });
  }, [invoices, statusFilter, typeFilter, search]);

  const sortedInvoices = useMemo(() => {
    const rows = [...filteredInvoices];
    rows.sort((a, b) => {
      const { key, dir } = listSort;
      switch (key) {
        case "company":
          return compareText(a.company.nameKo, b.company.nameKo, dir);
        case "code":
          return compareText(a.company.code, b.company.code, dir);
        case "type":
          return compareText(a.invoiceType, b.invoiceType, dir);
        case "status":
          return compareText(a.status, b.status, dir);
        case "subtotal":
          return compareAmount(a.subtotal, b.subtotal, dir);
        case "markup":
          return compareAmount(a.markupAmount, b.markupAmount, dir);
        case "total":
          return compareAmount(a.totalAmount, b.totalAmount, dir);
        default:
          return 0;
      }
    });
    return rows;
  }, [filteredInvoices, listSort]);

  const listTotals = useMemo(() => {
    return filteredInvoices.reduce(
      (acc, inv) => ({
        count: acc.count + 1,
        subtotal: acc.subtotal + BigInt(inv.subtotal),
        markup: acc.markup + BigInt(inv.markupAmount),
        total: acc.total + BigInt(inv.totalAmount),
      }),
      { count: 0, subtotal: 0n, markup: 0n, total: 0n }
    );
  }, [filteredInvoices]);

  const generate = async () => {
    if (!projectId) return;
    const runs = await fetch(`/api/allocation-runs?projectId=${projectId}`, {
      credentials: "include",
    }).then((r) => r.json());
    const finalRun = runs.find(
      (r: { runType: string; status: string }) =>
        r.runType === "FINAL" && ["EXECUTED", "APPROVED"].includes(r.status)
    );
    if (!finalRun) return alert("최종 배분 계산 및 절사·대사 확정 후 생성 가능합니다.");
    const runDetail = await fetch(`/api/allocation-runs?runId=${finalRun.id}`, {
      credentials: "include",
    }).then((r) => r.json());
    if (!runDetail.reconciliation) {
      return alert("절사·대사를 먼저 확정하세요.");
    }
    await fetch("/api/invoices", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      credentials: "include",
      body: JSON.stringify({ action: "generate", runId: finalRun.id }),
    });
    load();
  };

  const approve = async (id: string) => {
    await fetch("/api/invoices", {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      credentials: "include",
      body: JSON.stringify({ invoiceId: id, action: "approve" }),
    });
    load();
  };

  const issue = async (id: string) => {
    await fetch(`/api/invoices/${id}/issue`, {
      method: "POST",
      credentials: "include",
    });
    load();
  };

  if (projectLoading) return <LoadingState />;

  return (
    <>
      <ProjectBanner />
      <ProcessSteps current={5} />

      <ProjectRequired projectId={projectId}>
        <PageHeader
          title="⑤ 청구서 작성"
          description="전체 청구서 목록 — 행을 클릭하면 팝업에서 상세·승인·발행"
          actions={
            <button onClick={generate} className="btn-primary">
              청구서 생성
            </button>
          }
        />

        {loading ? (
          <LoadingState />
        ) : (
          <div className="w-full space-y-3">
            <div className="card py-3 px-4 flex flex-wrap gap-3 items-end">
              <label className="text-xs text-navy-600">
                <span className="block mb-1">상태</span>
                <select
                  className="input text-sm min-w-[120px]"
                  value={statusFilter}
                  onChange={(e) => setStatusFilter(e.target.value)}
                >
                  {STATUS_FILTER_OPTIONS.map((o) => (
                    <option key={o.value} value={o.value}>
                      {o.label}
                    </option>
                  ))}
                </select>
              </label>
              <label className="text-xs text-navy-600">
                <span className="block mb-1">유형</span>
                <select
                  className="input text-sm min-w-[100px]"
                  value={typeFilter}
                  onChange={(e) => setTypeFilter(e.target.value)}
                >
                  {TYPE_FILTER_OPTIONS.map((o) => (
                    <option key={o.value} value={o.value}>
                      {o.label}
                    </option>
                  ))}
                </select>
              </label>
              <label className="text-xs text-navy-600 flex-1 min-w-[200px]">
                <span className="block mb-1">법인 검색</span>
                <input
                  type="search"
                  className="input text-sm w-full"
                  placeholder="법인명·코드·청구번호"
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                />
              </label>
              <p className="text-xs text-navy-500 pb-1 whitespace-nowrap">
                {listTotals.count}건 / 전체 {invoices.length}건 · 행 클릭 → 상세
              </p>
            </div>

            <div className="card overflow-x-auto p-0 w-full">
              <table className="data-table w-full">
                <thead>
                  <tr>
                    <SortableTh
                      label="법인"
                      active={listSort.key === "company"}
                      dir={listSort.dir}
                      onClick={() => setListSort((s) => toggleSort(s, "company"))}
                    />
                    <SortableTh
                      label="코드"
                      active={listSort.key === "code"}
                      dir={listSort.dir}
                      onClick={() => setListSort((s) => toggleSort(s, "code"))}
                    />
                    <SortableTh
                      label="유형"
                      active={listSort.key === "type"}
                      dir={listSort.dir}
                      onClick={() => setListSort((s) => toggleSort(s, "type"))}
                    />
                    <SortableTh
                      label="상태"
                      active={listSort.key === "status"}
                      dir={listSort.dir}
                      onClick={() => setListSort((s) => toggleSort(s, "status"))}
                    />
                    <SortableTh
                      label="배분소계"
                      active={listSort.key === "subtotal"}
                      dir={listSort.dir}
                      onClick={() => setListSort((s) => toggleSort(s, "subtotal"))}
                      className="text-right"
                    />
                    <SortableTh
                      label="Mark-up"
                      active={listSort.key === "markup"}
                      dir={listSort.dir}
                      onClick={() => setListSort((s) => toggleSort(s, "markup"))}
                      className="text-right"
                    />
                    <SortableTh
                      label="청구합계"
                      active={listSort.key === "total"}
                      dir={listSort.dir}
                      onClick={() => setListSort((s) => toggleSort(s, "total"))}
                      className="text-right"
                    />
                    <th className="text-white text-xs font-normal w-[88px]">작업</th>
                  </tr>
                </thead>
                <tbody>
                  {sortedInvoices.length === 0 ? (
                    <tr>
                      <td colSpan={8} className="text-center text-navy-500 py-8">
                        {invoices.length === 0
                          ? "청구서가 없습니다. 절사·대사 확정 후 생성하세요."
                          : "필터 조건에 맞는 청구서가 없습니다."}
                      </td>
                    </tr>
                  ) : (
                    sortedInvoices.map((inv) => (
                      <tr
                        key={inv.id}
                        className={cn(
                          "cursor-pointer hover:bg-navy-100 transition-colors",
                          selectedId === inv.id && "bg-navy-100 ring-1 ring-inset ring-navy-300"
                        )}
                        onClick={() => setSelectedId(inv.id)}
                      >
                        <td className="font-medium">{inv.company.nameKo}</td>
                        <td className="font-mono text-xs">{inv.company.code}</td>
                        <td>{inv.invoiceType === "OVERSEAS" ? "해외" : "국내"}</td>
                        <td>
                          <StatusBadge status={inv.status} />
                        </td>
                        <AmountCell value={inv.subtotal} />
                        <AmountCell value={inv.markupAmount} />
                        <AmountCell value={inv.totalAmount} />
                        <td className="space-x-1 whitespace-nowrap">
                          {inv.status === "DRAFT" && (
                            <button
                              type="button"
                              className="text-xs text-navy-600 hover:underline"
                              onClick={(e) => {
                                e.stopPropagation();
                                approve(inv.id);
                              }}
                            >
                              승인
                            </button>
                          )}
                          {inv.status === "APPROVED" && (
                            <button
                              type="button"
                              className="text-xs text-green-600 hover:underline"
                              onClick={(e) => {
                                e.stopPropagation();
                                issue(inv.id);
                              }}
                            >
                              발행
                            </button>
                          )}
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
                {sortedInvoices.length > 0 && (
                  <tfoot>
                    <tr>
                      <td colSpan={4}>
                        합계 ({listTotals.count}건
                        {filteredInvoices.length !== invoices.length
                          ? ` · 필터 ${filteredInvoices.length}/${invoices.length}`
                          : ""}
                        )
                      </td>
                      <td className="amount">{formatAmount(listTotals.subtotal)}</td>
                      <td className="amount">{formatAmount(listTotals.markup)}</td>
                      <td className="amount text-base">
                        {formatAmount(listTotals.total)}
                      </td>
                      <td></td>
                    </tr>
                  </tfoot>
                )}
              </table>
            </div>
          </div>
        )}

        {selected && (
          <InvoiceDetailModal
            invoiceId={selected.id}
            listInvoice={selected}
            onClose={() => setSelectedId(null)}
            onApprove={approve}
            onIssue={issue}
          />
        )}
      </ProjectRequired>
    </>
  );
}

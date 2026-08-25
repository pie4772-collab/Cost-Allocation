import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function formatAmount(value: string | number | bigint | null | undefined): string {
  if (value === null || value === undefined) return "0";
  const n = typeof value === "bigint" ? Number(value) : Number(value);
  if (isNaN(n)) return "0";
  return n.toLocaleString("ko-KR");
}

export function formatPercent(value: number | string): string {
  const n = typeof value === "string" ? parseFloat(value) : value;
  return (n * 100).toFixed(6);
}

export function statusColor(status: string): string {
  const map: Record<string, string> = {
    DRAFT: "bg-gray-100 text-gray-700",
    CONFIRMED: "bg-blue-100 text-blue-700",
    LOCKED: "bg-gray-200 text-gray-800",
    PENDING_APPROVAL: "bg-orange-100 text-orange-700",
    APPROVED: "bg-green-100 text-green-700",
    REJECTED: "bg-red-100 text-red-700",
    EXECUTED: "bg-blue-100 text-blue-700",
    ISSUED: "bg-green-100 text-green-700",
    CLOSED: "bg-gray-200 text-gray-800",
    COST_CONFIRMED: "bg-blue-100 text-blue-700",
    RATES_APPROVED: "bg-green-100 text-green-700",
    CALCULATED: "bg-blue-100 text-blue-700",
    RECONCILED: "bg-green-100 text-green-700",
    BILLING_APPROVED: "bg-green-100 text-green-700",
  };
  return map[status] ?? "bg-gray-100 text-gray-600";
}

export const STATUS_LABELS: Record<string, string> = {
  DRAFT: "초안",
  CONFIRMED: "확정",
  LOCKED: "잠금",
  PENDING_APPROVAL: "확정대기",
  APPROVED: "확정",
  REJECTED: "반려",
  EXECUTED: "실행됨",
  ISSUED: "발행",
  CLOSED: "마감",
  COST_CONFIRMED: "원가확정",
  RATES_APPROVED: "배분율확정",
  CALCULATED: "계산완료",
  RECONCILED: "대사완료",
  BILLING_APPROVED: "청구승인",
  CANCELLED: "취소",
  PREVIEW: "미리보기",
  SUPERSEDED: "대체됨",
};

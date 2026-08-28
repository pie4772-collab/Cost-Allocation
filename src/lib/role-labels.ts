export const ALL_ROLES = [
  "Admin",
  "CostManager",
  "AllocationManager",
  "Approver",
  "BillingManager",
  "Auditor",
  "Viewer",
] as const;

export type AppRoleName = (typeof ALL_ROLES)[number];

export const ROLE_LABELS: Record<AppRoleName, string> = {
  Admin: "관리자",
  CostManager: "원가 담당",
  AllocationManager: "배부 담당",
  Approver: "승인자",
  BillingManager: "청구 담당",
  Auditor: "감사",
  Viewer: "조회",
};

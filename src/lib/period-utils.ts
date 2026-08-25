export type PeriodCadence = "SEMI_ANNUAL" | "MONTHLY";

export type PeriodInfo = {
  cadence?: PeriodCadence | string;
  half?: number;
  month?: number | null;
  year?: number;
  label?: string;
};

export function isMonthlyPeriod(period: PeriodInfo | null | undefined): boolean {
  return period?.cadence === "MONTHLY";
}

/** 월별 1~6월: 배분율 합계 100% 미만/초과도 확정·배분 허용 */
export function allowsFlexibleRateTotal(
  period: PeriodInfo | null | undefined
): boolean {
  return (
    isMonthlyPeriod(period) &&
    !!period?.month &&
    period.month >= 1 &&
    period.month <= 6
  );
}

export function requiresExactRateTotal(project: {
  strictRateValidation?: boolean;
  period?: PeriodInfo | null;
} | null | undefined): boolean {
  if (!project) return true;
  if (allowsFlexibleRateTotal(project.period)) return false;
  return project.strictRateValidation ?? true;
}

export function monthsForPeriod(period: PeriodInfo | null | undefined): number[] {
  if (!period) return [1, 2, 3, 4, 5, 6];
  if (isMonthlyPeriod(period) && period.month) return [period.month];
  return period.half === 2 ? [7, 8, 9, 10, 11, 12] : [1, 2, 3, 4, 5, 6];
}

export function periodScopeLabel(period: PeriodInfo | null | undefined): string {
  if (!period) return "상반기 (1~6월)";
  if (isMonthlyPeriod(period) && period.month) {
    return `${period.month}월`;
  }
  return period.half === 2 ? "하반기 (7~12월)" : "상반기 (1~6월)";
}

export function costTotalLabel(period: PeriodInfo | null | undefined): string {
  return isMonthlyPeriod(period) ? "월 합계" : "반기합계";
}

export function costGrandTotalLabel(period: PeriodInfo | null | undefined): string {
  return isMonthlyPeriod(period) ? "월 총계" : "반기 총계";
}

export function projectListPath(period: PeriodInfo | null | undefined): string {
  return isMonthlyPeriod(period) ? "/monthly-projects" : "/projects";
}

export function projectTypeLabel(period: PeriodInfo | null | undefined): string {
  return isMonthlyPeriod(period) ? "월별" : "반기";
}

export function previousMonthly(year: number, month: number) {
  if (month === 1) return { year: year - 1, month: 12 };
  return { year, month: month - 1 };
}

export function monthDateRange(year: number, month: number) {
  const startDate = new Date(year, month - 1, 1);
  const endDate = new Date(year, month, 0);
  return { startDate, endDate };
}

export function monthlyPeriodLabel(year: number, month: number) {
  return `${year}년 ${month}월`;
}

export function semiAnnualPeriodLabel(year: number, half: number) {
  return `${year} H${half}`;
}

export function halfFromMonth(month: number) {
  return month <= 6 ? 1 : 2;
}

/** 월별 → 반기 순 (같은 유형 내에서는 연도·기간 내림차순) */
export function compareProjectsByPeriod<
  T extends { period: PeriodInfo & { periodKey?: number } },
>(a: T, b: T): number {
  const cadenceRank = (p: PeriodInfo) => (isMonthlyPeriod(p) ? 0 : 1);
  const byCadence = cadenceRank(a.period) - cadenceRank(b.period);
  if (byCadence !== 0) return byCadence;

  const yearDiff = (b.period.year ?? 0) - (a.period.year ?? 0);
  if (yearDiff !== 0) return yearDiff;

  const keyA = a.period.periodKey ?? a.period.month ?? a.period.half ?? 0;
  const keyB = b.period.periodKey ?? b.period.month ?? b.period.half ?? 0;
  return keyB - keyA;
}

export function sortProjectsByPeriod<
  T extends { period: PeriodInfo & { periodKey?: number } },
>(projects: T[]): T[] {
  return [...projects].sort(compareProjectsByPeriod);
}

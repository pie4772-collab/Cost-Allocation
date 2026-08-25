/** 배분율 초과분 대사 시 조정 대상 법인 (케이비아이동양철관) */
export const RATE_RECONCILIATION_COMPANY_CODE = "STEEL";
export const RATE_RECONCILIATION_COMPANY_NAME = "케이비아이동양철관 주식회사";

export interface RateReconciliationCompanyRef {
  companyId: string;
  companyCode: string;
  companyName: string;
}

export function findRateReconciliationCompany<
  T extends RateReconciliationCompanyRef,
>(rates: T[]): T | undefined {
  return rates.find(
    (r) =>
      r.companyCode === RATE_RECONCILIATION_COMPANY_CODE ||
      r.companyName === RATE_RECONCILIATION_COMPANY_NAME
  );
}

export function rateReconciliationCompanyLabel(): string {
  return `${RATE_RECONCILIATION_COMPANY_NAME} (${RATE_RECONCILIATION_COMPANY_CODE})`;
}

import type { CompanyType } from "@prisma/client";
import {
  roundDown,
  decimalToNumber,
  sumBigInt,
  createChecksum,
  isRateTotalValid,
  isRateOverExcessAcceptable,
  isRateTotalAcceptable,
  RATE_TOTAL_TARGET,
} from "./math";
import {
  findRateReconciliationCompany,
  rateReconciliationCompanyLabel,
} from "./rate-reconciliation";

export interface CostInput {
  costAccountId: string;
  accountCode: string;
  accountName: string;
  totalAmount: bigint;
}

export interface RateInput {
  companyId: string;
  companyCode: string;
  companyName: string;
  companyType: CompanyType;
  rate: number;
}

export interface AllocationEngineInput {
  projectId: string;
  costs: CostInput[];
  rates: RateInput[];
  markupRate?: number;
}

export interface AccountAllocationRow {
  costAccountId: string;
  companyId: string;
  accountTotal: bigint;
  rate: number;
  rawAmount: number;
  allocatedAmount: bigint;
}

export interface CompanySummaryRow {
  companyId: string;
  companyCode: string;
  companyName: string;
  companyType: CompanyType;
  preRoundTotal: bigint;
  allocationAmount: bigint;
  markupAmount: bigint;
  billingAmount: bigint;
}

export interface AccountReconciliation {
  costAccountId: string;
  accountCode: string;
  accountName: string;
  sourceTotal: bigint;
  allocatedSum: bigint;
  roundingDiff: bigint;
}

export interface AllocationEngineResult {
  details: AccountAllocationRow[];
  summaries: CompanySummaryRow[];
  accountReconciliation: AccountReconciliation[];
  totalCost: bigint;
  totalAllocated: bigint;
  totalMarkup: bigint;
  totalBilling: bigint;
  roundingDiff: bigint;
  rateTotal: number;
  rateValid: boolean;
  rateOverExcessAcceptable: boolean;
  rateReconciliation?: {
    companyId: string;
    companyName: string;
    adjustment: bigint;
    rateExcessPercent: number;
  };
  checksum: string;
}

export function validateRates(rates: RateInput[]): {
  total: number;
  valid: boolean;
  exactValid: boolean;
  overExcessAcceptable: boolean;
  message: string;
} {
  const total = rates.reduce((sum, r) => sum + r.rate, 0);
  const totalPercent = total * 100;
  const exactValid = isRateTotalValid(totalPercent);
  const overExcessAcceptable = isRateOverExcessAcceptable(totalPercent);
  const valid = isRateTotalAcceptable(totalPercent);
  const steelLabel = rateReconciliationCompanyLabel();
  return {
    total: totalPercent,
    valid,
    exactValid,
    overExcessAcceptable,
    message: exactValid
      ? "배분율 합계가 100%입니다."
      : overExcessAcceptable
        ? `배분율 합계가 ${totalPercent.toFixed(6)}%입니다. 초과분(0.01% 이내)은 원가 총액과 배분액 차이를 ${steelLabel} 비용으로 대사합니다.`
        : `배분율 합계가 ${totalPercent.toFixed(6)}%입니다. 정확히 100.000000%이거나 100% 초과 0.01% 이내여야 합니다.`,
  };
}

function applyRateExcessReconciliation(
  result: Omit<
    AllocationEngineResult,
    "rateReconciliation" | "rateOverExcessAcceptable"
  >,
  rates: RateInput[],
  markupRate: number,
  rateExcessPercent: number
): AllocationEngineResult {
  const steel = findRateReconciliationCompany(rates);
  if (!steel) {
    throw new Error(
      `배분율 합계 보정을 위해 ${rateReconciliationCompanyLabel()} 법인이 배분율에 포함되어야 합니다.`
    );
  }

  const adjustment = result.totalCost - result.totalAllocated;
  if (adjustment === 0n) {
    return {
      ...result,
      rateOverExcessAcceptable: true,
    };
  }

  const steelDetails = result.details.filter((d) => d.companyId === steel.companyId);
  if (steelDetails.length === 0) {
    throw new Error(
      `${rateReconciliationCompanyLabel()} 법인의 계정별 배분 내역이 없습니다.`
    );
  }

  const targetDetail = steelDetails.reduce((max, d) =>
    d.allocatedAmount >= max.allocatedAmount ? d : max
  );
  const newDetailAmount = targetDetail.allocatedAmount + adjustment;
  if (newDetailAmount < 0n) {
    throw new Error(
      `${rateReconciliationCompanyLabel()} 배분액 대사 후 금액이 음수가 됩니다. 배분율을 확인하세요.`
    );
  }
  const steelSummaryIdx = result.summaries.findIndex(
    (s) => s.companyId === steel.companyId
  );
  if (steelSummaryIdx < 0) {
    throw new Error(
      `${rateReconciliationCompanyLabel()} 법인의 배분 요약이 없습니다.`
    );
  }

  const steelSummary = result.summaries[steelSummaryIdx];
  const newAllocationAmount = steelSummary.allocationAmount + adjustment;
  if (newAllocationAmount < 0n) {
    throw new Error(
      `${rateReconciliationCompanyLabel()} 배분액 대사 후 금액이 음수가 됩니다. 배분율을 확인하세요.`
    );
  }

  targetDetail.allocatedAmount = newDetailAmount;

  const summaries = result.summaries.map((summary, idx) => {
    if (idx !== steelSummaryIdx) return summary;

    const markupAmount =
      summary.companyType === "OVERSEAS"
        ? roundDown(Number(newAllocationAmount) * markupRate, 10)
        : 0n;

    return {
      ...summary,
      preRoundTotal: summary.preRoundTotal + adjustment,
      allocationAmount: newAllocationAmount,
      markupAmount,
      billingAmount: newAllocationAmount + markupAmount,
    };
  });

  const accountReconciliation = result.accountReconciliation.map((row) => {
    if (row.costAccountId !== targetDetail.costAccountId) return row;
    const accountDetails = result.details.filter(
      (d) => d.costAccountId === row.costAccountId
    );
    const allocatedSum = sumBigInt(accountDetails.map((d) => d.allocatedAmount));
    return {
      ...row,
      allocatedSum,
      roundingDiff: row.sourceTotal - allocatedSum,
    };
  });

  const totalAllocated = sumBigInt(summaries.map((s) => s.allocationAmount));
  const totalMarkup = sumBigInt(summaries.map((s) => s.markupAmount));
  const totalBilling = sumBigInt(summaries.map((s) => s.billingAmount));
  const roundingDiff = result.totalCost - totalAllocated;

  return {
    ...result,
    summaries,
    accountReconciliation,
    totalAllocated,
    totalMarkup,
    totalBilling,
    roundingDiff,
    rateOverExcessAcceptable: true,
    rateReconciliation: {
      companyId: steel.companyId,
      companyName: steel.companyName,
      adjustment,
      rateExcessPercent,
    },
  };
}

export function runAllocation(
  input: AllocationEngineInput
): AllocationEngineResult {
  const markupRate = input.markupRate ?? 0.05;
  const rateValidation = validateRates(input.rates);

  // Step 1: Account-level allocation with ROUNDDOWN to KRW
  const details: AccountAllocationRow[] = [];
  for (const cost of input.costs) {
    for (const rate of input.rates) {
      const rawAmount = Number(cost.totalAmount) * rate.rate;
      const allocatedAmount = roundDown(rawAmount, 1);
      details.push({
        costAccountId: cost.costAccountId,
        companyId: rate.companyId,
        accountTotal: cost.totalAmount,
        rate: rate.rate,
        rawAmount,
        allocatedAmount,
      });
    }
  }

  // Step 2: Company-level summary with ROUNDDOWN to 10 KRW
  const summaries: CompanySummaryRow[] = input.rates.map((rate) => {
    const companyDetails = details.filter((d) => d.companyId === rate.companyId);
    const preRoundTotal = sumBigInt(companyDetails.map((d) => d.allocatedAmount));
    const allocationAmount = roundDown(preRoundTotal, 10);
    const markupAmount =
      rate.companyType === "OVERSEAS"
        ? roundDown(Number(allocationAmount) * markupRate, 10)
        : 0n;
    const billingAmount = allocationAmount + markupAmount;

    return {
      companyId: rate.companyId,
      companyCode: rate.companyCode,
      companyName: rate.companyName,
      companyType: rate.companyType,
      preRoundTotal,
      allocationAmount,
      markupAmount,
      billingAmount,
    };
  });

  // Step 3: Account reconciliation
  const accountReconciliation: AccountReconciliation[] = input.costs.map(
    (cost) => {
      const accountDetails = details.filter(
        (d) => d.costAccountId === cost.costAccountId
      );
      const allocatedSum = sumBigInt(
        accountDetails.map((d) => d.allocatedAmount)
      );
      return {
        costAccountId: cost.costAccountId,
        accountCode: cost.accountCode,
        accountName: cost.accountName,
        sourceTotal: cost.totalAmount,
        allocatedSum,
        roundingDiff: cost.totalAmount - allocatedSum,
      };
    }
  );

  const totalCost = sumBigInt(input.costs.map((c) => c.totalAmount));
  const totalAllocated = sumBigInt(summaries.map((s) => s.allocationAmount));
  const totalMarkup = sumBigInt(summaries.map((s) => s.markupAmount));
  const totalBilling = sumBigInt(summaries.map((s) => s.billingAmount));
  const roundingDiff = totalCost - totalAllocated;

  const checksum = createChecksum({
    projectId: input.projectId,
    costs: input.costs.map((c) => ({
      id: c.costAccountId,
      amount: c.totalAmount.toString(),
    })),
    rates: input.rates.map((r) => ({
      id: r.companyId,
      rate: r.rate,
    })),
    markupRate,
  });

  const baseResult = {
    details,
    summaries,
    accountReconciliation,
    totalCost,
    totalAllocated,
    totalMarkup,
    totalBilling,
    roundingDiff,
    rateTotal: rateValidation.total,
    rateValid: rateValidation.valid,
    checksum,
  };

  if (rateValidation.overExcessAcceptable) {
    const rateExcessPercent = rateValidation.total - RATE_TOTAL_TARGET;
    return applyRateExcessReconciliation(
      baseResult,
      input.rates,
      markupRate,
      rateExcessPercent
    );
  }

  return {
    ...baseResult,
    rateOverExcessAcceptable: false,
  };
}

export function buildEngineInputFromDb(
  projectId: string,
  costs: Array<{
    costAccountId: string;
    code: string;
    nameKo: string;
    totalAmount: bigint;
  }>,
  rates: Array<{
    companyId: string;
    code: string;
    nameKo: string;
    companyType: CompanyType;
    rate: { toString(): string };
  }>,
  markupRate?: number
): AllocationEngineInput {
  return {
    projectId,
    costs: costs.map((c) => ({
      costAccountId: c.costAccountId,
      accountCode: c.code,
      accountName: c.nameKo,
      totalAmount: c.totalAmount,
    })),
    rates: rates.map((r) => ({
      companyId: r.companyId,
      companyCode: r.code,
      companyName: r.nameKo,
      companyType: r.companyType,
      rate: decimalToNumber(r.rate),
    })),
    markupRate,
  };
}

export { RATE_TOTAL_TARGET };

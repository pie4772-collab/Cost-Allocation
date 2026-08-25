import { describe, it, expect } from "vitest";
import {
  roundDown,
  isRateTotalValid,
  isRateOverExcessAcceptable,
  isRateTotalAcceptable,
} from "../math";
import { runAllocation, validateRates } from "../allocation-engine";
import {
  RATE_RECONCILIATION_COMPANY_CODE,
  RATE_RECONCILIATION_COMPANY_NAME,
} from "../rate-reconciliation";

describe("roundDown", () => {
  it("truncates to whole KRW toward zero", () => {
    expect(roundDown(1234.9)).toBe(1234n);
    expect(roundDown(1234.1)).toBe(1234n);
    expect(roundDown(-1234.9)).toBe(-1234n);
    expect(roundDown(-1234.1)).toBe(-1234n);
  });

  it("truncates to 10 KRW toward zero", () => {
    expect(roundDown(1234, 10)).toBe(1230n);
    expect(roundDown(1239, 10)).toBe(1230n);
    expect(roundDown(-1234, 10)).toBe(-1230n);
    expect(roundDown(-1239, 10)).toBe(-1230n);
  });
});

describe("validateRates", () => {
  it("accepts exactly 100%", () => {
    const rates = [
      { companyId: "1", companyCode: "A", companyName: "A", companyType: "DOMESTIC" as const, rate: 0.5 },
      { companyId: "2", companyCode: "B", companyName: "B", companyType: "DOMESTIC" as const, rate: 0.5 },
    ];
    const result = validateRates(rates);
    expect(result.valid).toBe(true);
    expect(result.total).toBe(100);
  });

  it("accepts 100.001545% as over-excess within 0.01%", () => {
    const rates = Array.from({ length: 30 }, (_, i) => ({
      companyId: String(i),
      companyCode: i === 5 ? RATE_RECONCILIATION_COMPANY_CODE : `C${i}`,
      companyName: i === 5 ? RATE_RECONCILIATION_COMPANY_NAME : `Company ${i}`,
      companyType: "DOMESTIC" as const,
      rate: i === 29 ? 0.03334855 : 0.033333333333,
    }));
    rates[29].rate += 0.00001545 / 100;
    const result = validateRates(rates);
    expect(result.exactValid).toBe(false);
    expect(result.overExcessAcceptable).toBe(true);
    expect(result.valid).toBe(true);
  });

  it("rejects 100.02% over-excess", () => {
    const rates = [
      { companyId: "1", companyCode: "A", companyName: "A", companyType: "DOMESTIC" as const, rate: 0.5002 },
      { companyId: "2", companyCode: "B", companyName: "B", companyType: "DOMESTIC" as const, rate: 0.5000 },
    ];
    const result = validateRates(rates);
    expect(result.valid).toBe(false);
  });
});

describe("runAllocation", () => {
  const baseInput = {
    projectId: "test",
    costs: [
      { costAccountId: "acc1", accountCode: "6100", accountName: "임차료", totalAmount: 10000000n },
      { costAccountId: "acc2", accountCode: "6200", accountName: "통신비", totalAmount: 5000000n },
    ],
    rates: [
      { companyId: "c1", companyCode: "KR01", companyName: "국내법인1", companyType: "DOMESTIC" as const, rate: 0.6 },
      { companyId: "c2", companyCode: "US01", companyName: "해외법인1", companyType: "OVERSEAS" as const, rate: 0.4 },
    ],
  };

  it("applies KRW rounding at account level", () => {
    const result = runAllocation(baseInput);
    const detail = result.details.find(
      (d) => d.costAccountId === "acc1" && d.companyId === "c1"
    );
    expect(detail?.allocatedAmount).toBe(6000000n);
  });

  it("applies 10 KRW rounding at company level", () => {
    const result = runAllocation(baseInput);
    const domestic = result.summaries.find((s) => s.companyId === "c1");
    expect(Number(domestic!.allocationAmount) % 10).toBe(0);
  });

  it("applies 5% markup only to overseas", () => {
    const result = runAllocation(baseInput);
    const domestic = result.summaries.find((s) => s.companyId === "c1");
    const overseas = result.summaries.find((s) => s.companyId === "c2");
    expect(domestic?.markupAmount).toBe(0n);
    expect(overseas!.markupAmount).toBeGreaterThan(0n);
    expect(Number(overseas!.markupAmount) % 10).toBe(0);
  });

  it("produces deterministic checksum", () => {
    const r1 = runAllocation(baseInput);
    const r2 = runAllocation(baseInput);
    expect(r1.checksum).toBe(r2.checksum);
  });

  it("calculates billing = allocation + markup for overseas", () => {
    const result = runAllocation(baseInput);
    for (const s of result.summaries) {
      expect(s.billingAmount).toBe(s.allocationAmount + s.markupAmount);
    }
  });

  it("reconciles over-excess rates to STEEL company allocation", () => {
    const totalCost = 100000000n;
    const rates = [
      {
        companyId: "steel",
        companyCode: RATE_RECONCILIATION_COMPANY_CODE,
        companyName: RATE_RECONCILIATION_COMPANY_NAME,
        companyType: "DOMESTIC" as const,
        rate: 0.33334855,
      },
      {
        companyId: "other",
        companyCode: "C2",
        companyName: "Other Co",
        companyType: "DOMESTIC" as const,
        rate: 0.666666785455,
      },
    ];
    const result = runAllocation({
      projectId: "test-over",
      costs: [
        {
          costAccountId: "acc1",
          accountCode: "6100",
          accountName: "임차료",
          totalAmount: totalCost,
        },
      ],
      rates,
    });

    expect(result.rateOverExcessAcceptable).toBe(true);
    expect(result.totalAllocated).toBe(totalCost);
    expect(result.roundingDiff).toBe(0n);
    expect(result.rateReconciliation?.companyId).toBe("steel");
    expect(result.rateReconciliation?.adjustment).not.toBe(0n);

    const steelSummary = result.summaries.find((s) => s.companyId === "steel");
    expect(steelSummary).toBeDefined();
    const steelDetail = result.details.find(
      (d) => d.companyId === "steel" && d.costAccountId === "acc1"
    );
    expect(steelDetail!.allocatedAmount).toBeGreaterThan(0n);
    expect(steelSummary!.allocationAmount).toBeGreaterThan(0n);
  });
});

describe("isRateTotalValid", () => {
  it("validates 6 decimal precision", () => {
    expect(isRateTotalValid(100)).toBe(true);
    expect(isRateTotalValid(100.0000005)).toBe(true);
    expect(isRateTotalValid(100.001545)).toBe(false);
  });
});

describe("isRateOverExcessAcceptable", () => {
  it("allows up to 0.01% over 100%", () => {
    expect(isRateOverExcessAcceptable(100.001545)).toBe(true);
    expect(isRateOverExcessAcceptable(100.01)).toBe(true);
    expect(isRateOverExcessAcceptable(100.0100001)).toBe(false);
    expect(isRateOverExcessAcceptable(99.9)).toBe(false);
    expect(isRateOverExcessAcceptable(100)).toBe(false);
  });
});

describe("isRateTotalAcceptable", () => {
  it("accepts exact 100% or small over-excess", () => {
    expect(isRateTotalAcceptable(100)).toBe(true);
    expect(isRateTotalAcceptable(100.001545)).toBe(true);
    expect(isRateTotalAcceptable(100.02)).toBe(false);
  });
});

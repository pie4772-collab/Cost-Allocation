import prisma from "../db";
import {
  runAllocation,
  buildEngineInputFromDb,
  validateRates,
} from "../allocation-engine";
import { createAuditLog } from "../audit";
import type { ProjectStatus, RunType } from "@prisma/client";
import { decimalToNumber } from "../math";
import { allowsFlexibleRateTotal, requiresExactRateTotal } from "../period-utils";

const LOCKED_PROJECT_STATUSES: ProjectStatus[] = ["CLOSED"];

export async function getProjectCosts(
  projectId: string,
  options: { includeDraft?: boolean } = {}
) {
  const costs = await prisma.monthlyCost.groupBy({
    by: ["costAccountId"],
    where: {
      projectId,
      status: options.includeDraft
        ? { in: ["DRAFT", "CONFIRMED"] }
        : "CONFIRMED",
    },
    _sum: { amount: true },
  });

  const accounts = await prisma.costAccount.findMany({
    where: {
      id: { in: costs.map((c) => c.costAccountId) },
      isActive: true,
      deletedAt: null,
    },
  });

  return costs
    .map((c) => {
      const account = accounts.find((a) => a.id === c.costAccountId);
      if (!account) return null;
      return {
        costAccountId: c.costAccountId,
        code: account.code,
        nameKo: account.nameKo,
        totalAmount: c._sum.amount ?? 0n,
      };
    })
    .filter(Boolean) as Array<{
    costAccountId: string;
    code: string;
    nameKo: string;
    totalAmount: bigint;
  }>;
}

export async function getApprovedRates(projectId: string) {
  const rateVersion = await prisma.allocationRateVersion.findFirst({
    where: { projectId, status: "APPROVED" },
    orderBy: { version: "desc" },
    include: {
      rates: {
        include: { company: true },
      },
    },
  });
  return rateVersion;
}

export async function assertProjectEditable(projectId: string) {
  const project = await prisma.allocationProject.findUniqueOrThrow({
    where: { id: projectId },
    include: { period: true },
  });
  if (LOCKED_PROJECT_STATUSES.includes(project.status)) {
    throw new Error("마감된 프로젝트는 수정할 수 없습니다.");
  }
  return project;
}

export async function previewAllocation(
  projectId: string,
  rateVersionId: string,
  userId: string,
  options: { includeDraftCosts?: boolean } = {}
) {
  const project = await prisma.allocationProject.findUniqueOrThrow({
    where: { id: projectId },
    include: { period: true },
  });

  const rateVersion = await prisma.allocationRateVersion.findUniqueOrThrow({
    where: { id: rateVersionId },
    include: {
      rates: { include: { company: true } },
    },
  });

  const costs = await getProjectCosts(projectId, {
    includeDraft: options.includeDraftCosts,
  });
  if (costs.length === 0) {
    throw new Error(
      options.includeDraftCosts
        ? "원가 데이터가 없습니다. 원가를 입력하세요."
        : "확정된 원가 데이터가 없습니다. 원가 확정 후 실행하세요."
    );
  }

  const engineInput = buildEngineInputFromDb(
    projectId,
    costs,
    rateVersion.rates.map((r) => ({
      companyId: r.companyId,
      code: r.company.code,
      nameKo: r.company.nameKo,
      companyType: r.company.companyType,
      rate: r.rate,
    })),
    decimalToNumber(project.markupRate)
  );

  const result = runAllocation(engineInput);

  return {
    project,
    rateVersion,
    result,
    canExecute:
      (result.rateValid || allowsFlexibleRateTotal(project.period)) &&
      rateVersion.status === "APPROVED",
    canApprove:
      project.status === "COST_CONFIRMED" ||
      project.status === "RATES_APPROVED",
  };
}

export async function executeAllocation(
  projectId: string,
  rateVersionId: string,
  userId: string,
  runType: RunType = "FINAL"
) {
  const project = await assertProjectEditable(projectId);

  if (runType === "FINAL" && project.status === "DRAFT") {
    throw new Error("원가가 확정되지 않았습니다.");
  }

  const rateVersion = await prisma.allocationRateVersion.findUniqueOrThrow({
    where: { id: rateVersionId },
  });

  if (runType === "FINAL" && rateVersion.status !== "APPROVED") {
    throw new Error("확정된 배분율로만 최종 계산할 수 있습니다.");
  }

  const preview = await previewAllocation(projectId, rateVersionId, userId, {
    includeDraftCosts: runType === "PREVIEW",
  });

  if (
    runType === "FINAL" &&
    requiresExactRateTotal(project) &&
    !preview.result.rateValid
  ) {
    throw new Error(
      `배분율 합계가 ${preview.result.rateTotal.toFixed(6)}%입니다. 100% 또는 100% 초과 0.01% 이내일 때만 실행 가능합니다.`
    );
  }

  const existingRun = await prisma.allocationRun.findFirst({
    where: {
      projectId,
      rateVersionId,
      runType: "FINAL",
      status: { in: ["EXECUTED", "APPROVED"] },
    },
  });

  if (runType === "FINAL" && existingRun) {
    throw new Error("이미 최종 배부가 실행되었습니다. 새 버전을 생성하세요.");
  }

  const lastRun = await prisma.allocationRun.findFirst({
    where: { projectId, rateVersionId },
    orderBy: { runNumber: "desc" },
  });
  const runNumber = (lastRun?.runNumber ?? 0) + 1;

  const inputSnapshot = JSON.parse(
    JSON.stringify({
      costs: preview.result.accountReconciliation.map((c) => ({
        costAccountId: c.costAccountId,
        accountCode: c.accountCode,
        accountName: c.accountName,
        sourceTotal: c.sourceTotal.toString(),
        allocatedSum: c.allocatedSum.toString(),
        roundingDiff: c.roundingDiff.toString(),
      })),
      rateTotal: preview.result.rateTotal,
      rateReconciliation: preview.result.rateReconciliation
        ? {
            ...preview.result.rateReconciliation,
            adjustment: preview.result.rateReconciliation.adjustment.toString(),
          }
        : undefined,
      markupRate: decimalToNumber(project.markupRate),
    })
  );

  return prisma.$transaction(async (tx) => {
    const run = await tx.allocationRun.create({
      data: {
        projectId,
        rateVersionId,
        runNumber,
        runType,
        status: runType === "PREVIEW" ? "PREVIEW" : "EXECUTED",
        inputSnapshot,
        checksum: preview.result.checksum,
        totalCost: preview.result.totalCost,
        totalAllocated: preview.result.totalAllocated,
        totalMarkup: preview.result.totalMarkup,
        totalBilling: preview.result.totalBilling,
        roundingDiff: preview.result.roundingDiff,
        createdById: userId,
        details: {
          create: preview.result.details.map((d) => ({
            companyId: d.companyId,
            costAccountId: d.costAccountId,
            accountTotal: d.accountTotal,
            rate: d.rate,
            rawAmount: BigInt(Math.round(d.rawAmount)),
            allocatedAmount: d.allocatedAmount,
          })),
        },
        summaries: {
          create: preview.result.summaries.map((s) => ({
            companyId: s.companyId,
            preRoundTotal: s.preRoundTotal,
            allocationAmount: s.allocationAmount,
            markupAmount: s.markupAmount,
            billingAmount: s.billingAmount,
          })),
        },
      },
      include: { details: true, summaries: true },
    });

    if (runType === "FINAL") {
      await tx.allocationProject.update({
        where: { id: projectId },
        data: { status: "CALCULATED" },
      });
    }

    await createAuditLog(
      {
        userId,
        action: "ALLOCATION_EXECUTE",
        entityType: "AllocationRun",
        entityId: run.id,
        afterData: { runNumber, runType, checksum: preview.result.checksum },
      },
      tx
    );

    return run;
  });
}

const POST_ALLOCATION_STATUSES: ProjectStatus[] = [
  "CALCULATED",
  "RECONCILED",
  "BILLING_APPROVED",
];

/** 프로젝트의 배분 실행 결과(대사·청구 포함)를 삭제하고 재계산 가능 상태로 되돌림 */
export async function cancelProjectAllocation(
  projectId: string,
  userId: string,
  options: { runId?: string } = {}
) {
  const project = await prisma.allocationProject.findUniqueOrThrow({
    where: { id: projectId },
  });

  if (project.status === "CLOSED") {
    throw new Error("마감된 프로젝트는 배분 계산을 취소할 수 없습니다.");
  }

  const runs = await prisma.allocationRun.findMany({
    where: {
      projectId,
      ...(options.runId ? { id: options.runId } : {}),
    },
    select: { id: true, runType: true, status: true },
  });

  if (runs.length === 0) {
    throw new Error("취소할 배분 실행 결과가 없습니다.");
  }

  const runIds = runs.map((r) => r.id);

  return prisma.$transaction(async (tx) => {
    const invoices = await tx.invoice.findMany({
      where: { runId: { in: runIds } },
      select: { id: true, status: true },
    });
    const issued = invoices.filter((i) => i.status === "ISSUED");
    if (issued.length > 0) {
      throw new Error("발행된 청구서가 있어 배분 계산을 취소할 수 없습니다.");
    }

    await tx.invoiceLine.deleteMany({
      where: { invoice: { runId: { in: runIds } } },
    });
    await tx.invoice.deleteMany({ where: { runId: { in: runIds } } });
    await tx.reconciliationResult.deleteMany({ where: { runId: { in: runIds } } });
    const deleted = await tx.allocationRun.deleteMany({
      where: { id: { in: runIds } },
    });

    const remainingRuns = await tx.allocationRun.count({ where: { projectId } });
    const remainingFinalRuns = await tx.allocationRun.count({
      where: {
        projectId,
        runType: "FINAL",
        status: { in: ["EXECUTED", "APPROVED"] },
      },
    });

    let projectStatus = project.status;
    if (
      remainingFinalRuns === 0 &&
      POST_ALLOCATION_STATUSES.includes(project.status)
    ) {
      await tx.allocationProject.update({
        where: { id: projectId },
        data: { status: "RATES_APPROVED" },
      });
      projectStatus = "RATES_APPROVED";
    }

    await tx.approvalRequest.deleteMany({
      where: {
        entityId: { in: runIds },
        type: { in: ["ALLOCATION_APPROVAL", "INVOICE_APPROVAL", "INVOICE_ISSUE"] },
      },
    });

    await createAuditLog(
      {
        userId,
        action: "ALLOCATION_CANCEL",
        entityType: "AllocationProject",
        entityId: projectId,
        afterData: {
          deletedRunIds: runIds,
          deletedCount: deleted.count,
          remainingRuns,
          projectStatus,
        },
      },
      tx
    );

    return {
      deletedCount: deleted.count,
      remainingRuns,
      projectStatus,
      project: await tx.allocationProject.findUniqueOrThrow({
        where: { id: projectId },
        include: { period: true },
      }),
    };
  });
}

export function computeReconciliationData(
  costs: Array<{
    costAccountId: string;
    code: string;
    nameKo: string;
    totalAmount: bigint;
  }>,
  run: {
    details: Array<{ costAccountId: string; allocatedAmount: bigint }>;
    summaries: Array<{ allocationAmount: bigint }>;
    totalMarkup: bigint;
    totalBilling: bigint;
  }
) {
  const accountDetails = costs.map((cost) => {
    const details = run.details.filter(
      (d) => d.costAccountId === cost.costAccountId
    );
    const allocatedSum = details.reduce(
      (sum, d) => sum + d.allocatedAmount,
      0n
    );
    return {
      costAccountId: cost.costAccountId,
      code: cost.code,
      name: cost.nameKo,
      sourceTotal: cost.totalAmount.toString(),
      allocatedSum: allocatedSum.toString(),
      roundingDiff: (cost.totalAmount - allocatedSum).toString(),
    };
  });

  const totalSourceCost = costs.reduce((s, c) => s + c.totalAmount, 0n);
  const totalAccountAllocated = run.details.reduce(
    (s, d) => s + d.allocatedAmount,
    0n
  );
  const totalCompanyAllocated = run.summaries.reduce(
    (s, d) => s + d.allocationAmount,
    0n
  );

  const accountRoundingDiff = totalSourceCost - totalAccountAllocated;
  const companyRoundingDiff = totalAccountAllocated - totalCompanyAllocated;

  const isBalanced =
    accountRoundingDiff === companyRoundingDiff ||
    Math.abs(Number(accountRoundingDiff)) < 1000000;

  return {
    totalSourceCost: totalSourceCost.toString(),
    totalAccountAllocated: totalAccountAllocated.toString(),
    accountRoundingDiff: accountRoundingDiff.toString(),
    totalCompanyAllocated: totalCompanyAllocated.toString(),
    companyRoundingDiff: companyRoundingDiff.toString(),
    totalMarkup: run.totalMarkup.toString(),
    totalBilling: run.totalBilling.toString(),
    isBalanced,
    details: accountDetails,
  };
}

export async function reconcileRun(runId: string, userId: string) {
  const run = await prisma.allocationRun.findUniqueOrThrow({
    where: { id: runId },
    include: {
      details: { include: { costAccount: true } },
      summaries: true,
      project: true,
    },
  });

  if (run.status === "PREVIEW") {
    throw new Error("미리보기 실행은 대사할 수 없습니다.");
  }

  const costs = await getProjectCosts(run.projectId);
  const computed = computeReconciliationData(costs, run);

  return prisma.$transaction(async (tx) => {
    const reconciliation = await tx.reconciliationResult.upsert({
      where: { runId },
      create: {
        runId,
        totalSourceCost: BigInt(computed.totalSourceCost),
        totalAccountAllocated: BigInt(computed.totalAccountAllocated),
        accountRoundingDiff: BigInt(computed.accountRoundingDiff),
        totalCompanyAllocated: BigInt(computed.totalCompanyAllocated),
        companyRoundingDiff: BigInt(computed.companyRoundingDiff),
        totalMarkup: run.totalMarkup,
        totalBilling: run.totalBilling,
        isBalanced: computed.isBalanced,
        details: computed.details,
      },
      update: {
        totalSourceCost: BigInt(computed.totalSourceCost),
        totalAccountAllocated: BigInt(computed.totalAccountAllocated),
        accountRoundingDiff: BigInt(computed.accountRoundingDiff),
        totalCompanyAllocated: BigInt(computed.totalCompanyAllocated),
        companyRoundingDiff: BigInt(computed.companyRoundingDiff),
        totalMarkup: run.totalMarkup,
        totalBilling: run.totalBilling,
        isBalanced: computed.isBalanced,
        details: computed.details,
      },
    });

    await tx.allocationProject.update({
      where: { id: run.projectId },
      data: { status: "RECONCILED" },
    });

    await createAuditLog(
      {
        userId,
        action: "RECONCILE",
        entityType: "AllocationRun",
        entityId: runId,
        afterData: { isBalanced: computed.isBalanced },
      },
      tx
    );

    return reconciliation;
  });
}

/** 절사·대사 확정 취소 — 배분 실행 결과는 유지하고 대사·미발행 청구만 삭제 */
export async function cancelReconciliation(runId: string, userId: string) {
  const run = await prisma.allocationRun.findUniqueOrThrow({
    where: { id: runId },
    include: { reconciliation: true, project: true },
  });

  if (!run.reconciliation) {
    throw new Error("확정된 절사·대사가 없습니다.");
  }

  if (run.status === "PREVIEW") {
    throw new Error("미리보기 실행은 대사를 취소할 수 없습니다.");
  }

  if (run.project.status === "CLOSED") {
    throw new Error("마감된 프로젝트는 절사·대사를 취소할 수 없습니다.");
  }

  return prisma.$transaction(async (tx) => {
    const invoices = await tx.invoice.findMany({
      where: { runId },
      select: { id: true, status: true },
    });
    const issued = invoices.filter((i) => i.status === "ISSUED");
    if (issued.length > 0) {
      throw new Error("발행된 청구서가 있어 절사·대사를 취소할 수 없습니다.");
    }

    await tx.invoiceLine.deleteMany({
      where: { invoice: { runId } },
    });
    await tx.invoice.deleteMany({ where: { runId } });
    await tx.reconciliationResult.delete({ where: { runId } });

    let projectStatus = run.project.status;
    if (["RECONCILED", "BILLING_APPROVED"].includes(run.project.status)) {
      await tx.allocationProject.update({
        where: { id: run.projectId },
        data: { status: "CALCULATED" },
      });
      projectStatus = "CALCULATED";
    }

    await createAuditLog(
      {
        userId,
        action: "RECONCILE_CANCEL",
        entityType: "AllocationRun",
        entityId: runId,
        afterData: { projectStatus },
      },
      tx
    );

    return {
      projectStatus,
      project: await tx.allocationProject.findUniqueOrThrow({
        where: { id: run.projectId },
        include: { period: true },
      }),
    };
  });
}

export async function generateInvoicesFromRun(runId: string, userId: string) {
  const run = await prisma.allocationRun.findUniqueOrThrow({
    where: { id: runId },
    include: {
      summaries: { include: { company: { include: { addresses: true } } } },
      details: { include: { costAccount: true } },
      project: { include: { period: true } },
      reconciliation: true,
    },
  });

  if (run.status === "PREVIEW") {
    throw new Error("미리보기 실행으로는 청구서를 생성할 수 없습니다.");
  }

  if (!run.reconciliation) {
    throw new Error("대사가 완료되지 않았습니다.");
  }

  const invoices = [];

  for (const summary of run.summaries) {
    const company = summary.company;
    const primaryAddress = company.addresses.find(
      (a) => a.isPrimary && !a.deletedAt
    );

    if (company.companyType === "OVERSEAS" && !primaryAddress) {
      throw new Error(
        `${company.nameKo} 해외법인의 청구 주소가 없습니다.`
      );
    }

    const companyDetails = run.details.filter(
      (d) => d.companyId === company.id
    );

    const invoiceType =
      company.companyType === "OVERSEAS" ? "OVERSEAS" : "DOMESTIC";

    const lines = companyDetails.map((d, idx) => ({
      lineNumber: idx + 1,
      costAccountId: d.costAccountId,
      description: d.costAccount.nameKo,
      amount: d.allocatedAmount,
    }));

    const subtotal = summary.allocationAmount;
    const markupAmount = summary.markupAmount;
    const totalAmount = summary.billingAmount;

    if (subtotal + markupAmount !== totalAmount) {
      throw new Error(`${company.nameKo} 청구서 금액이 배부 결과와 불일치합니다.`);
    }

    const lineSum = lines.reduce((s, l) => s + l.amount, 0n);
    const preRoundDiff = lineSum - subtotal;
    if (preRoundDiff !== 0n) {
      // 10원 절사 차이는 별도 라인으로 표시하지 않고 summary 기준 사용
    }

    const invoice = await prisma.invoice.upsert({
      where: {
        runId_companyId: { runId, companyId: company.id },
      },
      create: {
        runId,
        companyId: company.id,
        invoiceType,
        status: "DRAFT",
        periodLabel: run.project.period.label,
        subtotal,
        markupAmount,
        totalAmount,
        billingAddress: primaryAddress
          ? {
              line1: primaryAddress.line1,
              line2: primaryAddress.line2,
              city: primaryAddress.city,
              country: primaryAddress.country,
            }
          : undefined,
        lines: {
          create: lines,
        },
      },
      update: {
        subtotal,
        markupAmount,
        totalAmount,
        lines: {
          deleteMany: {},
          create: lines,
        },
      },
      include: { lines: true, company: true },
    });

    invoices.push(invoice);
  }

  await createAuditLog({
    userId,
    action: "INVOICE_GENERATE",
    entityType: "AllocationRun",
    entityId: runId,
    afterData: { count: invoices.length },
  });

  return invoices;
}

export async function issueInvoice(invoiceId: string, userId: string) {
  const invoice = await prisma.invoice.findUniqueOrThrow({
    where: { id: invoiceId },
    include: {
      run: { include: { summaries: true, reconciliation: true } },
      company: true,
      lines: true,
    },
  });

  if (invoice.status === "ISSUED") {
    throw new Error("이미 발행된 청구서입니다.");
  }

  if (invoice.status !== "APPROVED") {
    throw new Error("승인된 청구서만 발행할 수 있습니다.");
  }

  const summary = invoice.run.summaries.find(
    (s) => s.companyId === invoice.companyId
  );
  if (!summary) throw new Error("배부 결과를 찾을 수 없습니다.");

  if (
    summary.allocationAmount !== invoice.subtotal ||
    summary.markupAmount !== invoice.markupAmount ||
    summary.billingAmount !== invoice.totalAmount
  ) {
    throw new Error("청구서 금액이 배부 결과와 일치하지 않습니다. 발행이 차단됩니다.");
  }

  const invoiceNumber = `INV-${new Date().getFullYear()}-${invoice.company.code}-${Date.now().toString(36).toUpperCase()}`;

  return prisma.$transaction(async (tx) => {
    const issued = await tx.invoice.update({
      where: { id: invoiceId },
      data: {
        status: "ISSUED",
        invoiceNumber,
        issueDate: new Date(),
      },
    });

    await createAuditLog(
      {
        userId,
        action: "INVOICE_ISSUE",
        entityType: "Invoice",
        entityId: invoiceId,
        afterData: { invoiceNumber },
      },
      tx
    );

    return issued;
  });
}

export async function confirmProjectCosts(projectId: string, userId: string) {
  await assertProjectEditable(projectId);

  return prisma.$transaction(async (tx) => {
    await tx.monthlyCost.updateMany({
      where: { projectId, status: "DRAFT" },
      data: { status: "CONFIRMED" },
    });

    const project = await tx.allocationProject.update({
      where: { id: projectId },
      data: { status: "COST_CONFIRMED" },
    });

    await createAuditLog(
      {
        userId,
        action: "COST_CONFIRM",
        entityType: "AllocationProject",
        entityId: projectId,
      },
      tx
    );

    return project;
  });
}

export async function approveRateVersion(
  rateVersionId: string,
  userId: string
) {
  const rateVersion = await prisma.allocationRateVersion.findUniqueOrThrow({
    where: { id: rateVersionId },
    include: {
      rates: { include: { company: true } },
      project: { include: { period: true } },
    },
  });

  if (rateVersion.status === "APPROVED") {
    throw new Error("이미 확정된 버전입니다.");
  }

  const rates = rateVersion.rates.map((r) => ({
    companyId: r.companyId,
    companyCode: r.company.code,
    companyName: r.company.nameKo,
    companyType: r.company.companyType,
    rate: decimalToNumber(r.rate),
  }));

  const validation = validateRates(rates);
  if (requiresExactRateTotal(rateVersion.project) && !validation.valid) {
    throw new Error(validation.message);
  }

  return prisma.$transaction(async (tx) => {
    await tx.allocationRateVersion.updateMany({
      where: {
        projectId: rateVersion.projectId,
        status: "APPROVED",
      },
      data: { status: "SUPERSEDED" },
    });

    const updated = await tx.allocationRateVersion.update({
      where: { id: rateVersionId },
      data: {
        status: "APPROVED",
        totalRate: validation.total / 100,
        approvedAt: new Date(),
      },
    });

    await tx.allocationProject.update({
      where: { id: rateVersion.projectId },
      data: { status: "RATES_APPROVED" },
    });

    await createAuditLog(
      {
        userId,
        action: "RATE_APPROVE",
        entityType: "AllocationRateVersion",
        entityId: rateVersionId,
        afterData: { totalRate: validation.total },
      },
      tx
    );

    return updated;
  });
}

export async function reopenProjectCosts(projectId: string, userId: string) {
  const project = await prisma.allocationProject.findUniqueOrThrow({
    where: { id: projectId },
  });
  if (project.status !== "COST_CONFIRMED") {
    throw new Error("원가가 확정된 상태에서만 수정할 수 있습니다.");
  }

  return prisma.$transaction(async (tx) => {
    await tx.monthlyCost.updateMany({
      where: { projectId, status: "CONFIRMED" },
      data: { status: "DRAFT" },
    });

    const updated = await tx.allocationProject.update({
      where: { id: projectId },
      data: { status: "DRAFT" },
    });

    await createAuditLog(
      {
        userId,
        action: "COST_REOPEN",
        entityType: "AllocationProject",
        entityId: projectId,
      },
      tx
    );

    return updated;
  });
}

export async function reopenRateVersion(rateVersionId: string, userId: string) {
  const rateVersion = await prisma.allocationRateVersion.findUniqueOrThrow({
    where: { id: rateVersionId },
    include: { project: true },
  });

  if (rateVersion.status !== "APPROVED") {
    throw new Error("확정된 배분율에서만 수정할 수 있습니다.");
  }
  if (rateVersion.project.status !== "RATES_APPROVED") {
    throw new Error("배분 계산이 진행된 후에는 배분율을 수정할 수 없습니다.");
  }

  return prisma.$transaction(async (tx) => {
    const updated = await tx.allocationRateVersion.update({
      where: { id: rateVersionId },
      data: { status: "DRAFT", approvedAt: null },
    });

    await tx.allocationProject.update({
      where: { id: rateVersion.projectId },
      data: { status: "COST_CONFIRMED" },
    });

    await createAuditLog(
      {
        userId,
        action: "RATE_REOPEN",
        entityType: "AllocationRateVersion",
        entityId: rateVersionId,
      },
      tx
    );

    return updated;
  });
}

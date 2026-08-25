import prisma from "../db";
import { monthsForPeriod, isMonthlyPeriod } from "../period-utils";
import { createAuditLog } from "../audit";
import { findOrCreateMonthlyPeriod } from "./project-init-service";

export type MonthlyCostSource = {
  month: number;
  available: boolean;
  periodLabel: string;
  projectId?: string;
  projectName?: string;
  accountCount: number;
  totalAmount: number;
  message?: string;
};

export async function getMonthlyCostSources(semiProjectId: string) {
  const project = await prisma.allocationProject.findUniqueOrThrow({
    where: { id: semiProjectId },
    include: { period: true },
  });

  if (isMonthlyPeriod(project.period)) {
    return { projectId: semiProjectId, sources: [], message: "반기 프로젝트만 월별 원가를 불러올 수 있습니다." };
  }

  const year = project.period.year;
  const months = monthsForPeriod(project.period);

  const sources: MonthlyCostSource[] = [];

  for (const month of months) {
    const monthlyProject = await prisma.allocationProject.findFirst({
      where: {
        period: { cadence: "MONTHLY", year, periodKey: month },
      },
      include: { period: true },
    });

    if (!monthlyProject) {
      sources.push({
        month,
        available: false,
        periodLabel: `${year}년 ${month}월`,
        accountCount: 0,
        totalAmount: 0,
        message: "월별 프로젝트 없음",
      });
      continue;
    }

    const costs = await prisma.monthlyCost.findMany({
      where: { projectId: monthlyProject.id, month, amount: { not: 0n } },
    });

    const totalAmount = costs.reduce((s, c) => s + c.amount, 0n);

    sources.push({
      month,
      available: costs.length > 0,
      periodLabel: monthlyProject.period.label,
      projectId: monthlyProject.id,
      projectName: monthlyProject.name,
      accountCount: costs.length,
      totalAmount: Number(totalAmount),
      message: costs.length === 0 ? "입력된 원가 없음" : undefined,
    });
  }

  const importable = sources.filter((s) => s.available);

  return {
    projectId: semiProjectId,
    periodLabel: project.period.label,
    sources,
    importableCount: importable.length,
    available: importable.length > 0,
  };
}

/** 월별 프로젝트 원가 → 반기 프로젝트 해당 월에 복사 */
export async function importMonthlyCostsToSemiProject(
  semiProjectId: string,
  userId: string,
  months?: number[]
) {
  const project = await prisma.allocationProject.findUniqueOrThrow({
    where: { id: semiProjectId },
    include: { period: true },
  });

  if (isMonthlyPeriod(project.period)) {
    throw new Error("반기 프로젝트에서만 월별 원가를 불러올 수 있습니다.");
  }
  if (project.status !== "DRAFT" && project.status !== "COST_CONFIRMED") {
    throw new Error("마감된 프로젝트에는 원가를 불러올 수 없습니다.");
  }

  const sourceInfo = await getMonthlyCostSources(semiProjectId);
  const targetMonths = months?.length
    ? months
    : sourceInfo.sources.filter((s) => s.available).map((s) => s.month);

  if (targetMonths.length === 0) {
    throw new Error("불러올 월별 원가가 없습니다. 월별 프로젝트에 원가를 먼저 입력하세요.");
  }

  let copied = 0;
  const year = project.period.year;

  for (const month of targetMonths) {
    const monthlyProject = await prisma.allocationProject.findFirst({
      where: { period: { cadence: "MONTHLY", year, periodKey: month } },
    });
    if (!monthlyProject) continue;

    const sourceCosts = await prisma.monthlyCost.findMany({
      where: { projectId: monthlyProject.id, month },
    });

    for (const src of sourceCosts) {
      await prisma.monthlyCost.upsert({
        where: {
          projectId_costAccountId_month_version: {
            projectId: semiProjectId,
            costAccountId: src.costAccountId,
            month,
            version: 1,
          },
        },
        create: {
          projectId: semiProjectId,
          costAccountId: src.costAccountId,
          month,
          amount: src.amount,
          status: src.status,
          createdById: userId,
        },
        update: { amount: src.amount },
      });
      copied++;
    }
  }

  await createAuditLog({
    userId,
    action: "COST_IMPORT",
    entityType: "AllocationProject",
    entityId: semiProjectId,
    afterData: { direction: "monthly_to_semi", months: targetMonths, copied },
  });

  return { copied, months: targetMonths };
}

/** 반기 프로젝트 특정 월 원가 → 해당 월별 프로젝트로 복사 */
export async function syncSemiCostsToMonthlyProject(
  semiProjectId: string,
  month: number,
  userId: string
) {
  const project = await prisma.allocationProject.findUniqueOrThrow({
    where: { id: semiProjectId },
    include: { period: true },
  });

  if (isMonthlyPeriod(project.period)) {
    throw new Error("반기 프로젝트에서만 월별로 내보낼 수 있습니다.");
  }

  const halfMonths = monthsForPeriod(project.period);
  if (!halfMonths.includes(month)) {
    throw new Error(`${month}월은 이 반기 프로젝트 범위에 없습니다.`);
  }

  const year = project.period.year;
  const period = await findOrCreateMonthlyPeriod(year, month);

  let monthlyProject = await prisma.allocationProject.findFirst({
    where: { periodId: period.id, version: 1 },
  });

  if (!monthlyProject) {
    monthlyProject = await prisma.allocationProject.create({
      data: {
        periodId: period.id,
        name: `${year}년 ${month}월 공동비용 배부`,
        createdById: userId,
      },
    });
    const { initializeProject } = await import("./project-init-service");
    await initializeProject(monthlyProject.id, userId);
  }

  const sourceCosts = await prisma.monthlyCost.findMany({
    where: { projectId: semiProjectId, month },
  });

  let copied = 0;
  for (const src of sourceCosts) {
    await prisma.monthlyCost.upsert({
      where: {
        projectId_costAccountId_month_version: {
          projectId: monthlyProject.id,
          costAccountId: src.costAccountId,
          month,
          version: 1,
        },
      },
      create: {
        projectId: monthlyProject.id,
        costAccountId: src.costAccountId,
        month,
        amount: src.amount,
        status: src.status,
        createdById: userId,
      },
      update: { amount: src.amount },
    });
    copied++;
  }

  await createAuditLog({
    userId,
    action: "COST_SYNC",
    entityType: "AllocationProject",
    entityId: monthlyProject.id,
    afterData: { direction: "semi_to_monthly", sourceProjectId: semiProjectId, month, copied },
  });

  return { monthlyProjectId: monthlyProject.id, month, copied };
}

import prisma from "../db";
import {
  halfFromMonth,
  monthDateRange,
  monthlyPeriodLabel,
  monthsForPeriod,
  semiAnnualPeriodLabel,
  type PeriodCadence,
} from "../period-utils";

export async function initializeProject(projectId: string, userId: string) {
  const project = await prisma.allocationProject.findUniqueOrThrow({
    where: { id: projectId },
    include: { period: true },
  });

  const months = monthsForPeriod(project.period);
  const accounts = await prisma.costAccount.findMany({
    where: { isActive: true, deletedAt: null },
    orderBy: { sortOrder: "asc" },
  });

  const costRows = accounts.flatMap((account) =>
    months.map((month) => ({
      projectId,
      costAccountId: account.id,
      month,
      amount: 0n,
      createdById: userId,
    }))
  );

  if (costRows.length > 0) {
    await prisma.monthlyCost.createMany({
      data: costRows,
      skipDuplicates: true,
    });
  }

  const existingVersion = await prisma.allocationRateVersion.findFirst({
    where: { projectId },
  });
  if (!existingVersion) {
    await ensureDraftRateVersion(projectId, userId);
  }

  return project;
}

/** 배분율 버전이 없으면 DRAFT v1 생성 (프로젝트 초기화 실패 복구 포함) */
export async function ensureDraftRateVersion(
  projectId: string,
  userId?: string
) {
  const existing = await prisma.allocationRateVersion.findFirst({
    where: { projectId },
    orderBy: { version: "desc" },
  });
  if (existing) return existing;

  const project = await prisma.allocationProject.findUniqueOrThrow({
    where: { id: projectId },
    select: { createdById: true },
  });

  let creatorId: string | undefined = userId ?? project.createdById ?? undefined;
  if (!creatorId) {
    const fallback = await prisma.user.findFirst({
      where: { isActive: true },
      orderBy: { createdAt: "asc" },
    });
    creatorId = fallback?.id;
  }
  if (!creatorId) {
    throw new Error("배분율 버전을 생성할 사용자 정보가 없습니다.");
  }

  const companies = await prisma.company.findMany({
    where: { isActive: true, deletedAt: null },
    orderBy: { sortOrder: "asc" },
  });

  return prisma.allocationRateVersion.create({
    data: {
      projectId,
      version: 1,
      status: "DRAFT",
      totalRate: 0,
      createdById: creatorId,
      rates: {
        create: companies.map((c) => ({
          companyId: c.id,
          rate: 0,
        })),
      },
    },
  });
}

export async function findOrCreatePeriod(year: number, half: number) {
  const existing = await prisma.accountingPeriod.findFirst({
    where: { year, cadence: "SEMI_ANNUAL", periodKey: half },
  });
  if (existing) return existing;

  const label = semiAnnualPeriodLabel(year, half);
  const startDate =
    half === 1 ? new Date(`${year}-01-01`) : new Date(`${year}-07-01`);
  const endDate =
    half === 1 ? new Date(`${year}-06-30`) : new Date(`${year}-12-31`);

  return prisma.accountingPeriod.create({
    data: {
      year,
      cadence: "SEMI_ANNUAL",
      periodKey: half,
      half,
      label,
      startDate,
      endDate,
    },
  });
}

export async function findOrCreateMonthlyPeriod(year: number, month: number) {
  if (month < 1 || month > 12) {
    throw new Error("month must be between 1 and 12");
  }

  const existing = await prisma.accountingPeriod.findFirst({
    where: { year, cadence: "MONTHLY", periodKey: month },
  });
  if (existing) return existing;

  const { startDate, endDate } = monthDateRange(year, month);
  const half = halfFromMonth(month);

  return prisma.accountingPeriod.create({
    data: {
      year,
      cadence: "MONTHLY",
      periodKey: month,
      half,
      month,
      label: monthlyPeriodLabel(year, month),
      startDate,
      endDate,
    },
  });
}

export function periodCadenceFromBody(body: {
  cadence?: PeriodCadence | string;
}): PeriodCadence {
  return body.cadence === "MONTHLY" ? "MONTHLY" : "SEMI_ANNUAL";
}

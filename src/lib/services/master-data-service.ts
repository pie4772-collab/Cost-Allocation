import prisma from "../db";
import { validateRates } from "../allocation-engine";

const H1_MONTHS = [1, 2, 3, 4, 5, 6];
const H2_MONTHS = [7, 8, 9, 10, 11, 12];

export const activeCompanyWhere = { isActive: true, deletedAt: null } as const;

function monthsForHalf(half: number): number[] {
  return half === 1 ? H1_MONTHS : H2_MONTHS;
}

export async function recalculateRateVersionTotal(rateVersionId: string) {
  const rates = await prisma.allocationRate.findMany({
    where: { rateVersionId, company: activeCompanyWhere },
    include: { company: true },
  });

  const validation = validateRates(
    rates.map((r) => ({
      companyId: r.companyId,
      companyCode: r.company.code,
      companyName: r.company.nameKo,
      companyType: r.company.companyType,
      rate: Number(r.rate),
    }))
  );

  await prisma.allocationRateVersion.update({
    where: { id: rateVersionId },
    data: { totalRate: validation.total / 100 },
  });

  return validation;
}

/** 편집 중인 배분율에서 비활성·삭제 법인 행 제거 */
export async function pruneInactiveRatesFromProject(projectId: string) {
  const stale = await prisma.allocationRate.findMany({
    where: {
      rateVersion: {
        projectId,
        status: { in: ["DRAFT", "PENDING_APPROVAL"] },
      },
      company: {
        OR: [{ isActive: false }, { deletedAt: { not: null } }],
      },
    },
    select: { id: true, rateVersionId: true },
  });

  if (stale.length === 0) return 0;

  await prisma.allocationRate.deleteMany({
    where: { id: { in: stale.map((r) => r.id) } },
  });

  for (const versionId of new Set(stale.map((r) => r.rateVersionId))) {
    await recalculateRateVersionTotal(versionId);
  }

  return stale.length;
}

/** 법인 삭제/비활성 시 DRAFT 배분율에서 해당 법인 제거 */
export async function removeCompanyFromDraftRateVersions(companyId: string) {
  const rows = await prisma.allocationRate.findMany({
    where: {
      companyId,
      rateVersion: { status: { in: ["DRAFT", "PENDING_APPROVAL"] } },
    },
    select: { id: true, rateVersionId: true },
  });

  if (rows.length === 0) return;

  await prisma.allocationRate.deleteMany({
    where: { id: { in: rows.map((r) => r.id) } },
  });

  for (const versionId of new Set(rows.map((r) => r.rateVersionId))) {
    await recalculateRateVersionTotal(versionId);
  }
}

export async function syncCompanyToDraftRateVersions(companyId: string) {
  const company = await prisma.company.findFirst({
    where: { id: companyId, ...activeCompanyWhere },
  });
  if (!company) return;

  const draftVersions = await prisma.allocationRateVersion.findMany({
    where: {
      status: { in: ["DRAFT", "PENDING_APPROVAL"] },
      project: { status: { not: "CLOSED" } },
    },
    select: { id: true },
  });

  for (const version of draftVersions) {
    const exists = await prisma.allocationRate.findFirst({
      where: { rateVersionId: version.id, companyId },
    });
    if (!exists) {
      await prisma.allocationRate.create({
        data: { rateVersionId: version.id, companyId, rate: 0 },
      });
    }
  }
}

export async function syncCostAccountToActiveProjects(
  costAccountId: string,
  userId: string
) {
  const projects = await prisma.allocationProject.findMany({
    where: { status: { not: "CLOSED" } },
    include: { period: true },
  });

  for (const project of projects) {
    const months = monthsForHalf(project.period.half);
    const rows = months.map((month) => ({
      projectId: project.id,
      costAccountId,
      month,
      amount: 0n,
      createdById: userId,
    }));

    await prisma.monthlyCost.createMany({
      data: rows,
      skipDuplicates: true,
    });
  }
}

export async function generateCostAccountCode(): Promise<string> {
  const latest = await prisma.costAccount.findFirst({
    where: { code: { startsWith: "9" } },
    orderBy: { code: "desc" },
  });
  if (!latest) return "9001";
  const num = parseInt(latest.code, 10);
  return Number.isFinite(num) ? String(num + 1) : `9${Date.now().toString().slice(-4)}`;
}

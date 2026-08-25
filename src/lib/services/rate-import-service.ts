import prisma from "../db";
import { createAuditLog } from "@/lib/audit";
import { activeCompanyWhere, recalculateRateVersionTotal } from "./master-data-service";
import { isMonthlyPeriod, previousMonthly } from "../period-utils";

export function previousPeriod(year: number, half: number) {
  if (half === 2) return { year, half: 1 };
  return { year: year - 1, half: 2 };
}

function previousPeriodForProject(period: {
  cadence: string;
  year: number;
  half: number;
  month: number | null;
}) {
  if (isMonthlyPeriod(period) && period.month) {
    const prev = previousMonthly(period.year, period.month);
    return { year: prev.year, cadence: "MONTHLY" as const, periodKey: prev.month };
  }
  const prev = previousPeriod(period.year, period.half);
  return { year: prev.year, cadence: "SEMI_ANNUAL" as const, periodKey: prev.half };
}

async function findSourceRateVersion(projectId: string) {
  const approved = await prisma.allocationRateVersion.findFirst({
    where: { projectId, status: "APPROVED" },
    orderBy: { version: "desc" },
    include: {
      rates: { include: { company: true } },
      project: { include: { period: true } },
    },
  });
  if (approved) return approved;

  return prisma.allocationRateVersion.findFirst({
    where: { projectId },
    orderBy: { version: "desc" },
    include: {
      rates: { include: { company: true } },
      project: { include: { period: true } },
    },
  });
}

export async function getPreviousPeriodRateSource(projectId: string) {
  const project = await prisma.allocationProject.findUniqueOrThrow({
    where: { id: projectId },
    include: { period: true },
  });

  const prev = previousPeriodForProject(project.period);
  const prevProject = await prisma.allocationProject.findFirst({
    where: {
      period: {
        year: prev.year,
        cadence: prev.cadence,
        periodKey: prev.periodKey,
      },
    },
    include: { period: true },
  });

  if (!prevProject) {
    const prevLabel =
      prev.cadence === "MONTHLY"
        ? `${prev.year}년 ${prev.periodKey}월`
        : `${prev.year} H${prev.periodKey}`;
    return {
      available: false,
      periodLabel: prevLabel,
      message:
        prev.cadence === "MONTHLY"
          ? "이전 월 프로젝트가 없습니다."
          : "이전 반기 프로젝트가 없습니다.",
    };
  }

  const sourceVersion = await findSourceRateVersion(prevProject.id);
  if (!sourceVersion) {
    return {
      available: false,
      periodLabel: prevProject.period.label,
      projectName: prevProject.name,
      message: "이전 반기 배분율 데이터가 없습니다.",
    };
  }

  const activeSourceRates = sourceVersion.rates.filter(
    (r) => r.company.isActive && r.company.deletedAt === null
  );
  if (activeSourceRates.length === 0) {
    return {
      available: false,
      periodLabel: prevProject.period.label,
      projectName: prevProject.name,
      message: "이전 반기 배분율 데이터가 없습니다.",
    };
  }

  return {
    available: true,
    periodLabel: prevProject.period.label,
    projectName: prevProject.name,
    projectId: prevProject.id,
    rateVersionId: sourceVersion.id,
    rateVersionStatus: sourceVersion.status,
    version: sourceVersion.version,
    companyCount: activeSourceRates.length,
    totalRate: activeSourceRates.reduce((s, r) => s + Number(r.rate), 0) * 100,
  };
}

export async function importPreviousPeriodRates(
  rateVersionId: string,
  userId: string
) {
  const targetVersion = await prisma.allocationRateVersion.findUniqueOrThrow({
    where: { id: rateVersionId },
    include: {
      project: { include: { period: true } },
      rates: true,
    },
  });

  if (targetVersion.status === "APPROVED") {
    throw new Error("확정된 배분율은 불러올 수 없습니다. 수정하기를 먼저 누르세요.");
  }

  const sourceInfo = await getPreviousPeriodRateSource(targetVersion.projectId);
  if (!sourceInfo.available || !sourceInfo.rateVersionId) {
    throw new Error(sourceInfo.message ?? "이전 반기 배분율을 찾을 수 없습니다.");
  }

  const sourceVersion = await prisma.allocationRateVersion.findUniqueOrThrow({
    where: { id: sourceInfo.rateVersionId },
    include: { rates: { include: { company: true } } },
  });

  const activeCompanies = await prisma.company.findMany({
    where: activeCompanyWhere,
    select: { id: true },
  });
  const activeIds = new Set(activeCompanies.map((c) => c.id));

  const sourceRates = sourceVersion.rates.filter((r) =>
    activeIds.has(r.companyId)
  );

  await prisma.allocationRate.deleteMany({ where: { rateVersionId } });

  if (sourceRates.length > 0) {
    await prisma.allocationRate.createMany({
      data: sourceRates.map((src) => ({
        rateVersionId,
        companyId: src.companyId,
        rate: src.rate,
      })),
    });
  }

  const validation = await recalculateRateVersionTotal(rateVersionId);

  await prisma.allocationRateVersion.update({
    where: { id: rateVersionId },
    data: { notes: `이전 반기(${sourceInfo.periodLabel}) 배분율 불러옴` },
  });

  await createAuditLog({
    userId,
    action: "RATE_IMPORT",
    entityType: "AllocationRateVersion",
    entityId: rateVersionId,
    afterData: {
      sourcePeriod: sourceInfo.periodLabel,
      sourceVersionId: sourceInfo.rateVersionId,
      companyCount: sourceRates.length,
      totalRate: validation.total,
    },
  });

  const updated = await prisma.allocationRateVersion.findUniqueOrThrow({
    where: { id: rateVersionId },
    include: {
      project: { include: { period: true } },
      rates: {
        where: { company: activeCompanyWhere },
        include: { company: true },
        orderBy: { company: { sortOrder: "asc" } },
      },
    },
  });

  return { version: updated, source: sourceInfo, validation };
}

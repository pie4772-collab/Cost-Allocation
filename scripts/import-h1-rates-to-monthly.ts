import { PrismaClient } from "@prisma/client";
import { recalculateRateVersionTotal } from "../src/lib/services/master-data-service";

const prisma = new PrismaClient();

const H1_PROJECT_ID = "cmsgzh31v000uv4z40z4iq9r4";
const YEAR = 2026;
const MONTHS = [1, 2, 3, 4, 5, 6] as const;

async function findSourceRateVersion(projectId: string) {
  const approved = await prisma.allocationRateVersion.findFirst({
    where: { projectId, status: "APPROVED" },
    orderBy: { version: "desc" },
    include: {
      rates: {
        where: { company: { isActive: true, deletedAt: null } },
      },
      project: { include: { period: true } },
    },
  });
  if (approved) return approved;

  return prisma.allocationRateVersion.findFirst({
    where: { projectId },
    orderBy: { version: "desc" },
    include: {
      rates: {
        where: { company: { isActive: true, deletedAt: null } },
      },
      project: { include: { period: true } },
    },
  });
}

async function main() {
  const sourceVersion = await findSourceRateVersion(H1_PROJECT_ID);
  if (!sourceVersion || sourceVersion.rates.length === 0) {
    throw new Error("2026 상반기 배분율을 찾을 수 없습니다.");
  }

  const sourceTotal =
    sourceVersion.rates.reduce((s, r) => s + Number(r.rate), 0) * 100;

  console.log(
    `원본: ${sourceVersion.project.period.label} v${sourceVersion.version} (${sourceVersion.status})`
  );
  console.log(`  ${sourceVersion.rates.length}개 법인, 합계 ${sourceTotal.toFixed(6)}%`);

  const admin =
    (await prisma.user.findFirst({ where: { email: "jaeyong.lee@kbigrp.com" } })) ??
    (await prisma.user.findFirst({ where: { email: "admin@kbi.local" } }));

  for (const month of MONTHS) {
    const project = await prisma.allocationProject.findFirst({
      where: {
        period: { year: YEAR, cadence: "MONTHLY", periodKey: month },
        version: 1,
      },
      include: { period: true },
    });

    if (!project) {
      console.log(`⚠ ${YEAR}년 ${month}월 프로젝트 없음 — 스킵`);
      continue;
    }

    let targetVersion = await prisma.allocationRateVersion.findFirst({
      where: { projectId: project.id },
      orderBy: { version: "desc" },
    });

    if (!targetVersion) {
      throw new Error(`${project.name} 배분율 버전이 없습니다.`);
    }

    if (targetVersion.status === "APPROVED") {
      console.log(`⚠ ${project.period.label}: 확정 상태 — 스킵`);
      continue;
    }

    await prisma.$transaction(async (tx) => {
      await tx.allocationRate.deleteMany({
        where: { rateVersionId: targetVersion!.id },
      });
      await tx.allocationRate.createMany({
        data: sourceVersion.rates.map((r) => ({
          rateVersionId: targetVersion!.id,
          companyId: r.companyId,
          rate: r.rate,
        })),
      });
      await tx.allocationRateVersion.update({
        where: { id: targetVersion!.id },
        data: {
          notes: `${sourceVersion.project.period.label} 배분율에서 복사`,
        },
      });
    });

    const validation = await recalculateRateVersionTotal(targetVersion.id);

    if (admin) {
      await prisma.auditLog.create({
        data: {
          userId: admin.id,
          action: "RATE_IMPORT",
          entityType: "AllocationRateVersion",
          entityId: targetVersion.id,
          afterData: {
            sourceProjectId: H1_PROJECT_ID,
            sourceVersionId: sourceVersion.id,
            sourcePeriod: sourceVersion.project.period.label,
            companyCount: sourceVersion.rates.length,
            totalRate: validation.total,
          },
        },
      });
    }

    console.log(
      `✓ ${project.period.label}: ${sourceVersion.rates.length}개 법인, ${validation.total.toFixed(6)}%`
    );
  }

  console.log("\n✓ 월별 배분율 복사 완료");
}

main()
  .catch((e) => {
    console.error("❌", e.message ?? e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());

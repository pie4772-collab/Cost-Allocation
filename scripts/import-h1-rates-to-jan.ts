import { PrismaClient } from "@prisma/client";
import { recalculateRateVersionTotal } from "../src/lib/services/master-data-service";

const prisma = new PrismaClient();

const H1_PROJECT_ID = "cmsgzh31v000uv4z40z4iq9r4";
const JAN_PROJECT_ID = "cmssgeewz0002v4608rfdohjs";

async function findSourceRateVersion(projectId: string) {
  const approved = await prisma.allocationRateVersion.findFirst({
    where: { projectId, status: "APPROVED" },
    orderBy: { version: "desc" },
    include: {
      rates: {
        where: { company: { isActive: true, deletedAt: null } },
        include: { company: { select: { code: true, nameKo: true } } },
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
        include: { company: { select: { code: true, nameKo: true } } },
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

  let targetVersion = await prisma.allocationRateVersion.findFirst({
    where: { projectId: JAN_PROJECT_ID },
    orderBy: { version: "desc" },
    include: { project: { include: { period: true } } },
  });

  if (!targetVersion) {
    throw new Error("2026년 1월 배분율 버전이 없습니다.");
  }

  if (targetVersion.status === "APPROVED") {
    throw new Error("2026년 1월 배분율이 확정 상태입니다. 수정하기 후 다시 시도하세요.");
  }

  const sourceTotal =
    sourceVersion.rates.reduce((s, r) => s + Number(r.rate), 0) * 100;

  console.log(`원본: ${sourceVersion.project.period.label} v${sourceVersion.version} (${sourceVersion.status})`);
  console.log(`  ${sourceVersion.rates.length}개 법인, 합계 ${sourceTotal.toFixed(6)}%`);
  console.log(`대상: ${targetVersion.project.period.label} v${targetVersion.version} (${targetVersion.status})`);

  await prisma.$transaction(async (tx) => {
    await tx.allocationRate.deleteMany({ where: { rateVersionId: targetVersion!.id } });
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
        notes: `${sourceVersion.project.period.label} 배분율에서 불러옴`,
      },
    });
  });

  const validation = await recalculateRateVersionTotal(targetVersion.id);

  const admin = await prisma.user.findFirst({ where: { email: "admin@kbi.local" } });
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

  console.log(`\n✓ 2026년 1월 배분율 업로드 완료`);
  console.log(`  ${sourceVersion.rates.length}개 법인 복사`);
  console.log(`  합계 ${validation.total.toFixed(6)}% (valid: ${validation.valid})`);
}

main()
  .catch((e) => {
    console.error("❌", e.message ?? e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());

import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

function fmt(n: bigint) {
  return Number(n).toLocaleString("ko-KR");
}

async function main() {
  const before = await prisma.monthlyCost.aggregate({
    _sum: { amount: true },
    _count: { _all: true },
  });

  const byProject = await prisma.monthlyCost.groupBy({
    by: ["projectId"],
    _count: { _all: true },
    _sum: { amount: true },
  });

  console.log(`삭제 대상: ${before._count._all}건, 합계 ${fmt(before._sum.amount ?? 0n)}원`);
  console.log(`프로젝트 수: ${byProject.length}`);

  const deleted = await prisma.monthlyCost.deleteMany();

  const reset = await prisma.allocationProject.updateMany({
    where: {
      status: {
        in: [
          "COST_CONFIRMED",
          "RATES_APPROVED",
          "CALCULATED",
          "RECONCILED",
          "BILLING_APPROVED",
          "CLOSED",
        ],
      },
    },
    data: { status: "DRAFT" },
  });

  const after = await prisma.monthlyCost.count();

  console.log(`\n✓ monthly_costs ${deleted.count}건 삭제`);
  console.log(`✓ 프로젝트 상태 DRAFT로 초기화: ${reset.count}건`);
  console.log(`잔여 원가 행: ${after}건`);
}

main()
  .catch((e) => {
    console.error("❌", e.message ?? e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());

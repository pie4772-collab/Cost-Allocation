import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

const SEED_CODES = ["6100", "6200", "6300", "6400", "6500", "6600", "6700", "6800"];
const H1_PROJECT_ID = "cmsgzh31v000uv4z40z4iq9r4";

function fmt(n: bigint) {
  return Number(n).toLocaleString("ko-KR");
}

async function main() {
  const seedAccounts = await prisma.costAccount.findMany({
    where: { code: { in: SEED_CODES } },
    select: { id: true, code: true, nameKo: true },
  });

  if (seedAccounts.length === 0) {
    console.log("seed 계정 없음");
    return;
  }

  const seedIds = seedAccounts.map((a) => a.id);

  const before = await prisma.monthlyCost.aggregate({
    where: { projectId: H1_PROJECT_ID, costAccountId: { in: seedIds } },
    _sum: { amount: true },
    _count: { _all: true },
  });

  console.log(`삭제 대상: ${before._count._all}건, ${fmt(before._sum.amount ?? 0n)}원`);
  for (const a of seedAccounts) {
    console.log(`  - ${a.code} ${a.nameKo}`);
  }

  const deleted = await prisma.monthlyCost.deleteMany({
    where: { projectId: H1_PROJECT_ID, costAccountId: { in: seedIds } },
  });

  const after = await prisma.monthlyCost.aggregate({
    where: { projectId: H1_PROJECT_ID },
    _sum: { amount: true },
    _count: { _all: true },
  });

  const nonzero = await prisma.monthlyCost.count({
    where: { projectId: H1_PROJECT_ID, amount: { not: 0n } },
  });

  console.log(`\n✓ ${deleted.count}건 삭제 완료`);
  console.log(`H1 잔여: ${fmt(after._sum.amount ?? 0n)}원 (${nonzero}건 nonzero)`);
}

main()
  .catch((e) => {
    console.error("❌", e.message ?? e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());

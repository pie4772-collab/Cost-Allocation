/**
 * 2026 H1 기존 청구 데이터: 배분율 합계 100% 초과 허용
 * npx tsx --env-file=.env scripts/mark-legacy-h1.ts
 */
import prisma from "../src/lib/db";

async function main() {
  const period = await prisma.accountingPeriod.findFirst({
    where: { year: 2026, half: 1 },
  });
  if (!period) {
    console.log("2026 H1 기간 없음 — 스킵");
    return;
  }

  const result = await prisma.allocationProject.updateMany({
    where: { periodId: period.id },
    data: { strictRateValidation: false },
  });

  console.log(`✓ ${result.count}개 프로젝트 → strictRateValidation=false (2026 H1 레거시)`);
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());

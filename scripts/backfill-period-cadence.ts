#!/usr/bin/env tsx
/**
 * 기존 accounting_periods 행에 cadence/periodKey 백필
 */
import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

async function main() {
  const periods = await prisma.accountingPeriod.findMany();
  for (const p of periods) {
    const cadence = p.cadence ?? "SEMI_ANNUAL";
    const periodKey = p.periodKey ?? p.half;
    await prisma.accountingPeriod.update({
      where: { id: p.id },
      data: {
        cadence,
        periodKey,
        month: cadence === "MONTHLY" ? periodKey : p.month,
      },
    });
  }
  console.log(`✓ backfilled ${periods.length} periods`);
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());

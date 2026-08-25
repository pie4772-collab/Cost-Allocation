#!/usr/bin/env tsx
/** 반기 H1 1월 원가 → 월별 1월 프로젝트 동기화 */
import { PrismaClient } from "@prisma/client";
import { syncSemiCostsToMonthlyProject } from "../src/lib/services/cost-import-service";

const prisma = new PrismaClient();

async function main() {
  const user = await prisma.user.findFirst({
    where: { isActive: true },
    orderBy: { createdAt: "asc" },
  });
  if (!user) throw new Error("No active user");

  const semi = await prisma.allocationProject.findFirst({
    where: { period: { cadence: "SEMI_ANNUAL", year: 2026, periodKey: 1 } },
  });
  if (!semi) throw new Error("2026 H1 semi-annual project not found");

  const result = await syncSemiCostsToMonthlyProject(semi.id, 1, user.id);
  console.log("✓ Synced January costs:", result);

  const monthly = await prisma.monthlyCost.count({
    where: {
      projectId: result.monthlyProjectId,
      month: 1,
      amount: { not: 0n },
    },
  });
  console.log(`✓ Monthly Jan project nonzero rows: ${monthly}`);
}

main()
  .catch((e) => {
    console.error("❌", e.message ?? e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());

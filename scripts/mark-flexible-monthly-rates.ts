import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

async function main() {
  const result = await prisma.allocationProject.updateMany({
    where: {
      period: {
        cadence: "MONTHLY",
        periodKey: { gte: 1, lte: 6 },
      },
    },
    data: { strictRateValidation: false },
  });

  console.log(`✓ 월별 1~6월 프로젝트 ${result.count}건 → strictRateValidation=false`);
}

main().finally(() => prisma.$disconnect());

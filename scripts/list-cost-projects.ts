import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

async function main() {
  const projects = await prisma.allocationProject.findMany({
    include: { period: true },
    orderBy: { createdAt: "asc" },
  });
  for (const proj of projects) {
    const jan = await prisma.monthlyCost.count({
      where: { projectId: proj.id, month: 1, amount: { not: 0n } },
    });
    const total = await prisma.monthlyCost.count({
      where: { projectId: proj.id, amount: { not: 0n } },
    });
    console.log(
      JSON.stringify({
        id: proj.id,
        name: proj.name,
        cadence: proj.period.cadence,
        label: proj.period.label,
        year: proj.period.year,
        half: proj.period.half,
        month: proj.period.month,
        nonzero: total,
        janNonzero: jan,
      })
    );
  }
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());

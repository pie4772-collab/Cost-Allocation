import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

async function main() {
  const projects = await prisma.allocationProject.findMany({
    where: { period: { year: 2026 } },
    include: {
      period: true,
      rateVersions: {
        orderBy: { version: "desc" },
        take: 1,
        include: {
          rates: {
            where: { company: { isActive: true, deletedAt: null } },
          },
        },
      },
    },
    orderBy: [{ period: { cadence: "desc" } }, { period: { periodKey: "asc" } }],
  });

  for (const p of projects) {
    const rv = p.rateVersions[0];
    const total = rv
      ? rv.rates.reduce((s, r) => s + Number(r.rate), 0) * 100
      : 0;
    console.log(`${p.period.label} | ${p.name}`);
    console.log(`  id: ${p.id}, status: ${p.status}`);
    if (rv) {
      console.log(
        `  rateVersion: ${rv.id} v${rv.version} ${rv.status}, ${rv.rates.length} rates, total ${total.toFixed(6)}%`
      );
    } else {
      console.log("  rateVersion: none");
    }
    console.log("");
  }
}

main().finally(() => prisma.$disconnect());

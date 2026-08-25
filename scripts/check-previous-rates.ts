import { PrismaClient } from "@prisma/client";
import { getPreviousPeriodRateSource } from "../src/lib/services/rate-import-service";

const prisma = new PrismaClient();

async function main() {
  const projects = await prisma.allocationProject.findMany({
    include: { period: true },
    orderBy: { createdAt: "desc" },
  });
  console.log("Projects:");
  for (const p of projects) {
    console.log(`  ${p.period.label} | ${p.name} | status=${p.status} | id=${p.id}`);
    const versions = await prisma.allocationRateVersion.findMany({
      where: { projectId: p.id },
      select: { version: true, status: true, totalRate: true, _count: { select: { rates: true } } },
      orderBy: { version: "desc" },
    });
    for (const v of versions) {
      console.log(`    v${v.version} ${v.status} total=${v.totalRate} rates=${v._count.rates}`);
    }
    const prev = await getPreviousPeriodRateSource(p.id);
    console.log(`    previousSource:`, prev);
    if (versions.length === 0) {
      console.log(`    ⚠ NO RATE VERSION — rates page isEditable=false, import button hidden`);
    }
  }
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());

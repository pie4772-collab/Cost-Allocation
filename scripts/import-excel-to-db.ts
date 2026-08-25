import { PrismaClient } from "@prisma/client";
import { parseExcelFile, DEFAULT_EXCEL_PATH } from "../src/lib/excel-import";

const prisma = new PrismaClient();

async function main() {
  const filePath = process.argv[2] ?? DEFAULT_EXCEL_PATH;
  console.log("Importing from:", filePath);

  const data = await parseExcelFile(filePath);
  console.log(`Accounts: ${data.accounts.length}, Companies: ${data.companies.length}`);
  console.log(`Rate total: ${data.rateTotal.toFixed(6)}%, Grand total: ${data.grandTotal.toLocaleString()}`);

  const admin = await prisma.user.findFirst({ where: { email: "admin@kbi.local" } });
  if (!admin) throw new Error("admin@kbi.local not found — run db:seed first");

  // Upsert accounts
  for (const a of data.accounts) {
    await prisma.costAccount.upsert({
      where: { code: a.code },
      create: {
        code: a.code,
        nameKo: a.nameKo,
        description: a.category,
        sortOrder: a.sortOrder,
      },
      update: {
        nameKo: a.nameKo,
        description: a.category,
        sortOrder: a.sortOrder,
        deletedAt: null,
      },
    });
  }

  // Upsert companies + addresses
  for (const c of data.companies) {
    const company = await prisma.company.upsert({
      where: { code: c.code },
      create: {
        code: c.code,
        nameKo: c.nameKo,
        nameEn: c.nameEn,
        companyType: c.companyType,
        billingLanguage: c.companyType === "OVERSEAS" ? "EN" : "KO",
        sortOrder: c.sortOrder,
        isActive: true,
      },
      update: {
        nameKo: c.nameKo,
        nameEn: c.nameEn,
        companyType: c.companyType,
        sortOrder: c.sortOrder,
        deletedAt: null,
      },
    });

    if (c.address) {
      await prisma.companyAddress.upsert({
        where: { id: `addr-${c.code}` },
        create: {
          id: `addr-${c.code}`,
          companyId: company.id,
          line1: c.address,
          country: c.companyType === "OVERSEAS" ? "OVERSEAS" : "KR",
          isPrimary: true,
        },
        update: { line1: c.address },
      });
    }
  }

  const period = await prisma.accountingPeriod.upsert({
    where: { year_half: { year: 2026, half: 1 } },
    create: {
      year: 2026,
      half: 1,
      label: "2026 H1",
      startDate: new Date("2026-01-01"),
      endDate: new Date("2026-06-30"),
    },
    update: {},
  });

  const project = await prisma.allocationProject.upsert({
    where: { periodId_version: { periodId: period.id, version: 1 } },
    create: {
      periodId: period.id,
      name: "2026 상반기 Scripture Room 공동비용 배부",
      status: "DRAFT",
      createdById: admin.id,
    },
    update: { name: "2026 상반기 Scripture Room 공동비용 배부" },
  });

  const accountMap = new Map(
    (await prisma.costAccount.findMany()).map((a) => [a.code, a.id])
  );

  // Clear old monthly costs for this project and re-import
  await prisma.monthlyCost.deleteMany({ where: { projectId: project.id } });

  for (const mc of data.monthlyCosts) {
    const costAccountId = accountMap.get(mc.accountCode);
    if (!costAccountId) continue;
    await prisma.monthlyCost.create({
      data: {
        projectId: project.id,
        costAccountId,
        month: mc.month,
        amount: BigInt(mc.amount),
        status: "DRAFT",
        createdById: admin.id,
      },
    });
  }

  const companyMap = new Map(
    (await prisma.company.findMany()).map((c) => [c.code, c.id])
  );

  // New rate version from Excel
  const lastVersion = await prisma.allocationRateVersion.findFirst({
    where: { projectId: project.id },
    orderBy: { version: "desc" },
  });
  const versionNum = (lastVersion?.version ?? 0) + 1;

  await prisma.allocationRateVersion.updateMany({
    where: { projectId: project.id, status: "DRAFT" },
    data: { status: "SUPERSEDED" },
  });

  const rateVersion = await prisma.allocationRateVersion.create({
    data: {
      projectId: project.id,
      version: versionNum,
      status: "DRAFT",
      totalRate: data.rateTotal / 100,
      notes: `Excel import ${new Date().toISOString().slice(0, 10)}`,
      createdById: admin.id,
      rates: {
        create: data.companies.map((c) => ({
          companyId: companyMap.get(c.code)!,
          rate: c.rate,
        })),
      },
    },
  });

  console.log("\n✅ Import complete");
  console.log("Project ID:", project.id);
  console.log("Rate version:", rateVersion.id);
  console.log(`Monthly costs: ${data.monthlyCosts.length} rows`);
  console.log(`Open: /costs?projectId=${project.id}`);
  console.log(`Open: /rates?projectId=${project.id}`);
}

main()
  .catch((e) => {
    console.error("❌", e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());

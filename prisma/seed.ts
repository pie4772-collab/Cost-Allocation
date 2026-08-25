import { PrismaClient, RoleName } from "@prisma/client";
import bcrypt from "bcryptjs";

const prisma = new PrismaClient();
const ADMIN_PASSWORD = process.env.SEED_ADMIN_PASSWORD ?? "ChangeMe123!";

const COMPANIES = [
  { code: "kbi-01", nameKo: "KBI 본사", nameEn: "KBI Headquarters", companyType: "DOMESTIC" as const, sortOrder: 1 },
  { code: "kbi-02", nameKo: "KBI 서울", nameEn: "KBI Seoul", companyType: "DOMESTIC" as const, sortOrder: 2 },
  { code: "kbi-03", nameKo: "KBI 부산", nameEn: "KBI Busan", companyType: "DOMESTIC" as const, sortOrder: 3 },
  { code: "kbi-04", nameKo: "KBI America", nameEn: "KBI America Inc.", companyType: "OVERSEAS" as const, sortOrder: 4, billingLanguage: "EN" as const },
  { code: "kbi-05", nameKo: "KBI Japan", nameEn: "KBI Japan K.K.", companyType: "OVERSEAS" as const, sortOrder: 5, billingLanguage: "EN" as const },
  { code: "kbi-06", nameKo: "KBI China", nameEn: "KBI China Ltd.", companyType: "OVERSEAS" as const, sortOrder: 6, billingLanguage: "EN" as const },
];

const COST_ACCOUNTS = [
  { code: "6100", nameKo: "임차료", nameEn: "Rent", sortOrder: 1 },
  { code: "6200", nameKo: "통신비", nameEn: "Communication", sortOrder: 2 },
  { code: "6300", nameKo: "전기료", nameEn: "Utilities", sortOrder: 3 },
  { code: "6400", nameKo: "보험료", nameEn: "Insurance", sortOrder: 4 },
  { code: "6500", nameKo: "감가상각비", nameEn: "Depreciation", sortOrder: 5 },
  { code: "6600", nameKo: "수선비", nameEn: "Repairs", sortOrder: 6 },
  { code: "6700", nameKo: "세금과공과", nameEn: "Taxes", sortOrder: 7 },
  { code: "6800", nameKo: "기타공동비용", nameEn: "Other Shared Costs", sortOrder: 8 },
];

async function main() {
  console.log("Seeding database...");

  const roles: RoleName[] = [
    "Admin", "CostManager", "AllocationManager",
    "Approver", "BillingManager", "Auditor", "Viewer",
  ];

  for (const name of roles) {
    await prisma.role.upsert({
      where: { name },
      create: { name, description: `${name} role` },
      update: {},
    });
  }

  const adminRole = await prisma.role.findUniqueOrThrow({ where: { name: "Admin" } });
  const costRole = await prisma.role.findUniqueOrThrow({ where: { name: "CostManager" } });
  const allocRole = await prisma.role.findUniqueOrThrow({ where: { name: "AllocationManager" } });
  const approverRole = await prisma.role.findUniqueOrThrow({ where: { name: "Approver" } });
  const billingRole = await prisma.role.findUniqueOrThrow({ where: { name: "BillingManager" } });

  const passwordHash = await bcrypt.hash(ADMIN_PASSWORD, 12);

  const admin = await prisma.user.upsert({
    where: { email: "admin@kbi.local" },
    create: {
      email: "admin@kbi.local",
      name: "시스템 관리자",
      passwordHash,
      isActive: true,
      roles: {
        create: [
          { roleId: adminRole.id },
          { roleId: costRole.id },
          { roleId: allocRole.id },
          { roleId: approverRole.id },
          { roleId: billingRole.id },
        ],
      },
    },
    update: { passwordHash, isActive: true },
  });

  for (const c of COMPANIES) {
    const company = await prisma.company.upsert({
      where: { code: c.code },
      create: {
        code: c.code,
        nameKo: c.nameKo,
        nameEn: c.nameEn,
        companyType: c.companyType,
        billingLanguage: c.billingLanguage ?? "KO",
        sortOrder: c.sortOrder,
        isActive: true,
      },
      update: {},
    });

    if (c.companyType === "OVERSEAS") {
      await prisma.companyAddress.upsert({
        where: { id: `addr-${c.code}` },
        create: {
          id: `addr-${c.code}`,
          companyId: company.id,
          line1: "123 Business Park Drive",
          city: "New York",
          country: c.code.startsWith("kbi-04") ? "US" : c.code.startsWith("kbi-05") ? "JP" : "CN",
          isPrimary: true,
        },
        update: {},
      });
    } else {
      await prisma.companyAddress.upsert({
        where: { id: `addr-${c.code}` },
        create: {
          id: `addr-${c.code}`,
          companyId: company.id,
          line1: "서울특별시 중구 세종대로 123",
          city: "서울",
          country: "KR",
          isPrimary: true,
        },
        update: {},
      });
    }
  }

  for (const a of COST_ACCOUNTS) {
    await prisma.costAccount.upsert({
      where: { code: a.code },
      create: a,
      update: {},
    });
  }

  const period = await prisma.accountingPeriod.upsert({
    where: {
      year_cadence_periodKey: {
        year: 2026,
        cadence: "SEMI_ANNUAL",
        periodKey: 1,
      },
    },
    create: {
      year: 2026,
      cadence: "SEMI_ANNUAL",
      periodKey: 1,
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
    update: {},
  });

  const accounts = await prisma.costAccount.findMany();
  const monthlyAmounts: Record<string, number[]> = {
    "6100": [8500000, 8500000, 8500000, 8500000, 8500000, 8500000],
    "6200": [1200000, 1150000, 1180000, 1220000, 1190000, 1210000],
    "6300": [980000, 920000, 1050000, 1100000, 990000, 1010000],
    "6400": [500000, 500000, 500000, 500000, 500000, 500000],
    "6500": [3200000, 3200000, 3200000, 3200000, 3200000, 3200000],
    "6600": [450000, 380000, 520000, 410000, 390000, 470000],
    "6700": [780000, 780000, 780000, 780000, 780000, 780000],
    "6800": [650000, 720000, 680000, 710000, 690000, 700000],
  };

  for (const account of accounts) {
    const amounts = monthlyAmounts[account.code];
    if (!amounts) continue;
    for (let month = 1; month <= 6; month++) {
      await prisma.monthlyCost.upsert({
        where: {
          projectId_costAccountId_month_version: {
            projectId: project.id,
            costAccountId: account.id,
            month,
            version: 1,
          },
        },
        create: {
          projectId: project.id,
          costAccountId: account.id,
          month,
          amount: BigInt(amounts[month - 1]),
          status: "DRAFT",
          createdById: admin.id,
        },
        update: { amount: BigInt(amounts[month - 1]) },
      });
    }
  }

  const companies = await prisma.company.findMany({ where: { isActive: true } });
  const domesticCount = companies.filter((c) => c.companyType === "DOMESTIC").length;
  const overseasCount = companies.filter((c) => c.companyType === "OVERSEAS").length;
  const domesticRate = 0.7 / domesticCount;
  const overseasRate = 0.3 / overseasCount;

  const rateVersion = await prisma.allocationRateVersion.upsert({
    where: { projectId_version: { projectId: project.id, version: 1 } },
    create: {
      projectId: project.id,
      version: 1,
      status: "DRAFT",
      totalRate: 1,
      createdById: admin.id,
      rates: {
        create: companies.map((c) => ({
          companyId: c.id,
          rate: c.companyType === "DOMESTIC" ? domesticRate : overseasRate,
        })),
      },
    },
    update: {},
  });

  await prisma.systemSetting.upsert({
    where: { key: "default_markup_rate" },
    create: {
      key: "default_markup_rate",
      value: 0.05,
      description: "해외법인 Mark-up 기본 비율 (향후 설정 확장)",
    },
    update: {},
  });

  await prisma.systemSetting.upsert({
    where: { key: "vat_enabled" },
    create: {
      key: "vat_enabled",
      value: false,
      description: "부가세 계산 (MVP 비활성)",
    },
    update: {},
  });

  console.log(`Seeded: ${companies.length} companies, ${accounts.length} accounts, project ${project.id}`);
  console.log(`Admin user: admin@kbi.local (id: ${admin.id})`);
  console.log(`Admin password: (SEED_ADMIN_PASSWORD or default ChangeMe123!)`);
  console.log(`Rate version: ${rateVersion.id}`);
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());

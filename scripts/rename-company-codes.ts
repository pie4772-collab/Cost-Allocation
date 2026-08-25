import { PrismaClient } from "@prisma/client";
import { formatCompanyCode } from "../src/lib/company-utils";

const prisma = new PrismaClient();

async function main() {
  const companies = await prisma.company.findMany({
    where: { deletedAt: null },
    orderBy: [{ sortOrder: "asc" }, { createdAt: "asc" }],
    select: { id: true, code: true, nameKo: true, sortOrder: true },
  });

  console.log(`대상 법인: ${companies.length}건`);

  await prisma.$transaction(async (tx) => {
    const allCompanies = await tx.company.findMany({ select: { id: true } });
    for (const company of allCompanies) {
      await tx.company.update({
        where: { id: company.id },
        data: { code: `__renaming__${company.id}` },
      });
    }

    for (let i = 0; i < companies.length; i++) {
      const company = companies[i];
      const newCode = formatCompanyCode(i + 1);
      await tx.company.update({
        where: { id: company.id },
        data: { code: newCode, sortOrder: i + 1 },
      });
      console.log(`${company.code} → ${newCode}  ${company.nameKo}`);
    }

    const deleted = await tx.company.findMany({
      where: { deletedAt: { not: null } },
      orderBy: { deletedAt: "asc" },
      select: { id: true, code: true, nameKo: true },
    });
    for (let i = 0; i < deleted.length; i++) {
      const archivedCode = `kbi-del-${String(i + 1).padStart(2, "0")}`;
      await tx.company.update({
        where: { id: deleted[i].id },
        data: { code: archivedCode },
      });
      console.log(`(삭제) ${deleted[i].code} → ${archivedCode}  ${deleted[i].nameKo}`);
    }
  });

  console.log("\n✓ 법인 코드 변경 완료");
}

main()
  .catch((e) => {
    console.error("❌", e.message ?? e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());

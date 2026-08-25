import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

async function main() {
  const companies = await prisma.company.findMany({
    where: { deletedAt: null },
    orderBy: [{ sortOrder: "asc" }, { createdAt: "asc" }],
    select: { id: true, code: true, nameKo: true, sortOrder: true },
  });
  console.log(JSON.stringify(companies, null, 2));
}

main().finally(() => prisma.$disconnect());

import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

async function main() {
  const accounts = await prisma.costAccount.findMany({
    where: { code: { startsWith: "ACC-" } },
    orderBy: { sortOrder: "asc" },
    select: { code: true, nameKo: true },
  });
  console.log(accounts);
}

main().finally(() => prisma.$disconnect());

import { PrismaClient } from "@prisma/client";
import { parseExcelCosts } from "../src/lib/excel-import";

const prisma = new PrismaClient();

const DEFAULT_FILE =
  "c:\\Users\\pie84\\OneDrive\\문서\\공동비용 배분\\260710 Scripture Room Cost Allocation Report (For DB UPload).xlsx";

const H1_PROJECT_ID = "cmsgzh31v000uv4z40z4iq9r4";

function fmt(n: bigint) {
  return Number(n).toLocaleString("ko-KR");
}

async function main() {
  const filePath = process.argv[2] ?? DEFAULT_FILE;
  console.log("파일:", filePath);

  const parsed = await parseExcelCosts(filePath);
  console.log(`계정 ${parsed.accounts.length}개, 원가 ${parsed.monthlyCosts.length}건`);
  console.log(`상반기 합계: ${parsed.grandTotal.toLocaleString("ko-KR")}원`);

  const admin =
    (await prisma.user.findFirst({ where: { email: "jaeyong.lee@kbigrp.com" } })) ??
    (await prisma.user.findFirst({ where: { email: "admin@kbi.local" } }));
  if (!admin) throw new Error("사용자를 찾을 수 없습니다.");

  const project = await prisma.allocationProject.findUniqueOrThrow({
    where: { id: H1_PROJECT_ID },
    include: { period: true },
  });

  const accountMap = new Map(
    (await prisma.costAccount.findMany()).map((a) => [a.nameKo, a.id])
  );

  const missingAccounts = parsed.accounts.filter((a) => !accountMap.has(a.nameKo));
  if (missingAccounts.length > 0) {
    throw new Error(
      `DB에 없는 계정: ${missingAccounts.map((a) => a.nameKo).join(", ")}`
    );
  }

  await prisma.monthlyCost.deleteMany({ where: { projectId: project.id } });

  let imported = 0;
  for (const mc of parsed.monthlyCosts) {
    const acc = parsed.accounts.find((a) => a.code === mc.accountCode);
    if (!acc) continue;
    const costAccountId = accountMap.get(acc.nameKo);
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
    imported++;
  }

  await prisma.allocationProject.update({
    where: { id: project.id },
    data: { status: "DRAFT" },
  });

  const byMonth = await prisma.monthlyCost.groupBy({
    by: ["month"],
    where: { projectId: project.id },
    _sum: { amount: true },
    _count: { _all: true },
  });

  const total = byMonth.reduce((s, m) => s + (m._sum.amount ?? 0n), 0n);

  console.log(`\n✓ ${project.name} (${project.period.label})`);
  console.log(`  ${imported}건 업로드`);
  for (const m of byMonth.sort((a, b) => a.month - b.month)) {
    console.log(`  ${m.month}월: ${fmt(m._sum.amount ?? 0n)}원 (${m._count._all}건)`);
  }
  console.log(`  합계: ${fmt(total)}원`);
}

main()
  .catch((e) => {
    console.error("❌", e.message ?? e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());

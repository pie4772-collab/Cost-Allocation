import { PrismaClient } from "@prisma/client";
import { parseExcelCosts } from "../src/lib/excel-import";
import {
  findOrCreateMonthlyPeriod,
  initializeProject,
} from "../src/lib/services/project-init-service";

const prisma = new PrismaClient();

const DEFAULT_FILE =
  "c:\\Users\\pie84\\OneDrive\\문서\\공동비용 배분\\260710 Scripture Room Cost Allocation Report (For DB UPload).xlsx";

const H1_PROJECT_ID = "cmsgzh31v000uv4z40z4iq9r4";
const YEAR = 2026;
const MONTHS = [1, 2, 3, 4, 5, 6] as const;

function fmt(n: bigint) {
  return Number(n).toLocaleString("ko-KR");
}

async function main() {
  const filePath = process.argv[2] ?? DEFAULT_FILE;
  console.log("파일:", filePath);

  const parsed = await parseExcelCosts(filePath, { months: [...MONTHS] });
  console.log(`Excel: ${parsed.monthlyCosts.length}건, 합계 ${parsed.grandTotal.toLocaleString("ko-KR")}원`);

  const admin =
    (await prisma.user.findFirst({ where: { email: "jaeyong.lee@kbigrp.com" } })) ??
    (await prisma.user.findFirst({ where: { email: "admin@kbi.local" } }));
  if (!admin) throw new Error("사용자를 찾을 수 없습니다.");

  const accountMap = new Map(
    (await prisma.costAccount.findMany()).map((a) => [a.nameKo, a.id])
  );
  const missingAccounts = parsed.accounts.filter((a) => !accountMap.has(a.nameKo));
  if (missingAccounts.length > 0) {
    throw new Error(`DB에 없는 계정: ${missingAccounts.map((a) => a.nameKo).join(", ")}`);
  }

  const h1Deleted = await prisma.monthlyCost.deleteMany({
    where: { projectId: H1_PROJECT_ID },
  });
  await prisma.allocationProject.update({
    where: { id: H1_PROJECT_ID },
    data: { status: "DRAFT" },
  });
  console.log(`\n✓ 반기(H1) 원가 ${h1Deleted.count}건 삭제`);

  let grandTotal = 0n;

  for (const month of MONTHS) {
    const period = await findOrCreateMonthlyPeriod(YEAR, month);

    let project = await prisma.allocationProject.findFirst({
      where: { periodId: period.id, version: 1 },
      include: { period: true },
    });

    if (!project) {
      project = await prisma.allocationProject.create({
        data: {
          periodId: period.id,
          name: `${YEAR}년 ${month}월 공동비용 배부`,
          strictRateValidation: false,
          createdById: admin.id,
        },
        include: { period: true },
      });
      await initializeProject(project.id, admin.id);
      console.log(`+ ${project.name} 생성 (${project.id})`);
    } else if (project.strictRateValidation) {
      await prisma.allocationProject.update({
        where: { id: project.id },
        data: { strictRateValidation: false, status: "DRAFT" },
      });
    }

    await prisma.monthlyCost.deleteMany({ where: { projectId: project.id } });

    const monthCosts = parsed.monthlyCosts.filter((mc) => mc.month === month);
    let imported = 0;
    for (const mc of monthCosts) {
      const acc = parsed.accounts.find((a) => a.code === mc.accountCode);
      if (!acc) continue;
      const costAccountId = accountMap.get(acc.nameKo);
      if (!costAccountId) continue;

      await prisma.monthlyCost.create({
        data: {
          projectId: project.id,
          costAccountId,
          month,
          amount: BigInt(mc.amount),
          status: "DRAFT",
          createdById: admin.id,
        },
      });
      imported++;
    }

    const sum = await prisma.monthlyCost.aggregate({
      where: { projectId: project.id },
      _sum: { amount: true },
    });
    const total = sum._sum.amount ?? 0n;
    grandTotal += total;

    console.log(
      `✓ ${YEAR}년 ${month}월: ${imported}건, ${fmt(total)}원 (${project.id})`
    );
  }

  console.log(`\n월별 합계: ${fmt(grandTotal)}원`);
}

main()
  .catch((e) => {
    console.error("❌", e.message ?? e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());

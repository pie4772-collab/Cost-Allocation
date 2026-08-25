import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

function fmt(n: bigint) {
  return Number(n).toLocaleString("ko-KR");
}

async function main() {
  const projects = await prisma.allocationProject.findMany({
    where: { period: { year: 2026 } },
    include: { period: true },
    orderBy: [{ period: { cadence: "asc" } }, { period: { periodKey: "asc" } }],
  });

  console.log("=== 2026 원가 현황 ===\n");

  for (const p of projects) {
    const byMonth = await prisma.monthlyCost.groupBy({
      by: ["month"],
      where: { projectId: p.id },
      _sum: { amount: true },
      _count: { _all: true },
    });

    const nonzero = await prisma.monthlyCost.count({
      where: { projectId: p.id, amount: { not: 0n } },
    });

    const total = byMonth.reduce((s, m) => s + (m._sum.amount ?? 0n), 0n);

    console.log(`[${p.period.cadence}] ${p.name}`);
    console.log(`  id: ${p.id}`);
    console.log(`  period: ${p.period.label}`);
    console.log(`  status: ${p.status}`);
    console.log(`  total: ${fmt(total)}원 (${nonzero}건 nonzero / ${byMonth.reduce((s, m) => s + m._count._all, 0)} rows)`);

    const monthLines = byMonth
      .sort((a, b) => a.month - b.month)
      .map((m) => `    ${m.month}월: ${fmt(m._sum.amount ?? 0n)}원 (${m._count._all} rows)`)
      .join("\n");
    if (monthLines) console.log(monthLines);
    console.log("");
  }

  // Compare H1 Jan vs Monthly Jan (should match after sync)
  const h1 = projects.find((p) => p.period.cadence === "SEMI_ANNUAL" && p.period.periodKey === 1);
  const jan = projects.find((p) => p.period.cadence === "MONTHLY" && p.period.periodKey === 1);

  if (h1 && jan) {
    console.log("=== 1월 반기 vs 월별 비교 ===\n");
    const h1Jan = await prisma.monthlyCost.findMany({
      where: { projectId: h1.id, month: 1 },
      include: { costAccount: { select: { code: true, nameKo: true } } },
      orderBy: { costAccount: { sortOrder: "asc" } },
    });
    const mJan = await prisma.monthlyCost.findMany({
      where: { projectId: jan.id, month: 1 },
      include: { costAccount: { select: { code: true, nameKo: true } } },
      orderBy: { costAccount: { sortOrder: "asc" } },
    });

    const mMap = new Map(mJan.map((c) => [c.costAccountId, c.amount]));
    let diffs = 0;
    for (const row of h1Jan) {
      const other = mMap.get(row.costAccountId) ?? 0n;
      if (row.amount !== other) {
        diffs++;
        console.log(
          `  DIFF ${row.costAccount.code} ${row.costAccount.nameKo}: H1=${fmt(row.amount)} vs 월별=${fmt(other)}`
        );
      }
    }
    if (diffs === 0) {
      console.log("  ✓ 1월 계정별 금액 일치 (H1 ↔ 월별 1월)");
    } else {
      console.log(`  ⚠ ${diffs}건 불일치`);
    }

    const h1JanTotal = h1Jan.reduce((s, c) => s + c.amount, 0n);
    const mJanTotal = mJan.reduce((s, c) => s + c.amount, 0n);
    console.log(`  H1 1월 합계: ${fmt(h1JanTotal)}원`);
    console.log(`  월별 1월 합계: ${fmt(mJanTotal)}원`);
  }

  // H1 costs modified today?
  if (h1) {
    console.log("\n=== 오늘 수정된 H1 원가 ===\n");
    const recentH1 = await prisma.monthlyCost.findMany({
      where: {
        projectId: h1.id,
        updatedAt: { gte: new Date("2026-08-14T00:00:00Z") },
      },
      include: { costAccount: { select: { nameKo: true, code: true } } },
      orderBy: { updatedAt: "desc" },
    });
    if (recentH1.length === 0) {
      console.log("  ✓ 2026 H1 반기 원가는 오늘 변경되지 않음");
    } else {
      console.log(`  ⚠ ${recentH1.length}건 오늘 updatedAt 갱신`);
      for (const r of recentH1.slice(0, 10)) {
        console.log(
          `    ${r.updatedAt.toISOString().slice(0, 19)} | ${r.month}월 ${r.costAccount.code} ${r.costAccount.nameKo} | ${fmt(r.amount)}원`
        );
      }
    }
  }

  // Seed vs real accounts in H1
  if (h1) {
    console.log("\n=== H1 계정 구성 ===\n");
    const costs = await prisma.monthlyCost.findMany({
      where: { projectId: h1.id, amount: { not: 0n } },
      include: { costAccount: { select: { code: true, nameKo: true } } },
    });
    const byAccount = new Map<string, { name: string; total: bigint }>();
    for (const c of costs) {
      const key = c.costAccount.code;
      const cur = byAccount.get(key) ?? { name: c.costAccount.nameKo, total: 0n };
      cur.total += c.amount;
      byAccount.set(key, cur);
    }
    const seedCodes = ["6100", "6200", "6300", "6400", "6500", "6600", "6700", "6800"];
    let seedTotal = 0n;
    let realTotal = 0n;
    for (const [code, v] of [...byAccount.entries()].sort()) {
      const isSeed = seedCodes.includes(code);
      if (isSeed) seedTotal += v.total;
      else realTotal += v.total;
      if (byAccount.size <= 30) {
        console.log(`  ${code} ${v.name}: ${fmt(v.total)}원${isSeed ? " (seed 계정)" : ""}`);
      }
    }
    console.log(`\n  seed 계정(6100~6800) 합: ${fmt(seedTotal)}원`);
    console.log(`  실제 업무 계정(ACC-* 등) 합: ${fmt(realTotal)}원`);
  }
  console.log("\n=== 최근 원가 관련 감사로그 ===\n");
  const logs = await prisma.auditLog.findMany({
    where: {
      OR: [
        { action: { in: ["COST_IMPORT", "COST_SYNC", "CREATE", "UPDATE"] } },
        { entityType: { in: ["MonthlyCost", "AllocationProject"] } },
      ],
      createdAt: { gte: new Date("2026-01-01") },
    },
    orderBy: { createdAt: "desc" },
    take: 15,
    include: { user: { select: { email: true } } },
  });

  if (logs.length === 0) {
    console.log("  (없음)");
  } else {
    for (const log of logs) {
      console.log(
        `  ${log.createdAt.toISOString().slice(0, 19)} | ${log.action} | ${log.entityType} | ${log.user?.email ?? "-"}`
      );
    }
  }
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());

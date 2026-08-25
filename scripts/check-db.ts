#!/usr/bin/env tsx
/**
 * PostgreSQL 연결 및 시드 사용자 확인
 * Usage: npx tsx --env-file=.env scripts/check-db.ts
 */
import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

function mask(value: string) {
  if (value.length <= 12) return "***";
  return value.slice(0, 12) + "..." + value.slice(-4);
}

async function main() {
  console.log("=== DB 연결 확인 ===\n");

  const url = process.env.DATABASE_URL;
  if (!url) {
    console.log("✗ DATABASE_URL 미설정");
    process.exit(1);
  }
  console.log("DATABASE_URL:", mask(url));

  try {
    await prisma.$queryRaw`SELECT 1`;
    console.log("✓ PostgreSQL 연결 성공");
  } catch (e) {
    console.log("✗ PostgreSQL 연결 실패:", (e as Error).message);
    console.log("  → PostgreSQL 서비스 실행 및 DATABASE_URL 확인");
    console.log("  → Windows: docs/LOCAL_POSTGRES_WINDOWS.md");
    process.exit(1);
  }

  const userCount = await prisma.user.count();
  const projectCount = await prisma.allocationProject.count();
  const companyCount = await prisma.company.count({ where: { isActive: true } });

  console.log(`\nusers: ${userCount}, projects: ${projectCount}, companies: ${companyCount}`);

  const admin = await prisma.user.findUnique({
    where: { email: "admin@kbi.local" },
    select: { id: true, email: true, passwordHash: true, isActive: true },
  });

  if (admin) {
    console.log("✓ admin@kbi.local 존재");
    console.log(
      admin.passwordHash
        ? "✓ passwordHash 설정됨 (로그인 가능)"
        : "✗ passwordHash 없음 — npm run db:seed 실행"
    );
  } else {
    console.log("✗ admin@kbi.local 없음 — npm run db:seed 실행");
  }

  if (!process.env.SESSION_SECRET || process.env.SESSION_SECRET.length < 16) {
    console.log("\n⚠ SESSION_SECRET 미설정 (production 배포 전 필수)");
  } else {
    console.log("\n✓ SESSION_SECRET 설정됨");
  }

  console.log("\n✅ DB 확인 완료");
}

main()
  .catch((e) => {
    console.error("❌", e.message ?? e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());

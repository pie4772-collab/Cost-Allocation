import "server-only";
import { prisma } from "./db";
import { INIT_SQL } from "./init-schema-sql";

function sqlStatements(sql: string): string[] {
  return sql
    .split(";")
    .map((part) =>
      part
        .split("\n")
        .filter((line) => !line.trim().startsWith("--"))
        .join("\n")
        .trim()
    )
    .filter(Boolean);
}

async function usersTableExists(): Promise<boolean> {
  const rows = await prisma.$queryRaw<Array<{ exists: boolean }>>`
    SELECT EXISTS (
      SELECT 1
      FROM information_schema.tables
      WHERE table_schema = 'public'
        AND table_name = 'users'
    ) AS exists
  `;
  return Boolean(rows[0]?.exists);
}

async function ensureSchema() {
  if (await usersTableExists()) return;
  console.log("runtime-init: creating database tables");
  for (const stmt of sqlStatements(INIT_SQL)) {
    await prisma.$executeRawUnsafe(stmt);
  }
}

async function seedAdminIfEmpty() {
  if (process.env.IMPORT_LOCAL_DATA === "true") {
    console.log("runtime-init: skip seed while local data import is enabled");
    return;
  }
  if ((await prisma.user.count()) > 0) return;
  const bcrypt = await import("bcryptjs");
  const hashFn = bcrypt.hash ?? bcrypt.default.hash;
  const roleNames = [
    "Admin",
    "CostManager",
    "AllocationManager",
    "Approver",
    "BillingManager",
    "Auditor",
    "Viewer",
  ] as const;
  for (const name of roleNames) {
    await prisma.role.upsert({
      where: { name },
      create: { name, description: `${name} role` },
      update: {},
    });
  }
  const adminRole = await prisma.role.findUniqueOrThrow({
    where: { name: "Admin" },
  });
  await prisma.user.create({
    data: {
      email: "admin@kbi.local",
      name: "시스템 관리자",
      passwordHash: await hashFn(
        process.env.SEED_ADMIN_PASSWORD ?? "ChangeMe123!",
        10
      ),
      isActive: true,
      roles: { create: [{ roleId: adminRole.id }] },
    },
  });
  console.log("runtime-init: created admin@kbi.local");
}

export async function initSchemaAndAdmin() {
  try {
    await ensureSchema();
    await seedAdminIfEmpty();
  } catch (err) {
    console.error("runtime-init failed", err);
  }
}

import { spawn } from "node:child_process";
import path from "node:path";
import { prisma } from "./db";

function runPrismaPush() {
  const prismaCli = path.join(
    process.cwd(),
    "node_modules",
    "prisma",
    "build",
    "index.js"
  );
  return new Promise<void>((resolve, reject) => {
    const child = spawn(
      process.execPath,
      [prismaCli, "db", "push", "--skip-generate", "--accept-data-loss"],
      {
        cwd: process.cwd(),
        stdio: "inherit",
        env: { ...process.env, CI: "true" },
      }
    );
    child.on("error", reject);
    child.on("exit", (code) => {
      if (code === 0) resolve();
      else reject(new Error(`prisma db push exited ${code}`));
    });
  });
}

async function seedAdminIfEmpty() {
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
  console.log("runtime-init: applying database schema");
  await runPrismaPush();
  await seedAdminIfEmpty();
}

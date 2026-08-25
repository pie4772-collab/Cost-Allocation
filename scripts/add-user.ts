#!/usr/bin/env tsx
/**
 * 팀원 사용자 추가 (비밀번호 해시 포함)
 * Usage: npx tsx --env-file=.env scripts/add-user.ts email@kbigrp.com "이름" password
 */
import { PrismaClient, RoleName } from "@prisma/client";
import bcrypt from "bcryptjs";

const prisma = new PrismaClient();

async function main() {
  const email = process.argv[2]?.toLowerCase();
  const name = process.argv[3];
  const password = process.argv[4];

  if (!email || !name || !password) {
    console.log("Usage: npx tsx --env-file=.env scripts/add-user.ts <email> <name> <password>");
    process.exit(1);
  }

  const roleNames: RoleName[] = email.endsWith("@kbigrp.com")
    ? ["Admin", "CostManager", "AllocationManager", "Approver", "BillingManager"]
    : ["Viewer"];

  const roles = await prisma.role.findMany({ where: { name: { in: roleNames } } });
  const passwordHash = await bcrypt.hash(password, 12);

  const user = await prisma.user.upsert({
    where: { email },
    create: {
      email,
      name,
      passwordHash,
      isActive: true,
      roles: { create: roles.map((r) => ({ roleId: r.id })) },
    },
    update: { name, passwordHash, isActive: true },
  });

  console.log(`✓ User ${user.email} (${user.id})`);
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());

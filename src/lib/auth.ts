import { NextRequest } from "next/server";
import prisma from "./db";
import { getSessionFromRequest } from "./session";
import type { RoleName } from "@prisma/client";

export interface SessionUser {
  id: string;
  email: string;
  name: string;
  roles: RoleName[];
}

const DEV_USER: SessionUser = {
  id: "dev-admin",
  email: "admin@kbi.local",
  name: "관리자",
  roles: [
    "Admin",
    "CostManager",
    "AllocationManager",
    "Approver",
    "BillingManager",
    "Auditor",
  ],
};

function toSessionUser(user: {
  id: string;
  email: string;
  name: string;
  roles: Array<{ role: { name: RoleName } }>;
}): SessionUser {
  return {
    id: user.id,
    email: user.email,
    name: user.name,
    roles: user.roles.map((r) => r.role.name),
  };
}

export async function getSessionUser(
  request?: NextRequest
): Promise<SessionUser | null> {
  if (process.env.AUTH_DISABLED === "true") {
    const devUserId = process.env.DEV_USER_ID;
    if (devUserId) {
      const user = await prisma.user.findUnique({
        where: { id: devUserId },
        include: { roles: { include: { role: true } } },
      });
      if (user) return toSessionUser(user);
    }
    return DEV_USER;
  }

  const session = await getSessionFromRequest(request);
  if (!session?.sub) return null;

  const user = await prisma.user.findFirst({
    where: { id: session.sub, isActive: true, deletedAt: null },
    include: { roles: { include: { role: true } } },
  });

  if (!user) return null;
  return toSessionUser(user);
}

export function hasRole(user: SessionUser, ...roles: RoleName[]): boolean {
  if (user.roles.includes("Admin")) return true;
  return roles.some((r) => user.roles.includes(r));
}

export function requireRole(user: SessionUser, ...roles: RoleName[]): void {
  if (!hasRole(user, ...roles)) {
    throw new Error("FORBIDDEN");
  }
}

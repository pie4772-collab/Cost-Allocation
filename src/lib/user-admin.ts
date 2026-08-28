import type { NextRequest } from "next/server";
import type { RoleName } from "@prisma/client";
import prisma from "@/lib/db";
import { getSessionUser, hasRole, type SessionUser } from "@/lib/auth";

const USER_PUBLIC_SELECT = {
  id: true,
  email: true,
  name: true,
  isActive: true,
  createdAt: true,
  roles: { include: { role: true } },
} as const;

export type UserWithRoles = {
  id: string;
  email: string;
  name: string;
  isActive: boolean;
  createdAt: Date;
  roles: Array<{ role: { name: RoleName } }>;
};

export function toPublicUser(user: UserWithRoles) {
  return {
    id: user.id,
    email: user.email,
    name: user.name,
    isActive: user.isActive,
    createdAt: user.createdAt,
    roles: user.roles.map((r) => r.role.name),
  };
}

export const userPublicSelect = USER_PUBLIC_SELECT;

export async function requireAdminUser(request: NextRequest): Promise<SessionUser> {
  const user = await getSessionUser(request);
  if (!user) throw new Error("FORBIDDEN");
  if (!hasRole(user, "Admin")) {
    throw new Error("FORBIDDEN");
  }
  return user;
}

export function userHasAdmin(user: UserWithRoles): boolean {
  return user.roles.some((r) => r.role.name === "Admin");
}

export async function countActiveAdmins(): Promise<number> {
  return prisma.user.count({
    where: {
      isActive: true,
      deletedAt: null,
      roles: { some: { role: { name: "Admin" } } },
    },
  });
}

export async function findManagedUser(id: string): Promise<UserWithRoles> {
  const user = await prisma.user.findFirst({
    where: { id, deletedAt: null },
    select: USER_PUBLIC_SELECT,
  });
  if (!user) throw new Error("NOT_FOUND");
  return user;
}

export async function assertCanDeactivateOrDelete(
  actor: SessionUser,
  target: UserWithRoles
): Promise<void> {
  if (actor.id === target.id) {
    throw new Error("본인 계정은 비활성화하거나 삭제할 수 없습니다.");
  }
  if (userHasAdmin(target) && (await countActiveAdmins()) <= 1) {
    throw new Error("마지막 관리자 계정은 비활성화하거나 삭제할 수 없습니다.");
  }
}

export async function assertCanChangeRoles(
  target: UserWithRoles,
  nextRoles: RoleName[]
): Promise<void> {
  if (!userHasAdmin(target) || nextRoles.includes("Admin")) return;
  if ((await countActiveAdmins()) <= 1) {
    throw new Error("마지막 관리자 역할은 제거할 수 없습니다.");
  }
}

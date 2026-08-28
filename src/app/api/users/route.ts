import { NextRequest } from "next/server";
import bcrypt from "bcryptjs";
import prisma from "@/lib/db";
import { jsonOk, handleApiError } from "@/lib/api-utils";
import { userCreateSchema } from "@/lib/validations";
import { createAuditLog } from "@/lib/audit";
import {
  requireAdminUser,
  toPublicUser,
  userPublicSelect,
} from "@/lib/user-admin";

export async function GET(request: NextRequest) {
  try {
    await requireAdminUser(request);

    const users = await prisma.user.findMany({
      where: { deletedAt: null },
      select: userPublicSelect,
      orderBy: [{ isActive: "desc" }, { createdAt: "asc" }],
    });

    return jsonOk(users.map(toPublicUser));
  } catch (error) {
    return handleApiError(error);
  }
}

export async function POST(request: NextRequest) {
  try {
    const actor = await requireAdminUser(request);
    const body = userCreateSchema.parse(await request.json());
    const email = body.email.trim().toLowerCase();

    const existing = await prisma.user.findUnique({ where: { email } });
    if (existing) {
      throw new Error("이미 등록된 이메일입니다.");
    }

    const roleRecords = await prisma.role.findMany({
      where: { name: { in: body.roles } },
    });
    if (roleRecords.length !== body.roles.length) {
      throw new Error("유효하지 않은 역할입니다.");
    }

    const passwordHash = await bcrypt.hash(body.password, 12);
    const created = await prisma.user.create({
      data: {
        email,
        name: body.name.trim(),
        passwordHash,
        isActive: true,
        roles: { create: roleRecords.map((role) => ({ roleId: role.id })) },
      },
      select: userPublicSelect,
    });

    const publicUser = toPublicUser(created);
    await createAuditLog({
      userId: actor.id,
      action: "CREATE",
      entityType: "User",
      entityId: created.id,
      afterData: publicUser,
    });

    return jsonOk(publicUser, 201);
  } catch (error) {
    return handleApiError(error);
  }
}

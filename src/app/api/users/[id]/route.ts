import { NextRequest } from "next/server";
import bcrypt from "bcryptjs";
import type { Prisma } from "@prisma/client";
import prisma from "@/lib/db";
import { jsonOk, handleApiError } from "@/lib/api-utils";
import { userUpdateSchema } from "@/lib/validations";
import { createAuditLog } from "@/lib/audit";
import {
  assertCanChangeRoles,
  assertCanDeactivateOrDelete,
  findManagedUser,
  requireAdminUser,
  toPublicUser,
  userPublicSelect,
} from "@/lib/user-admin";

type RouteParams = { params: Promise<{ id: string }> };

export async function PATCH(request: NextRequest, { params }: RouteParams) {
  try {
    const actor = await requireAdminUser(request);
    const { id } = await params;
    const body = userUpdateSchema.parse(await request.json());
    const before = await findManagedUser(id);

    if (body.isActive === false) {
      await assertCanDeactivateOrDelete(actor, before);
    }
    if (body.roles) {
      await assertCanChangeRoles(before, body.roles);
    }

    const data: Prisma.UserUpdateInput = {};
    if (body.name !== undefined) data.name = body.name.trim();
    if (body.isActive !== undefined) data.isActive = body.isActive;
    if (body.password) {
      data.passwordHash = await bcrypt.hash(body.password, 12);
    }

    let roleRecords: { id: string }[] | undefined;
    if (body.roles) {
      roleRecords = await prisma.role.findMany({
        where: { name: { in: body.roles } },
      });
      if (roleRecords.length !== body.roles.length) {
        throw new Error("유효하지 않은 역할입니다.");
      }
    }

    const updated = await prisma.$transaction(async (tx) => {
      if (roleRecords) {
        await tx.userRole.deleteMany({ where: { userId: id } });
        await tx.userRole.createMany({
          data: roleRecords.map((role) => ({ userId: id, roleId: role.id })),
        });
      }
      return tx.user.update({
        where: { id },
        data,
        select: userPublicSelect,
      });
    });

    const publicUser = toPublicUser(updated);
    await createAuditLog({
      userId: actor.id,
      action: "UPDATE",
      entityType: "User",
      entityId: id,
      beforeData: toPublicUser(before),
      afterData: publicUser,
    });

    return jsonOk(publicUser);
  } catch (error) {
    return handleApiError(error);
  }
}

export async function DELETE(request: NextRequest, { params }: RouteParams) {
  try {
    const actor = await requireAdminUser(request);
    const { id } = await params;
    const before = await findManagedUser(id);
    await assertCanDeactivateOrDelete(actor, before);

    const updated = await prisma.user.update({
      where: { id },
      data: { isActive: false, deletedAt: new Date() },
      select: userPublicSelect,
    });

    await createAuditLog({
      userId: actor.id,
      action: "DELETE",
      entityType: "User",
      entityId: id,
      beforeData: toPublicUser(before),
    });

    return jsonOk(toPublicUser(updated));
  } catch (error) {
    return handleApiError(error);
  }
}

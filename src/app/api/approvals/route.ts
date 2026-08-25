import { NextRequest } from "next/server";
import prisma from "@/lib/db";
import { getSessionUser } from "@/lib/auth";
import { jsonOk, handleApiError, serializeBigInt } from "@/lib/api-utils";
import { createAuditLog } from "@/lib/audit";

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const status = searchParams.get("status");

    const requests = await prisma.approvalRequest.findMany({
      where: status ? { status: status as never } : undefined,
      include: {
        actions: {
          include: { user: { select: { id: true, name: true } } },
          orderBy: { createdAt: "desc" },
        },
      },
      orderBy: { createdAt: "desc" },
    });
    return jsonOk(serializeBigInt(requests));
  } catch (error) {
    return handleApiError(error);
  }
}

export async function POST(request: NextRequest) {
  try {
    const user = await getSessionUser(request);
    if (!user) return handleApiError(new Error("FORBIDDEN"));

    const body = await request.json();

    const approval = await prisma.approvalRequest.create({
      data: {
        type: body.type,
        entityType: body.entityType,
        entityId: body.entityId,
        requestedBy: user.id,
        reason: body.reason,
      },
    });

    await createAuditLog({
      userId: user.id,
      action: "APPROVAL_REQUEST",
      entityType: "ApprovalRequest",
      entityId: approval.id,
      afterData: approval,
    });

    return jsonOk(serializeBigInt(approval), 201);
  } catch (error) {
    return handleApiError(error);
  }
}

export async function PATCH(request: NextRequest) {
  try {
    const user = await getSessionUser(request);
    if (!user) return handleApiError(new Error("FORBIDDEN"));

    const { requestId, action, comment } = await request.json();

    const result = await prisma.$transaction(async (tx) => {
      await tx.approvalAction.create({
        data: {
          requestId,
          userId: user.id,
          action,
          comment,
        },
      });

      return tx.approvalRequest.update({
        where: { id: requestId },
        data: { status: action },
      });
    });

    return jsonOk(serializeBigInt(result));
  } catch (error) {
    return handleApiError(error);
  }
}

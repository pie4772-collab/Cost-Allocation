import { NextRequest } from "next/server";
import prisma from "@/lib/db";
import { getSessionUser } from "@/lib/auth";
import { jsonOk, handleApiError, serializeBigInt } from "@/lib/api-utils";
import { createAuditLog } from "@/lib/audit";
import { z } from "zod";

const updateProjectSchema = z.object({
  name: z.string().min(1).max(200),
  notes: z.string().optional(),
});

export async function PATCH(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const user = await getSessionUser(request);
    if (!user) return handleApiError(new Error("FORBIDDEN"));

    const { id } = await params;
    const body = updateProjectSchema.parse(await request.json());

    const project = await prisma.allocationProject.findUniqueOrThrow({
      where: { id },
    });

    if (project.status === "CLOSED") {
      throw new Error("마감된 프로젝트는 수정할 수 없습니다.");
    }

    const updated = await prisma.allocationProject.update({
      where: { id },
      data: {
        name: body.name,
        ...(body.notes !== undefined ? { notes: body.notes } : {}),
      },
      include: {
        period: true,
        rateVersions: { orderBy: { version: "desc" }, take: 1 },
        runs: { orderBy: { createdAt: "desc" }, take: 1 },
        _count: { select: { monthlyCosts: true } },
      },
    });

    await createAuditLog({
      userId: user.id,
      action: "UPDATE",
      entityType: "AllocationProject",
      entityId: id,
      beforeData: { name: project.name },
      afterData: { name: updated.name },
    });

    return jsonOk(serializeBigInt(updated));
  } catch (error) {
    return handleApiError(error);
  }
}

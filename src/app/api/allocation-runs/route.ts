import { NextRequest } from "next/server";
import { getSessionUser } from "@/lib/auth";
import { jsonOk, handleApiError, serializeBigInt } from "@/lib/api-utils";
import { allocationRunSchema } from "@/lib/validations";
import { executeAllocation, cancelProjectAllocation } from "@/lib/services/allocation-service";
import prisma from "@/lib/db";
import { z } from "zod";

const runInclude = {
  details: {
    include: { company: true, costAccount: true },
  },
  summaries: { include: { company: true } },
  reconciliation: true,
  rateVersion: true,
} as const;

export async function POST(request: NextRequest) {
  try {
    const user = await getSessionUser(request);
    if (!user) return handleApiError(new Error("FORBIDDEN"));

    const body = allocationRunSchema.parse(await request.json());

    const run = await executeAllocation(
      body.projectId,
      body.rateVersionId,
      user.id,
      body.runType
    );

    const full = await prisma.allocationRun.findUniqueOrThrow({
      where: { id: run.id },
      include: runInclude,
    });

    return jsonOk(serializeBigInt(full), 201);
  } catch (error) {
    return handleApiError(error);
  }
}

export async function PATCH(request: NextRequest) {
  try {
    const user = await getSessionUser(request);
    if (!user) return handleApiError(new Error("FORBIDDEN"));

    const body = z
      .object({
        projectId: z.string(),
        action: z.literal("cancel"),
        runId: z.string().optional(),
      })
      .parse(await request.json());

    const result = await cancelProjectAllocation(body.projectId, user.id, {
      runId: body.runId,
    });

    return jsonOk(serializeBigInt(result));
  } catch (error) {
    return handleApiError(error);
  }
}

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const projectId = searchParams.get("projectId");
    const runId = searchParams.get("runId");
    const latest = searchParams.get("latest") === "true";

    if (runId) {
      const run = await prisma.allocationRun.findUniqueOrThrow({
        where: { id: runId },
        include: runInclude,
      });
      return jsonOk(serializeBigInt(run));
    }

    if (projectId && latest) {
      const run = await prisma.allocationRun.findFirst({
        where: { projectId },
        orderBy: { createdAt: "desc" },
        include: runInclude,
      });
      return jsonOk(serializeBigInt(run));
    }

    const runs = await prisma.allocationRun.findMany({
      where: projectId ? { projectId } : undefined,
      orderBy: { createdAt: "desc" },
      include: { rateVersion: true },
      take: projectId ? 10 : undefined,
    });
    return jsonOk(serializeBigInt(runs));
  } catch (error) {
    return handleApiError(error);
  }
}

import { NextRequest } from "next/server";
import prisma from "@/lib/db";
import { getSessionUser } from "@/lib/auth";
import { jsonOk, handleApiError, serializeBigInt } from "@/lib/api-utils";
import { projectSchema } from "@/lib/validations";
import { createAuditLog } from "@/lib/audit";
import {
  findOrCreatePeriod,
  findOrCreateMonthlyPeriod,
  initializeProject,
  periodCadenceFromBody,
} from "@/lib/services/project-init-service";
import { allowsFlexibleRateTotal } from "@/lib/period-utils";
import { z } from "zod";

const createProjectSchema = projectSchema.extend({
  cadence: z.enum(["SEMI_ANNUAL", "MONTHLY"]).optional(),
  year: z.number().int().min(2020).max(2100).optional(),
  half: z.number().int().min(1).max(2).optional(),
  month: z.number().int().min(1).max(12).optional(),
});

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const periodId = searchParams.get("periodId");
    const cadence = searchParams.get("cadence");

    const projects = await prisma.allocationProject.findMany({
      where: {
        ...(periodId ? { periodId } : {}),
        ...(cadence === "MONTHLY" || cadence === "SEMI_ANNUAL"
          ? { period: { cadence } }
          : {}),
      },
      include: {
        period: true,
        rateVersions: { orderBy: { version: "desc" }, take: 1 },
        runs: { orderBy: { createdAt: "desc" }, take: 1 },
        _count: { select: { monthlyCosts: true } },
      },
      orderBy: [
        { period: { cadence: "desc" } },
        { period: { year: "desc" } },
        { period: { periodKey: "desc" } },
      ],
    });
    return jsonOk(serializeBigInt(projects));
  } catch (error) {
    return handleApiError(error);
  }
}

export async function POST(request: NextRequest) {
  try {
    const user = await getSessionUser(request);
    if (!user) return handleApiError(new Error("FORBIDDEN"));

    const raw = await request.json();
    const body = createProjectSchema.parse(raw);
    const cadence = periodCadenceFromBody(body);

    let periodId = body.periodId;
    if (cadence === "MONTHLY") {
      if (!body.year || !body.month) {
        throw new Error("월별 프로젝트는 year, month가 필요합니다.");
      }
      const period = await findOrCreateMonthlyPeriod(body.year, body.month);
      periodId = period.id;
    } else if (body.year && body.half) {
      const period = await findOrCreatePeriod(body.year, body.half);
      periodId = period.id;
    }
    if (!periodId) {
      throw new Error("회계기간(year/half 또는 year/month)을 지정해주세요.");
    }

    const period = await prisma.accountingPeriod.findUniqueOrThrow({
      where: { id: periodId },
    });

    const existing = await prisma.allocationProject.findFirst({
      where: { periodId, version: 1 },
    });
    if (existing) {
      throw new Error(`${period.label} 프로젝트가 이미 존재합니다.`);
    }

    const project = await prisma.allocationProject.create({
      data: {
        periodId,
        name: body.name,
        notes: body.notes,
        strictRateValidation: !allowsFlexibleRateTotal(period),
        createdById: user.id,
      },
      include: { period: true },
    });

    await initializeProject(project.id, user.id);

    await createAuditLog({
      userId: user.id,
      action: "CREATE",
      entityType: "AllocationProject",
      entityId: project.id,
      afterData: project,
    });

    const full = await prisma.allocationProject.findUniqueOrThrow({
      where: { id: project.id },
      include: {
        period: true,
        rateVersions: { orderBy: { version: "desc" }, take: 1 },
        _count: { select: { monthlyCosts: true } },
      },
    });

    return jsonOk(serializeBigInt(full), 201);
  } catch (error) {
    return handleApiError(error);
  }
}

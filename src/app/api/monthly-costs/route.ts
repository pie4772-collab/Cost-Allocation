import { NextRequest } from "next/server";
import prisma from "@/lib/db";
import { getSessionUser } from "@/lib/auth";
import { jsonOk, handleApiError, serializeBigInt } from "@/lib/api-utils";
import { monthlyCostSchema } from "@/lib/validations";

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const projectId = searchParams.get("projectId");
    if (!projectId) return handleApiError(new Error("projectId is required"));

    if (searchParams.get("monthlySources") === "true") {
      const { getMonthlyCostSources } = await import(
        "@/lib/services/cost-import-service"
      );
      return jsonOk(await getMonthlyCostSources(projectId));
    }

    const costs = await prisma.monthlyCost.findMany({
      where: { projectId },
      include: {
        costAccount: true,
        createdBy: { select: { id: true, name: true } },
      },
      orderBy: [{ costAccountId: "asc" }, { month: "asc" }],
    });
    return jsonOk(serializeBigInt(costs));
  } catch (error) {
    return handleApiError(error);
  }
}

export async function POST(request: NextRequest) {
  try {
    const user = await getSessionUser(request);
    if (!user) return handleApiError(new Error("FORBIDDEN"));

    const body = await request.json();

    if (body.action === "import_from_monthly") {
      const { projectId, months } = body as {
        projectId: string;
        months?: number[];
      };
      const { importMonthlyCostsToSemiProject } = await import(
        "@/lib/services/cost-import-service"
      );
      const result = await importMonthlyCostsToSemiProject(
        projectId,
        user.id,
        months
      );
      return jsonOk(result);
    }

    if (body.action === "sync_to_monthly") {
      const { projectId, month } = body as { projectId: string; month: number };
      const { syncSemiCostsToMonthlyProject } = await import(
        "@/lib/services/cost-import-service"
      );
      const result = await syncSemiCostsToMonthlyProject(
        projectId,
        month,
        user.id
      );
      return jsonOk(result);
    }

    if (body.action === "bulk") {
      const { projectId, items } = body as {
        projectId: string;
        items: Array<{ costAccountId: string; month: number; amount: number }>;
      };

      const project = await prisma.allocationProject.findUniqueOrThrow({
        where: { id: projectId },
      });
      if (project.status !== "DRAFT" && project.status !== "COST_CONFIRMED") {
        throw new Error("마감된 프로젝트의 원가는 수정할 수 없습니다.");
      }

      for (const item of items) {
        await prisma.monthlyCost.upsert({
          where: {
            projectId_costAccountId_month_version: {
              projectId,
              costAccountId: item.costAccountId,
              month: item.month,
              version: 1,
            },
          },
          create: {
            projectId,
            costAccountId: item.costAccountId,
            month: item.month,
            amount: BigInt(item.amount),
            createdById: user.id,
          },
          update: { amount: BigInt(item.amount) },
        });
      }

      return jsonOk({ count: items.length }, 201);
    }

    const parsed = monthlyCostSchema.parse(body);

    const project = await prisma.allocationProject.findUniqueOrThrow({
      where: { id: parsed.projectId },
    });
    if (project.status !== "DRAFT" && project.status !== "COST_CONFIRMED") {
      throw new Error("마감된 프로젝트의 원가는 수정할 수 없습니다.");
    }

    const cost = await prisma.monthlyCost.upsert({
      where: {
        projectId_costAccountId_month_version: {
          projectId: parsed.projectId,
          costAccountId: parsed.costAccountId,
          month: parsed.month,
          version: 1,
        },
      },
      create: {
        ...parsed,
        amount: BigInt(parsed.amount),
        createdById: user.id,
      },
      update: {
        amount: BigInt(parsed.amount),
      },
      include: { costAccount: true },
    });

    return jsonOk(serializeBigInt(cost), 201);
  } catch (error) {
    return handleApiError(error);
  }
}

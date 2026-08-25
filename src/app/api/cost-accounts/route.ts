import { NextRequest } from "next/server";
import prisma from "@/lib/db";
import { getSessionUser } from "@/lib/auth";
import { jsonOk, handleApiError, serializeBigInt } from "@/lib/api-utils";
import { costAccountSchema } from "@/lib/validations";
import { createAuditLog } from "@/lib/audit";
import {
  generateCostAccountCode,
  syncCostAccountToActiveProjects,
} from "@/lib/services/master-data-service";

export async function GET() {
  try {
    const accounts = await prisma.costAccount.findMany({
      where: { isActive: true, deletedAt: null },
      orderBy: { sortOrder: "asc" },
    });
    return jsonOk(serializeBigInt(accounts));
  } catch (error) {
    return handleApiError(error);
  }
}

export async function POST(request: NextRequest) {
  try {
    const user = await getSessionUser(request);
    if (!user) return handleApiError(new Error("FORBIDDEN"));

    const raw = await request.json();
    const parsed = costAccountSchema.parse({
      ...raw,
      code: raw.code || undefined,
    });

    const code = parsed.code || (await generateCostAccountCode());
    const maxSort = await prisma.costAccount.aggregate({
      _max: { sortOrder: true },
    });

    const account = await prisma.costAccount.create({
      data: {
        code,
        nameKo: parsed.nameKo,
        nameEn: parsed.nameEn,
        description: parsed.description,
        sortOrder: parsed.sortOrder ?? (maxSort._max.sortOrder ?? 0) + 1,
      },
    });

    await syncCostAccountToActiveProjects(account.id, user.id);

    await createAuditLog({
      userId: user.id,
      action: "CREATE",
      entityType: "CostAccount",
      entityId: account.id,
      afterData: account,
    });

    return jsonOk(serializeBigInt(account), 201);
  } catch (error) {
    return handleApiError(error);
  }
}

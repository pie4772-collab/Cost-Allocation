import { NextRequest } from "next/server";
import prisma from "@/lib/db";
import { getSessionUser } from "@/lib/auth";
import { jsonOk, handleApiError, serializeBigInt } from "@/lib/api-utils";

export async function GET() {
  try {
    const periods = await prisma.accountingPeriod.findMany({
      orderBy: [{ year: "desc" }, { cadence: "desc" }, { periodKey: "desc" }],
    });
    return jsonOk(serializeBigInt(periods));
  } catch (error) {
    return handleApiError(error);
  }
}

export async function POST(request: NextRequest) {
  try {
    const user = await getSessionUser(request);
    if (!user) return handleApiError(new Error("FORBIDDEN"));

    const body = await request.json();
    const period = await prisma.accountingPeriod.create({ data: body });
    return jsonOk(serializeBigInt(period), 201);
  } catch (error) {
    return handleApiError(error);
  }
}

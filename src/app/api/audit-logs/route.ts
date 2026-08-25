import { NextRequest } from "next/server";
import { getAuditLogs } from "@/lib/audit";
import { jsonOk, handleApiError, serializeBigInt } from "@/lib/api-utils";

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const result = await getAuditLogs({
      entityType: searchParams.get("entityType") ?? undefined,
      entityId: searchParams.get("entityId") ?? undefined,
      userId: searchParams.get("userId") ?? undefined,
      limit: parseInt(searchParams.get("limit") ?? "50"),
      offset: parseInt(searchParams.get("offset") ?? "0"),
    });
    return jsonOk(serializeBigInt(result));
  } catch (error) {
    return handleApiError(error);
  }
}

import { NextRequest } from "next/server";
import { getSessionUser } from "@/lib/auth";
import { jsonOk, handleApiError, serializeBigInt } from "@/lib/api-utils";
import { reconcileRun, cancelReconciliation } from "@/lib/services/allocation-service";

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const user = await getSessionUser(request);
    if (!user) return handleApiError(new Error("FORBIDDEN"));

    const { id } = await params;
    const result = await reconcileRun(id, user.id);
    return jsonOk(serializeBigInt(result));
  } catch (error) {
    return handleApiError(error);
  }
}

export async function DELETE(
  _request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const user = await getSessionUser(_request);
    if (!user) return handleApiError(new Error("FORBIDDEN"));

    const { id } = await params;
    const result = await cancelReconciliation(id, user.id);
    return jsonOk(serializeBigInt(result));
  } catch (error) {
    return handleApiError(error);
  }
}

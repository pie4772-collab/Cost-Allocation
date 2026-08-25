import { NextRequest } from "next/server";
import { getSessionUser } from "@/lib/auth";
import { jsonOk, handleApiError, serializeBigInt } from "@/lib/api-utils";
import { issueInvoice } from "@/lib/services/allocation-service";

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const user = await getSessionUser(request);
    if (!user) return handleApiError(new Error("FORBIDDEN"));

    const { id } = await params;
    const invoice = await issueInvoice(id, user.id);
    return jsonOk(serializeBigInt(invoice));
  } catch (error) {
    return handleApiError(error);
  }
}

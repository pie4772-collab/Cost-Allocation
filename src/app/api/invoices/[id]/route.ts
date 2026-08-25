import { NextRequest } from "next/server";
import { getSessionUser } from "@/lib/auth";
import { jsonOk, handleApiError, serializeBigInt } from "@/lib/api-utils";
import { getInvoiceFormData } from "@/lib/services/invoice-form-service";

export async function GET(
  _request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const user = await getSessionUser(_request);
    if (!user) return handleApiError(new Error("FORBIDDEN"));

    const { id } = await params;
    const data = await getInvoiceFormData(id);
    return jsonOk(serializeBigInt(data));
  } catch (error) {
    return handleApiError(error);
  }
}

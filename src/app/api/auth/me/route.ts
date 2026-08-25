import { NextRequest } from "next/server";
import { getSessionUser } from "@/lib/auth";
import { jsonOk, handleApiError } from "@/lib/api-utils";

export async function GET(request: NextRequest) {
  try {
    const user = await getSessionUser(request);
    if (!user) return jsonOk(null);
    return jsonOk({
      id: user.id,
      email: user.email,
      name: user.name,
      roles: user.roles,
    });
  } catch (error) {
    return handleApiError(error);
  }
}

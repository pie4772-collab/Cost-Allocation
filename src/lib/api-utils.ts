import { NextResponse } from "next/server";
import { ZodError } from "zod";

export function jsonOk<T>(data: T, status = 200) {
  return NextResponse.json(data, {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

export function jsonError(message: string, status = 400, details?: unknown) {
  return NextResponse.json({ error: message, details }, { status });
}

export function handleApiError(error: unknown) {
  if (error instanceof ZodError) {
    return jsonError(error.issues[0]?.message ?? "입력값이 올바르지 않습니다.", 400);
  }
  if (error instanceof Error) {
    if (error.message === "FORBIDDEN") {
      return jsonError("권한이 없습니다. 다시 로그인해주세요.", 403);
    }
    if (error.message === "NOT_FOUND") {
      return jsonError("리소스를 찾을 수 없습니다.", 404);
    }
    return jsonError(error.message, 400);
  }
  return jsonError("서버 오류가 발생했습니다.", 500);
}

export function serializeBigInt<T>(obj: T): T {
  return JSON.parse(
    JSON.stringify(obj, (_, value) =>
      typeof value === "bigint" ? value.toString() : value
    )
  );
}

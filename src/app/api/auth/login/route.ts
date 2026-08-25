import { NextRequest } from "next/server";
import bcrypt from "bcryptjs";
import prisma from "@/lib/db";
import { jsonOk, handleApiError } from "@/lib/api-utils";
import {
  createSessionToken,
  sessionCookieOptions,
  SESSION_COOKIE,
} from "@/lib/session";
import { z } from "zod";

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

export async function POST(request: NextRequest) {
  try {
    const { email, password } = loginSchema.parse(await request.json());
    const normalizedEmail = email.toLowerCase();

    const user = await prisma.user.findFirst({
      where: {
        email: normalizedEmail,
        isActive: true,
        deletedAt: null,
      },
    });

    if (!user?.passwordHash) {
      return handleApiError(new Error("이메일 또는 비밀번호가 올바르지 않습니다."));
    }

    const valid = await bcrypt.compare(password, user.passwordHash);
    if (!valid) {
      return handleApiError(new Error("이메일 또는 비밀번호가 올바르지 않습니다."));
    }

    const token = await createSessionToken({
      sub: user.id,
      email: user.email,
      name: user.name,
    });

    const secure = process.env.NODE_ENV === "production";
    const response = jsonOk({ email: user.email, name: user.name });
    response.cookies.set(SESSION_COOKIE, token, sessionCookieOptions(secure));
    return response;
  } catch (error) {
    return handleApiError(error);
  }
}

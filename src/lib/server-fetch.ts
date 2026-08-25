import { headers } from "next/headers";

/**
 * Server Component에서 API Route 호출 시 세션 쿠키를 전달합니다.
 */
export async function serverFetch(
  path: string,
  init?: RequestInit
): Promise<Response> {
  const headersList = await headers();
  const host = headersList.get("x-forwarded-host") ?? headersList.get("host");
  const proto = headersList.get("x-forwarded-proto") ?? "https";
  const baseUrl =
    process.env.NEXT_PUBLIC_APP_URL ??
    (host ? `${proto}://${host}` : "http://localhost:3000");
  const cookie = headersList.get("cookie");

  return fetch(`${baseUrl}${path.startsWith("/") ? path : `/${path}`}`, {
    ...init,
    cache: init?.cache ?? "no-store",
    headers: {
      ...init?.headers,
      ...(cookie ? { cookie } : {}),
    },
  });
}

export async function serverFetchJson<T = unknown>(
  path: string,
  init?: RequestInit
): Promise<T | null> {
  try {
    const res = await serverFetch(path, init);
    if (!res.ok) return null;
    const text = await res.text();
    if (text.startsWith("<!DOCTYPE") || text.startsWith("<html")) return null;
    return JSON.parse(text) as T;
  } catch {
    return null;
  }
}

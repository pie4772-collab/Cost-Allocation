/** 클라이언트 API fetch — 세션 쿠키 포함 */
export async function apiFetch(
  input: RequestInfo | URL,
  init?: RequestInit
): Promise<Response> {
  return fetch(input, {
    ...init,
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
      ...init?.headers,
    },
  });
}

export async function apiJson<T>(
  input: RequestInfo | URL,
  init?: RequestInit
): Promise<T> {
  const res = await apiFetch(input, init);
  const data = await res.json();
  if (!res.ok) {
    const message =
      res.status === 401 || res.status === 403
        ? "로그인이 필요합니다. /login 에서 다시 로그인해주세요."
        : (data as { error?: string }).error ?? "요청에 실패했습니다.";
    throw new Error(message);
  }
  return data as T;
}

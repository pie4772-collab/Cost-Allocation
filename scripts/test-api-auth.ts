#!/usr/bin/env tsx
/**
 * API 로그인 테스트 (자체 세션)
 * Usage: npx tsx --env-file=.env scripts/test-api-auth.ts [email] [password]
 */
const base = process.env.NEXT_PUBLIC_APP_URL ?? "http://localhost:3000";
const email = process.argv[2] ?? "admin@kbi.local";
const password = process.argv[3] ?? process.env.SEED_ADMIN_PASSWORD ?? "ChangeMe123!";

async function main() {
  console.log("=== API 로그인 테스트 ===");
  console.log("email:", email);
  console.log("base:", base);

  const loginRes = await fetch(`${base}/api/auth/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, password }),
  });
  console.log("POST /api/auth/login:", loginRes.status, await loginRes.text());
  if (!loginRes.ok) process.exit(1);

  const cookie = loginRes.headers.get("set-cookie") ?? "";

  const meRes = await fetch(`${base}/api/auth/me`, {
    headers: { Cookie: cookie },
  });
  console.log("GET /api/auth/me:", meRes.status, await meRes.text());

  const projectsRes = await fetch(`${base}/api/allocation-projects`, {
    headers: { Cookie: cookie },
  });
  console.log("GET /api/allocation-projects:", projectsRes.status);
}

main().catch((e) => {
  console.error("❌", e.message ?? e);
  process.exit(1);
});

import { test, expect } from "@playwright/test";

test("login page and sign in", async ({ page, context }) => {
  await context.clearCookies();
  await page.goto("http://localhost:3000/");
  await expect(page).toHaveURL(/\/login/);

  await page.fill('input[type="email"]', "admin@kbi.local");
  await page.fill('input[type="password"]', process.env.SEED_ADMIN_PASSWORD ?? "ChangeMe123!");
  await page.click('button[type="submit"]');

  await page.waitForURL("http://localhost:3000/", { timeout: 15000 });
  await expect(page.getByRole("heading", { name: "대시보드" })).toBeVisible();

  // projects SSR 페이지 (이전 JSON parse 오류 발생 지점)
  await page.goto("http://localhost:3000/projects");
  await expect(page.getByRole("heading", { name: "반기별 배부 프로젝트" })).toBeVisible();
  await expect(page.getByText("2026 상반기")).toBeVisible();

  const data = await page.evaluate(async () => {
    const res = await fetch("/api/dashboard");
    return { status: res.status, ok: res.ok };
  });
  expect(data.ok).toBeTruthy();
});

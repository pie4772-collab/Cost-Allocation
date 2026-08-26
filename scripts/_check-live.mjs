const base = "https://pie8405-cost-allocation.mycafe24.ai";
const res = await fetch(`${base}/api/auth/login`, {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({
    email: "admin@kbi.local",
    password: "ChangeMe123!",
  }),
});
const cookie = (res.headers.getSetCookie?.() ?? [])
  .map((c) => c.split(";")[0])
  .filter((c) => c.startsWith("kbi_session="))
  .join("; ");
const loginBody = await res.json().catch(() => ({}));
console.log("login", res.status, loginBody.email || loginBody.error || "");
if (!res.ok || !cookie) process.exit(1);

async function get(path) {
  const r = await fetch(`${base}${path}`, { headers: { cookie } });
  return { status: r.status, body: await r.json().catch(() => ({})) };
}
function n(body) {
  if (Array.isArray(body)) return body.length;
  if (body?.error) return "error:" + body.error;
  return body;
}
const companies = await get("/api/companies?active=false");
const projects = await get("/api/allocation-projects");
const invoices = await get("/api/invoices");
const accounts = await get("/api/cost-accounts");
const status = await get("/api/import-status");
const list = Array.isArray(companies.body) ? companies.body : [];
const plist = Array.isArray(projects.body) ? projects.body : [];
console.log("companies", companies.status, n(companies.body), "active", list.filter((c) => c.isActive).length);
console.log("projects", projects.status, n(projects.body));
console.log("invoices", invoices.status, n(invoices.body));
console.log("accounts", accounts.status, n(accounts.body));
console.log("import-status", status.status, JSON.stringify(status.body));
if (list[0]) console.log("first-company", list[0].code, list[0].nameKo);
if (plist[0]) {
  console.log("first-project", plist[0].name);
  const costs = await get(`/api/monthly-costs?projectId=${plist[0].id}`);
  console.log("costs", costs.status, n(costs.body));
}

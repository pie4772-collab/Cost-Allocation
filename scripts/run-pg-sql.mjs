import { createRequire } from "module";
import { spawn } from "child_process";
import fs from "fs";
import os from "os";
import path from "path";
import { fileURLToPath } from "url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const require = createRequire(import.meta.url);
const markerDir = process.env.IMPORT_MARKER_DIR || "/app/user_data";

export const PUBLIC_TABLES = [
  "invoice_lines",
  "invoices",
  "allocation_details",
  "company_allocation_summaries",
  "reconciliation_results",
  "approval_actions",
  "approval_requests",
  "allocation_runs",
  "allocation_rates",
  "allocation_rate_versions",
  "monthly_costs",
  "attachments",
  "audit_logs",
  "system_settings",
  "company_addresses",
  "user_roles",
  "allocation_projects",
  "companies",
  "cost_accounts",
  "accounting_periods",
  "users",
  "roles",
];

export function splitSqlStatements(sql) {
  return sql
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line && !line.startsWith("--"))
    .join("\n")
    .split(";")
    .map((stmt) => stmt.trim())
    .filter(Boolean);
}

function loadPg() {
  const candidates = ["pg", path.join(root, "node_modules", "pg")];
  let lastErr;
  for (const id of candidates) {
    try {
      return require(id);
    } catch (err) {
      lastErr = err;
    }
  }
  throw new Error("pg package not found: " + (lastErr?.message || ""));
}

export function writeImportLog(payload) {
  try {
    fs.mkdirSync(markerDir, { recursive: true });
    fs.writeFileSync(
      path.join(markerDir, "import-last.json"),
      JSON.stringify({ at: new Date().toISOString(), ...payload })
    );
  } catch (err) {
    console.error("import log write failed", err);
  }
}

export async function withPgClient(fn) {
  const { Client } = loadPg();
  const url = process.env.DATABASE_URL;
  if (!url) throw new Error("DATABASE_URL missing");
  const client = new Client({ connectionString: url });
  await client.connect();
  try {
    return await fn(client);
  } finally {
    await client.end();
  }
}

function runPrismaExecute(filePath) {
  const prismaCli = path.join(root, "node_modules", "prisma", "build", "index.js");
  const schemaPath = path.join(root, "prisma", "schema.prisma");
  return new Promise((resolve, reject) => {
    const child = spawn(
      process.execPath,
      [prismaCli, "db", "execute", "--file", filePath, "--schema", schemaPath],
      { cwd: root, stdio: ["ignore", "inherit", "inherit"], env: process.env }
    );
    child.on("error", reject);
    child.on("exit", (code) => {
      if (code === 0) resolve();
      else reject(new Error("prisma db execute exited " + code));
    });
  });
}

async function executeViaPrisma(statements) {
  const tmp = path.join(os.tmpdir(), `cost-allocation-sql-${process.pid}.sql`);
  fs.writeFileSync(
    tmp,
    statements.map((s) => (s.endsWith(";") ? s : s + ";")).join("\n") + "\n"
  );
  try {
    await runPrismaExecute(tmp);
  } finally {
    fs.rmSync(tmp, { force: true });
  }
}

export async function executeStatements(statements) {
  try {
    return await withPgClient(async (client) => {
      await client.query("BEGIN");
      try {
        for (const stmt of statements) {
          await client.query(stmt);
        }
        await client.query("COMMIT");
      } catch (err) {
        try {
          await client.query("ROLLBACK");
        } catch {
          // ignore rollback errors
        }
        throw err;
      }
    });
  } catch (err) {
    const msg = String(err?.message || err);
    if (!msg.includes("pg package not found")) throw err;
    console.log("run-pg-sql: pg missing, fallback prisma db execute");
    return executeViaPrisma(statements);
  }
}

export async function countPublic(table) {
  try {
    return await withPgClient(async (client) => {
      const result = await client.query(
        `SELECT COUNT(*)::int AS n FROM public.${table}`
      );
      return result.rows[0].n;
    });
  } catch (err) {
    if (!String(err?.message || err).includes("pg package not found")) throw err;
    const tmp = path.join(os.tmpdir(), `cost-allocation-count-${process.pid}.sql`);
    fs.writeFileSync(tmp, `SELECT COUNT(*) FROM public.${table};\n`);
    try {
      await runPrismaExecute(tmp);
      return -1;
    } finally {
      fs.rmSync(tmp, { force: true });
    }
  }
}

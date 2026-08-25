import { spawn } from "child_process";
import fs from "fs";
import os from "os";
import path from "path";
import { fileURLToPath } from "url";
import { PrismaClient } from "@prisma/client";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const dumpCandidates = [
  path.join(root, "scripts", "cafe24-import.sql"),
  path.join(root, "prisma", "cafe24-import.sql"),
  path.join(root, "prisma", "local-data.sql"),
];
const dumpModule = path.join(root, "scripts", "cafe24-import-data.mjs");
const partFiles = Array.from({ length: 10 }, (_, i) =>
  path.join(root, "scripts", `cafe24-import-p${String(i).padStart(2, "0")}.mjs`)
);
const file = dumpCandidates.find((candidate) => fs.existsSync(candidate));
const prismaCli = path.join(root, "node_modules", "prisma", "build", "index.js");
const schemaPath = path.join(root, "prisma", "schema.prisma");
const markerDir = process.env.IMPORT_MARKER_DIR || "/app/user_data";
const marker = path.join(markerDir, ".local-data-imported");
const TABLE_ORDER = [
  "roles",
  "users",
  "user_roles",
  "companies",
  "company_addresses",
  "accounting_periods",
  "cost_accounts",
  "allocation_projects",
  "monthly_costs",
  "allocation_rate_versions",
  "allocation_rates",
  "allocation_runs",
  "allocation_details",
  "company_allocation_summaries",
  "invoices",
  "invoice_lines",
  "approval_requests",
  "approval_actions",
  "reconciliation_results",
  "audit_logs",
  "system_settings",
  "attachments",
];

const prisma = new PrismaClient();

function runPrisma(args) {
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [prismaCli, ...args], {
      cwd: root,
      stdio: ["ignore", "inherit", "inherit"],
      env: process.env,
    });
    child.on("error", reject);
    child.on("exit", (code) => {
      if (code === 0) resolve();
      else reject(new Error(`prisma ${args.join(" ")} exited ${code}`));
    });
  });
}

async function main() {
  if (fs.existsSync(marker)) {
    try {
      const rows = await prisma.$queryRawUnsafe(
        'SELECT COUNT(*)::int AS n FROM public.companies'
      );
      if (Number(rows?.[0]?.n) > 0) {
        console.log("import-local-data: already imported, skip");
        return;
      }
      console.log("import-local-data: marker present but companies empty, re-import");
    } catch {
      console.log("import-local-data: marker present but companies table missing, re-import");
    }
  }
  if (!file && !partFiles.every((part) => fs.existsSync(part)) && !fs.existsSync(dumpModule)) {
    console.log("import-local-data: no dump file");
    return;
  }
  if (!fs.existsSync(prismaCli)) {
    throw new Error("prisma CLI is not installed");
  }
  let sql = "";
  const missingParts = partFiles.filter((part) => !fs.existsSync(part));
  if (missingParts.length === 0) {
    console.log("import-local-data: reading dump chunks as text");
    const b64 = partFiles
      .map((part) => {
        const text = fs.readFileSync(part, "utf8");
        const match = text.match(/export const p = "([^"]*)";/);
        if (!match) throw new Error(`invalid dump chunk ${path.basename(part)}`);
        return match[1];
      })
      .join("");
    sql = Buffer.from(b64, "base64").toString("utf8");
  } else if (file) {
    console.log(
      `import-local-data: missing ${missingParts.length} chunks, using ${path.relative(root, file)}`
    );
    sql = fs.readFileSync(file, "utf8");
  } else {
    throw new Error(
      `dump chunks missing: ${missingParts.map((part) => path.basename(part)).join(", ")}`
    );
  }
  const byTable = new Map();
  for (const line of sql.split(/\r?\n/)) {
    const match = line.match(/^INSERT INTO public\.([a-z_]+)/);
    if (!match) continue;
    const table = match[1];
    if (!byTable.has(table)) byTable.set(table, []);
    byTable.get(table).push(line.endsWith(";") ? line : `${line};`);
  }

  console.log("import-local-data: truncating public tables");
  await prisma.$executeRawUnsafe(`
    DO $$ DECLARE r RECORD;
    BEGIN
      FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public') LOOP
        EXECUTE 'TRUNCATE TABLE public.' || quote_ident(r.tablename) || ' CASCADE';
      END LOOP;
    END $$;
  `);

  const parts = ["SET client_encoding = 'UTF8';", "SET search_path = public;"];
  for (const table of TABLE_ORDER) {
    const rows = byTable.get(table) ?? [];
    if (rows.length === 0) continue;
    console.log(`import-local-data: ${table} (${rows.length})`);
    parts.push(...rows);
  }
  for (const table of byTable.keys()) {
    if (TABLE_ORDER.includes(table)) continue;
    const rows = byTable.get(table) ?? [];
    console.log(`import-local-data: extra table ${table} (${rows.length})`);
    parts.push(...rows);
  }

  const tmp = path.join(os.tmpdir(), `cost-allocation-import-${process.pid}.sql`);
  fs.writeFileSync(tmp, `${parts.join("\n")}\n`);
  console.log(`import-local-data: executing ${parts.length} SQL statements via prisma db execute`);
  try {
    await runPrisma(["db", "execute", "--file", tmp, "--schema", schemaPath]);
  } finally {
    fs.rmSync(tmp, { force: true });
  }

  try {
    fs.mkdirSync(markerDir, { recursive: true });
    fs.writeFileSync(marker, new Date().toISOString());
  } catch (err) {
    console.error("import-local-data: could not write marker", err);
  }
  console.log("import-local-data: done");
}

main()
  .catch((err) => {
    console.error("import-local-data: failed", err);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());

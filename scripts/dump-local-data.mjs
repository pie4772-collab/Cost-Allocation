import { spawnSync } from "child_process";
import fs from "fs";

const envText = fs.readFileSync(".env", "utf8");
const env = {};
for (const line of envText.split(/\r?\n/)) {
  if (!line || line.startsWith("#") || !line.includes("=")) continue;
  const i = line.indexOf("=");
  const key = line.slice(0, i).trim();
  let value = line.slice(i + 1).trim();
  if (
    (value.startsWith('"') && value.endsWith('"')) ||
    (value.startsWith("'") && value.endsWith("'"))
  ) {
    value = value.slice(1, -1);
  }
  env[key] = value;
}

const url = (env.DATABASE_URL ?? "").replace(/\?.*$/, "");
if (!url) {
  console.error("DATABASE_URL missing");
  process.exit(1);
}

const pgDump = "C:\\Program Files\\PostgreSQL\\18\\bin\\pg_dump.exe";
const result = spawnSync(
  pgDump,
  [url, "--data-only", "--no-owner", "--no-acl", "--column-inserts"],
  { encoding: "utf8", maxBuffer: 80 * 1024 * 1024 }
);

if (result.status !== 0) {
  console.error("pg_dump failed", result.status);
  process.exit(result.status ?? 1);
}

const cleaned = result.stdout
  .split(/\r?\n/)
  .filter((line) => {
    const t = line.trim();
    if (t.startsWith("\\")) return false;
    if (t.startsWith("SET transaction_timeout")) return false;
    if (t.includes("set_config('search_path'")) return false;
    if (t.startsWith("SET search_path")) return false;
    return true;
  })
  .join("\n");

const preamble = `SET client_encoding = 'UTF8';
SET search_path = public;

DO $$ DECLARE r RECORD;
BEGIN
  FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public') LOOP
    EXECUTE 'TRUNCATE TABLE public.' || quote_ident(r.tablename) || ' CASCADE';
  END LOOP;
END $$;

`;

fs.writeFileSync("prisma/local-data.sql", preamble + cleaned);
console.log("wrote prisma/local-data.sql bytes=" + fs.statSync("prisma/local-data.sql").size);

import { spawn } from "child_process";
import { randomBytes } from "crypto";
import { existsSync } from "fs";
import path from "path";
import { fileURLToPath } from "url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const nextBin = path.join(root, "node_modules", "next", "dist", "bin", "next");
const prismaCli = path.join(root, "node_modules", "prisma", "build", "index.js");
const port = process.env.PORT || "3000";

function resolveDatabaseUrl() {
  if (process.env.DATABASE_URL) return process.env.DATABASE_URL;
  const host = process.env.DB_HOST;
  const name = process.env.DB_NAME;
  const user = process.env.DB_USER;
  const password = process.env.DB_PASSWORD ?? "";
  if (!host || !name || !user) {
    throw new Error("DATABASE_URL 또는 DB_HOST / DB_NAME / DB_USER 가 필요합니다.");
  }
  const dbPort = process.env.DB_PORT ?? "5432";
  return `postgresql://${encodeURIComponent(user)}:${encodeURIComponent(password)}@${host}:${dbPort}/${name}?schema=public`;
}

process.env.CI = "true";
process.env.DATABASE_URL = resolveDatabaseUrl();
if (!process.env.SESSION_SECRET || process.env.SESSION_SECRET.length < 16) {
  process.env.SESSION_SECRET = randomBytes(32).toString("base64");
}

function run(bin, args) {
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [bin, ...args], {
      cwd: root,
      stdio: ["ignore", "inherit", "inherit"],
      env: process.env,
    });
    child.on("error", reject);
    child.on("exit", (code) => {
      if (code === 0) resolve();
      else reject(new Error(`${path.basename(bin)} exited ${code}`));
    });
  });
}

if (existsSync(prismaCli)) {
  console.log("startup: applying database schema");
  await run(prismaCli, ["db", "push", "--skip-generate", "--accept-data-loss"]);
}

if (!existsSync(nextBin)) {
  console.error("next is not installed. Run npm install.");
  process.exit(1);
}

const dumpModule = path.join(root, "scripts", "cafe24-import-data.mjs");
const partFiles = Array.from({ length: 10 }, (_, i) =>
  path.join(
    root,
    "scripts",
    `cafe24-import-p${String(i).padStart(2, "0")}.mjs`
  )
);
const dataSql =
  [
    path.join(root, "scripts", "cafe24-import.sql"),
    path.join(root, "prisma", "cafe24-import.sql"),
    path.join(root, "prisma", "local-data.sql"),
  ].find((candidate) => existsSync(candidate)) ?? "";
const importScript = path.join(root, "scripts", "import-local-data.mjs");
const importMarker = path.join(
  process.env.IMPORT_MARKER_DIR || "/app/user_data",
  ".local-data-imported"
);
const hasDump =
  Boolean(dataSql) ||
  existsSync(dumpModule) ||
  partFiles.some((part) => existsSync(part));
process.env.IMPORT_DUMP_FOUND = hasDump ? "1" : "0";
process.env.IMPORT_DUMP_NAME = existsSync(dumpModule)
  ? "cafe24-import-data.mjs"
  : dataSql
    ? path.basename(dataSql)
    : partFiles.filter((part) => existsSync(part)).length
      ? `parts:${partFiles.filter((part) => existsSync(part)).length}`
      : "";
process.env.IMPORT_MARKER_FOUND = existsSync(importMarker) ? "1" : "0";

const child = spawn(
  process.execPath,
  [nextBin, "start", "--hostname", "0.0.0.0", "--port", port],
  { cwd: root, stdio: "inherit", env: process.env }
);
const nextExit = new Promise((resolve) => {
  child.on("exit", (code) => resolve(code ?? 1));
});

if (
  process.env.IMPORT_LOCAL_DATA === "true" &&
  hasDump &&
  existsSync(importScript)
) {
  console.log("startup: importing local settlement data");
  try {
    await run(process.execPath, [importScript]);
    console.log("startup: import complete");
  } catch (err) {
    console.error("startup: import failed", err);
  }
} else if (existsSync(importMarker)) {
  console.log("startup: local data already imported");
}

process.exit(await nextExit);

import { spawn } from "child_process";
import { randomBytes } from "crypto";
import { existsSync, readdirSync, readFileSync } from "fs";
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
    const chunks = [];
    const child = spawn(process.execPath, [bin, ...args], {
      cwd: root,
      env: process.env,
    });
    child.stdout.on("data", (d) => {
      chunks.push(d);
      process.stdout.write(d);
    });
    child.stderr.on("data", (d) => {
      chunks.push(d);
      process.stderr.write(d);
    });
    child.on("error", reject);
    child.on("exit", (code) => {
      const out = Buffer.concat(chunks).toString("utf8").replace(/\s+/g, " ").slice(-400);
      if (code === 0) resolve(out);
      else reject(new Error(out || `${path.basename(bin)} exited ${code}`));
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

const importScript = path.join(root, "scripts", "import-local-data.mjs");
const importMarker = path.join(
  process.env.IMPORT_MARKER_DIR || "/app/user_data",
  ".core-import-v3"
);
const chunkScript = path.join(root, "scripts", "import-chunks.mjs");
const scriptsDir = path.join(root, "scripts");
const chunkFileCount = existsSync(scriptsDir)
  ? readdirSync(scriptsDir).filter((name) => /^import-chunk-\d+\.mjs$/.test(name))
      .length
  : 0;

process.env.IMPORT_DUMP_FOUND = existsSync(importScript) ? "1" : "0";
process.env.IMPORT_DUMP_NAME = "embedded-core";
process.env.IMPORT_STATE = `chunkFiles=${chunkFileCount}`;
console.log(
  "startup: import script",
  existsSync(importScript) ? "present" : "MISSING",
  "marker",
  existsSync(importMarker) ? "present" : "absent",
  "chunkFiles",
  chunkFileCount
);

if (process.env.IMPORT_LOCAL_DATA === "true") {
  if (!existsSync(importScript)) {
    console.error("startup: import script missing at", importScript);
    process.env.IMPORT_STATE += ";core=missing-script";
  } else {
    console.log("startup: importing core settlement data before next start");
    try {
      await run(importScript, []);
      console.log("startup: core import complete");
      process.env.IMPORT_STATE += ";core=ok";
    } catch (err) {
      console.error("startup: core import failed", err);
      process.env.IMPORT_STATE += `;core=fail:${String(err?.message || err).slice(0, 180)}`;
    }
  }
}

process.env.IMPORT_MARKER_FOUND = existsSync(importMarker) ? "1" : "0";
try {
  const logPath = path.join(
    process.env.IMPORT_MARKER_DIR || "/app/user_data",
    "import-last.json"
  );
  if (existsSync(logPath)) {
    process.env.IMPORT_STATE += ";" + readFileSync(logPath, "utf8").slice(0, 300);
  }
} catch {
  // ignore
}

const child = spawn(
  process.execPath,
  [nextBin, "start", "--hostname", "0.0.0.0", "--port", port],
  { cwd: root, stdio: "inherit", env: process.env }
);

if (
  process.env.IMPORT_LOCAL_DATA === "true" &&
  existsSync(chunkScript) &&
  existsSync(importMarker)
) {
  console.log("startup: importing remaining settlement chunks in background");
  run(chunkScript, [])
    .then(() => console.log("startup: chunk import complete"))
    .catch((err) => console.error("startup: chunk import failed", err));
}

process.exit(await new Promise((resolve) => {
  child.on("exit", (code) => resolve(code ?? 1));
}));

import fs from "fs";
import path from "path";
import { pathToFileURL } from "url";
import { fileURLToPath } from "url";
import {
  splitSqlStatements,
  executeStatements,
  writeImportLog,
} from "./run-pg-sql.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const scriptsDir = path.join(root, "scripts");
const markerDir = process.env.IMPORT_MARKER_DIR || "/app/user_data";
const coreMarker = path.join(markerDir, ".core-import-v3");

if (!fs.existsSync(coreMarker)) {
  writeImportLog({ step: "chunks", skipped: true, reason: "core-marker-missing" });
  console.log("import-chunks: core marker missing, skip remaining tables");
  process.exit(0);
}

const files = fs
  .readdirSync(scriptsDir)
  .filter((name) => /^import-chunk-\d+\.mjs$/.test(name))
  .sort();

if (files.length === 0) {
  writeImportLog({ step: "chunks", skipped: true, reason: "no-chunk-files" });
  console.log("import-chunks: no chunk files");
  process.exit(0);
}

fs.mkdirSync(markerDir, { recursive: true });

let done = 0;
let skipped = 0;
for (const name of files) {
  const href = pathToFileURL(path.join(scriptsDir, name)).href;
  const mod = await import(href);
  const chunkId = String(mod.CHUNK_ID || name);
  const marker = path.join(markerDir, `.import-chunk-${chunkId}`);
  if (fs.existsSync(marker)) {
    console.log("import-chunks: skip", chunkId);
    skipped += 1;
    continue;
  }
  const sql = Buffer.from(String(mod.SQL_B64 || ""), "base64").toString("utf8");
  const statements = [
    "SET client_encoding = 'UTF8'",
    "SET search_path = public",
    ...splitSqlStatements(sql),
  ];
  console.log("import-chunks: executing", chunkId, statements.length - 2, "statements");
  try {
    await executeStatements(statements);
  } catch (err) {
    writeImportLog({
      step: "chunks",
      ok: false,
      chunkId,
      error: String(err?.message || err).slice(0, 400),
      done,
      skipped,
      files: files.length,
    });
    throw err;
  }
  fs.writeFileSync(marker, new Date().toISOString());
  done += 1;
  console.log("import-chunks: done", chunkId);
}

writeImportLog({
  step: "chunks",
  ok: true,
  done,
  skipped,
  files: files.length,
});
console.log("import-chunks: all pending chunks complete");

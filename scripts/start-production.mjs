import { spawn } from "node:child_process";
import { randomBytes } from "node:crypto";

function resolveDatabaseUrl() {
  if (process.env.DATABASE_URL) return process.env.DATABASE_URL;
  const host = process.env.DB_HOST;
  const name = process.env.DB_NAME;
  const user = process.env.DB_USER;
  const password = process.env.DB_PASSWORD ?? "";
  if (!host || !name || !user) {
    throw new Error(
      "DATABASE_URL 또는 DB_HOST / DB_NAME / DB_USER 환경변수가 필요합니다."
    );
  }
  const port = process.env.DB_PORT ?? "5432";
  return `postgresql://${encodeURIComponent(user)}:${encodeURIComponent(password)}@${host}:${port}/${name}?schema=public`;
}

process.env.DATABASE_URL = resolveDatabaseUrl();
if (!process.env.SESSION_SECRET || process.env.SESSION_SECRET.length < 16) {
  process.env.SESSION_SECRET = randomBytes(32).toString("base64");
}

function run(command, args) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      stdio: "inherit",
      env: process.env,
      shell: process.platform === "win32",
    });
    child.on("exit", (code) => {
      if (code === 0) resolve();
      else reject(new Error(`${command} ${args.join(" ")} exited ${code}`));
    });
  });
}

await run("npx", ["prisma", "db", "push"]);
if (process.env.SEED_ON_BOOT === "true") {
  await run("npx", ["tsx", "prisma/seed.ts"]);
}
await run("npx", ["next", "start", "--hostname", "0.0.0.0", "--port", "3000"]);

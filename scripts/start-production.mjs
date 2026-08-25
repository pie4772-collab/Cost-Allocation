import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const nextBin = path.join(root, "node_modules", "next", "dist", "bin", "next");
const port = process.env.PORT || "3000";

if (!existsSync(nextBin)) {
  console.error("next is not installed. Run npm install.");
  process.exit(1);
}

const child = spawn(
  process.execPath,
  [nextBin, "start", "--hostname", "0.0.0.0", "--port", port],
  { cwd: root, stdio: "inherit" }
);

child.on("exit", (code) => {
  process.exit(code ?? 1);
});

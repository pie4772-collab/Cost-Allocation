export async function register() {
  if (process.env.NEXT_RUNTIME !== "nodejs") return;
  setTimeout(() => {
    import("./lib/runtime-init")
      .then((mod) => mod.initSchemaAndAdmin())
      .catch((err) => {
        console.error("runtime-init failed", err);
      });
  }, 1500);
}

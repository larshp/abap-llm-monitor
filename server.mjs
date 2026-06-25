import express from "express";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { initializeABAP } from "./output/init.mjs";
import { cl_express_icf_shim } from "./output/cl_express_icf_shim.clas.mjs";
import { zcl_env_config } from "./output/zcl_env_config.clas.mjs";
import { zcl_icf_handler } from "./output/zcl_icf_handler.clas.mjs";
import { getCodexUsage } from "./codex.mjs";
import { getCopilotQuota } from "./copilot.mjs";
import { getClaudeQuota } from "./claude.mjs";

globalThis.getCodexUsage = getCodexUsage;
globalThis.getCopilotQuota = getCopilotQuota;
globalThis.getClaudeQuota = getClaudeQuota;

const host = process.env.HOST || "127.0.0.1";
const port = Number(process.env.PORT || 3050);
const publicDir = join(dirname(fileURLToPath(import.meta.url)), "frontend");
export const serverUrl = `http://${host}:${port}`;

await initializeABAP();
zcl_env_config.openrouter_api_key.set(process.env.OPENROUTER_API_KEY || "");

const app = express();
app.disable("x-powered-by");
app.set("etag", false);

app.all(["/metrics", "/metrics.json"], express.raw({ type: "*/*" }), async (request, response) => {
  await cl_express_icf_shim.run({
    req: request,
    res: response,
    class: "ZCL_ICF_HANDLER",
  });
});

app.use(express.static(publicDir, {
  etag: false,
  fallthrough: true,
  index: "index.html",
  maxAge: 0,
  setHeaders(response) {
    response.setHeader("Cache-Control", "no-cache");
  },
}));

app.use((request, response) => {
  if (request.method !== "GET" && request.method !== "HEAD") {
    response.status(405).set("Allow", "GET, HEAD").type("text/plain").send("Method Not Allowed");
    return;
  }

  response.status(404).type("text/plain").send("Not Found");
});

export let server;
export const serverReady = new Promise((resolve) => {
  server = app.listen(port, host, () => {
    console.log(`Metrics REST service listening at http://${host}:${port}/metrics.json`);
    console.log(`Serving static files from ${publicDir}`);
    console.log(`Frontend available at ${serverUrl}`);
    resolve(server);
  });
});

process.on("SIGINT", () => server.close(() => process.exit(0)));
process.on("SIGTERM", () => server.close(() => process.exit(0)));

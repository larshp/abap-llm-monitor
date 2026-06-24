import express from "express";
import { initializeABAP } from "./output/init.mjs";
import { cl_express_icf_shim } from "./output/cl_express_icf_shim.clas.mjs";
import { zcl_env_config } from "./output/zcl_env_config.clas.mjs";
import { zcl_icf_handler } from "./output/zcl_icf_handler.clas.mjs";

const host = process.env.HOST || "127.0.0.1";
const port = Number(process.env.PORT || 3050);

await initializeABAP();
zcl_env_config.codex_access_token.set(process.env.CODEX_ACCESS_TOKEN || process.env.CODEX_API_KEY || "");
zcl_env_config.codex_account_id.set(process.env.CODEX_ACCOUNT_ID || process.env.CHATGPT_ACCOUNT_ID || "");
zcl_env_config.codex_plan.set(process.env.CODEX_PLAN || process.env.CHATGPT_PLAN || "");
zcl_env_config.codex_usage_url.set(process.env.CODEX_USAGE_URL || "https://chatgpt.com/backend-api/wham/usage");
zcl_env_config.openrouter_api_key.set(process.env.OPENROUTER_API_KEY || "");

const app = express();
app.disable("x-powered-by");
app.set("etag", false);
app.use(express.raw({ type: "*/*" }));

app.all(["/metrics", "/metrics.json"], async (request, response) => {
  await cl_express_icf_shim.run({
    req: request,
    res: response,
    class: "ZCL_ICF_HANDLER",
  });
});

app.use((request, response) => {
  response.status(404).type("application/json").send('{"error":"not found"}');
});

const server = app.listen(port, host, () => {
  console.log(`Metrics REST service listening at http://${host}:${port}/metrics.json`);
});

process.on("SIGINT", () => server.close(() => process.exit(0)));
process.on("SIGTERM", () => server.close(() => process.exit(0)));

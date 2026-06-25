import { getCodexQuota } from "./codex.mjs";

try {
  const quota = await getCodexQuota();
  console.log(JSON.stringify(quota, null, 2));
} catch (error) {
  console.error(error instanceof Error ? error.stack : String(error));
  process.exitCode = 1;
}
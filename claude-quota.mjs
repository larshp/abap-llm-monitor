import { getClaudeQuota } from "./claude.mjs";

try {
  const quota = await getClaudeQuota();
  console.log(JSON.stringify(quota, null, 2));
} catch (error) {
  console.error(error instanceof Error ? error.stack : String(error));
  process.exitCode = 1;
}
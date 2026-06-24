import { CopilotClient } from "@github/copilot-sdk";
import { pathToFileURL } from "node:url";

export async function getCopilotQuota() {
  const client = new CopilotClient();
  await client.start();

  try {
    const accountRpc = client.rpc.account;
    const getQuota = accountRpc.get_quota || accountRpc.getQuota;

    if (typeof getQuota !== "function") {
      throw new Error(`Copilot SDK account RPC does not expose get_quota. Available methods: ${Object.keys(accountRpc).join(", ")}`);
    }

    return await getQuota.call(accountRpc, {});
  } finally {
    const stopErrors = await client.stop();
    if (stopErrors.length > 0) {
      console.dir(stopErrors, { depth: null });
      throw new AggregateError(stopErrors, "Failed to stop Copilot SDK client");
    }
  }
}
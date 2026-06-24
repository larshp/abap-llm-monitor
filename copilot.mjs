import { CopilotClient, RuntimeConnection } from "@github/copilot-sdk";
import { fileURLToPath } from "node:url";

function getPlatformPackageName() {
  const variants = process.platform === "linux" ? ["linux", "linuxmusl"] : [process.platform];

  return variants.map((variant) => `@github/copilot-${variant}-${process.arch}`);
}

function resolveElectronCliPath() {
  if (!process.versions.electron) {
    return undefined;
  }

  for (const packageName of getPlatformPackageName()) {
    try {
      return fileURLToPath(import.meta.resolve(packageName));
    } catch {
      // Try the next platform package variant.
    }
  }

  return undefined;
}

export async function getCopilotQuota() {
  const cliPath = resolveElectronCliPath();
  const client = new CopilotClient(cliPath ? {
    connection: RuntimeConnection.forTcp({ path: cliPath }),
  } : undefined);
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
import { join } from "node:path";
import { homedir } from "node:os";
import { readFile } from "node:fs/promises";

const TOKEN_REFRESH_INTERVAL_MS = 8 * 24 * 60 * 60 * 1000;
const REFRESH_URL = "https://auth.openai.com/oauth/token";
const REFRESH_CLIENT_ID = "app_hmmtodo";

function getCodexAuthPath() {
  const codexHome = process.env.CODEX_HOME;
  return codexHome ? join(codexHome, "auth.json") : join(homedir(), ".codex", "auth.json");
}

function parseIsoDate(value) {
  if (typeof value !== "string" || !value) return null;
  const parsed = Date.parse(value);
  return Number.isNaN(parsed) ? null : parsed;
}

function shouldRefresh(lastRefreshIso) {
  const lastRefresh = parseIsoDate(lastRefreshIso);
  if (!lastRefresh) return true;
  return (Date.now() - lastRefresh) > TOKEN_REFRESH_INTERVAL_MS;
}

async function loadCodexAuthJson() {
  try {
    const authPath = getCodexAuthPath();
    const raw = await readFile(authPath, "utf8");
    const parsed = JSON.parse(raw);
    return { authPath, parsed };
  } catch {
    return null;
  }
}

async function refreshCodexTokens(refreshToken) {
  const response = await fetch(REFRESH_URL, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      accept: "application/json",
    },
    body: JSON.stringify({
      client_id: REFRESH_CLIENT_ID,
      grant_type: "refresh_token",
      refresh_token: refreshToken,
      scope: "openid profile email",
    }),
  });

  if (!response.ok) {
    return null;
  }

  const json = await response.json();
  const accessToken = typeof json.access_token === "string" ? json.access_token : "";
  if (!accessToken) {
    return null;
  }

  return {
    accessToken,
    refreshToken: typeof json.refresh_token === "string" && json.refresh_token ? json.refresh_token : refreshToken,
    idToken: typeof json.id_token === "string" ? json.id_token : null,
  };
}

export async function resolveCodexCredentials() {
  const configuredAccessToken = process.env.CODEX_ACCESS_TOKEN || "";
  const configuredApiKey = process.env.CODEX_API_KEY || "";
  const configuredAccountId = process.env.CODEX_ACCOUNT_ID || process.env.CHATGPT_ACCOUNT_ID || "";

  if (configuredAccessToken) {
    console.log("Using CODEX_ACCESS_TOKEN from environment");
    return {
      accessToken: configuredAccessToken,
      accountId: configuredAccountId,
    };
  }

  const auth = await loadCodexAuthJson();
  if (!auth) {
    console.log("No auth.json found; using configured API key if available");
    return {
      accessToken: configuredApiKey,
      accountId: configuredAccountId,
    };
  }

  const authApiKey = typeof auth.parsed.OPENAI_API_KEY === "string" ? auth.parsed.OPENAI_API_KEY : "";
  const tokens = auth.parsed.tokens && typeof auth.parsed.tokens === "object" ? auth.parsed.tokens : {};
  let accessToken = typeof tokens.access_token === "string" ? tokens.access_token : "";
  const refreshToken = typeof tokens.refresh_token === "string" ? tokens.refresh_token : "";
  const accountIdFromAuth = typeof tokens.account_id === "string" ? tokens.account_id : "";

  // If API key auth is configured, prefer a matching auth.json token set when available.
  const canUseAuthTokens = !configuredApiKey || !authApiKey || configuredApiKey === authApiKey;
  if (canUseAuthTokens && refreshToken && shouldRefresh(auth.parsed.last_refresh)) {
    console.log("Refreshing Codex access token using refresh token from auth.json");
    const refreshed = await refreshCodexTokens(refreshToken);
    if (refreshed) {
      accessToken = refreshed.accessToken;

      const updated = {
        ...auth.parsed,
        tokens: {
          ...(tokens || {}),
          access_token: refreshed.accessToken,
          refresh_token: refreshed.refreshToken,
          ...(refreshed.idToken ? { id_token: refreshed.idToken } : {}),
        },
        last_refresh: new Date().toISOString(),
      };

      console.dir(updated, { depth: null, colors: true });
      throw new Error("Token refresh persistence is disabled for now; uncomment writeFile to enable");
    }
  }

  return {
    accessToken: accessToken || configuredApiKey,
    accountId: configuredAccountId || accountIdFromAuth,
  };
}

import { Codex } from "@openai/codex-sdk";
import { spawn } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const codexCliPath = join(
  dirname(fileURLToPath(import.meta.url)),
  "node_modules",
  "@openai",
  "codex",
  "bin",
  "codex.js",
);

const emptyWindow = {
  has_data: false,
  remaining_percent: 0,
  reset: "",
  window: "",
};

function normalizeWindow(window) {
  if (!window || typeof window !== "object") return { ...emptyWindow };

  return {
    has_data: Boolean(window.has_data),
    remaining_percent: Math.max(0, Math.min(100, Number(window.remaining_percent) || 0)),
    reset: typeof window.reset === "string" ? window.reset : "",
    window: typeof window.window === "string" ? window.window : "",
  };
}

function normalizeUsage(usage) {
  return {
    primary: normalizeWindow(usage?.primary),
    secondary: normalizeWindow(usage?.secondary),
    error: typeof usage?.error === "string" ? usage.error : "",
  };
}

function formatReset(value) {
  if (!Number.isFinite(Number(value)) || Number(value) <= 0) return "";

  const timestamp = Number(value);
  const millis = timestamp < 1_000_000_000_000 ? timestamp * 1000 : timestamp;
  return new Date(millis).toLocaleString();
}

function formatWindowDuration(minutes) {
  if (!Number.isFinite(Number(minutes)) || Number(minutes) <= 0) return "Codex";

  const value = Number(minutes);
  if (value === 60) return "hourly";
  if (value === 24 * 60) return "daily";
  if (value === 7 * 24 * 60) return "weekly";
  if (value % (24 * 60) === 0) return `${value / (24 * 60)} day`;
  if (value % 60 === 0) return `${value / 60} hour`;
  return `${value} minute`;
}

function normalizeRateLimitWindow(window, fallbackLabel) {
  if (!window || typeof window !== "object") return { ...emptyWindow };

  return normalizeWindow({
    has_data: true,
    remaining_percent: 100 - Number(window.usedPercent || 0),
    reset: formatReset(window.resetsAt),
    window: window.window || formatWindowDuration(window.windowDurationMins) || fallbackLabel,
  });
}

function normalizeRateLimitSnapshot(snapshot) {
  const usage = normalizeUsage({
    primary: normalizeRateLimitWindow(snapshot?.primary, "primary"),
    secondary: normalizeRateLimitWindow(snapshot?.secondary, "secondary"),
  });

  if (usage.primary.has_data || usage.secondary.has_data) {
    return usage;
  }

  const individualLimit = snapshot?.individualLimit;
  if (individualLimit && typeof individualLimit === "object") {
    return normalizeUsage({
      primary: {
        has_data: true,
        remaining_percent: individualLimit.remainingPercent,
        reset: formatReset(individualLimit.resetsAt),
        window: snapshot?.limitName || "Codex",
      },
    });
  }

  return normalizeUsage({ error: "Codex rate limits are not available" });
}

function selectCodexRateLimitSnapshot(response) {
  const byLimitId = response?.rateLimitsByLimitId;
  if (byLimitId && typeof byLimitId === "object") {
    return byLimitId.codex
      || Object.values(byLimitId).find((snapshot) => snapshot?.limitId === "codex")
      || Object.values(byLimitId)[0];
  }

  return response?.rateLimits;
}

function createCodexAppServerClient() {
  const child = spawn(process.execPath, [codexCliPath, "app-server", "--stdio"], {
    cwd: process.cwd(),
    env: process.env,
    windowsHide: true,
  });

  let buffer = "";
  let nextId = 1;
  const pending = new Map();

  function cleanup(error) {
    for (const { reject, timeout } of pending.values()) {
      clearTimeout(timeout);
      reject(error);
    }
    pending.clear();
  }

  child.stdout.setEncoding("utf8");
  child.stdout.on("data", (chunk) => {
    buffer += chunk;

    for (;;) {
      const index = buffer.indexOf("\n");
      if (index < 0) break;

      const line = buffer.slice(0, index).trim();
      buffer = buffer.slice(index + 1);
      if (!line) continue;

      let message;
      try {
        message = JSON.parse(line);
      } catch {
        continue;
      }

      if (!Object.hasOwn(message, "id")) continue;

      const request = pending.get(message.id);
      if (!request) continue;

      pending.delete(message.id);
      clearTimeout(request.timeout);

      if (message.error) {
        request.reject(new Error(message.error.message || JSON.stringify(message.error)));
      } else {
        request.resolve(message.result);
      }
    }
  });

  child.once("error", cleanup);
  child.once("exit", (code, signal) => {
    if (pending.size === 0) return;
    cleanup(new Error(`Codex app-server exited with ${signal || `code ${code ?? 1}`}`));
  });

  function request(method, params = {}) {
    if (!child.stdin.writable) {
      return Promise.reject(new Error("Codex app-server stdin is not writable"));
    }

    const id = nextId++;
    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        pending.delete(id);
        reject(new Error(`Timed out waiting for Codex app-server ${method}`));
      }, 15000);

      pending.set(id, { resolve, reject, timeout });
      child.stdin.write(`${JSON.stringify({ id, method, params })}\n`);
    });
  }

  return {
    request,
    close() {
      child.kill();
    },
  };
}

async function getCodexQuotaFromAppServer() {
  const client = createCodexAppServerClient();
  try {
    await client.request("initialize", {
      clientInfo: {
        name: "abap-llm-monitor",
        version: "1.0.0",
      },
      capabilities: {
        experimentalApi: true,
      },
    });

    const response = await client.request("account/rateLimits/read");
    return normalizeRateLimitSnapshot(selectCodexRateLimitSnapshot(response));
  } finally {
    client.close();
  }
}

function createCodexThread() {
  const codex = new Codex();
  return codex.startThread({
    approvalPolicy: "never",
    networkAccessEnabled: true,
    sandboxMode: "read-only",
    skipGitRepoCheck: true,
    workingDirectory: process.cwd(),
  });
}

async function sendCodexHi() {
  const thread = createCodexThread();
  await thread.run("hi");
}

function parseStatusWindow(line) {
  const remainingMatch = line.match(/(?:remaining|left)\D+(\d{1,3})\s*%/i)
    || line.match(/(\d{1,3})\s*%\s*(?:remaining|left)/i);
  const usedMatch = line.match(/(?:used|usage)\D+(\d{1,3})\s*%/i)
    || line.match(/(\d{1,3})\s*%\s*(?:used|usage)/i);
  const resetMatch = line.match(/\b(?:resets?|reset)\b\s*(?:at|in|on)?\s*([^,;]+)/i);
  const windowMatch = line.match(/\b(\d+\s*(?:minute|hour|day|week|month)s?|daily|weekly|monthly|primary|secondary)\b/i);

  if (!remainingMatch && !usedMatch) return null;

  const percent = remainingMatch ? Number(remainingMatch[1]) : 100 - Number(usedMatch[1]);
  return normalizeWindow({
    has_data: true,
    remaining_percent: percent,
    reset: resetMatch ? resetMatch[1].trim() : "",
    window: windowMatch ? windowMatch[1].toLowerCase() : "Codex",
  });
}

function parseStatus(status) {
  const windows = status
    .split(/\r?\n/)
    .map((line) => parseStatusWindow(line))
    .filter(Boolean);

  return normalizeUsage({
    primary: windows[0] || emptyWindow,
    secondary: windows[1] || emptyWindow,
    error: windows.length > 0 ? "" : status.trim(),
  });
}

function parseUsageLimitError(message) {
  if (!/\b(?:quota|usage) limit\b|quota exceeded/i.test(message)) return null;

  const resetMatch = message.match(/try again at\s+(.+?)(?:\.|$)/i);
  return normalizeUsage({
    primary: {
      has_data: true,
      remaining_percent: 0,
      reset: resetMatch ? resetMatch[1].trim() : "",
      window: "Codex",
    },
    secondary: {
      has_data: true,
      remaining_percent: 0,
      reset: resetMatch ? resetMatch[1].trim() : "",
      window: "Codex",
    },
    error: "",
  });
}

function isFiveHourWindow(window) {
  const label = String(window || "").toLowerCase();
  return /\b5\s*hours?\b/.test(label)
    || /\b5\s*-\s*hours?\b/.test(label)
    || /\b5h\b/.test(label)
    || /\b300\s*minutes?\b/.test(label)
    || label === "primary";
}

function shouldPrimeCodexFiveHourLimit(usage) {
  return [usage?.primary, usage?.secondary].some((window) => {
    if (!window?.has_data || !isFiveHourWindow(window.window)) return false;
    return Number(window.remaining_percent) >= 99;
  });
}

async function readCodexQuota() {
  try {
    return await getCodexQuotaFromAppServer();
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    if (/authentication required|not logged in/i.test(message)) {
      return normalizeUsage({ error: "Codex login required" });
    }

    if (!/method not found|unrecognized|cannot find module|enoent/i.test(message)) {
      return normalizeUsage({ error: message });
    }
  }

  const thread = createCodexThread();

  let turn;
  try {
    turn = await thread.run("/status");
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    const usage = parseUsageLimitError(message);
    if (usage) return usage;
    throw error;
  }

  return parseStatus(turn.finalResponse);
}

export async function getCodexQuota() {
  const quota = await readCodexQuota();

  if (!shouldPrimeCodexFiveHourLimit(quota)) {
    return quota;
  }

  await sendCodexHi();
  return await readCodexQuota();
}

export const getCodexUsage = getCodexQuota;

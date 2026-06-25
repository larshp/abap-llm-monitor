import { Codex } from "@openai/codex-sdk";

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

export async function getCodexQuota() {
  const codex = new Codex();
  const thread = codex.startThread({
    approvalPolicy: "never",
    networkAccessEnabled: true,
    sandboxMode: "read-only",
    skipGitRepoCheck: true,
    workingDirectory: process.cwd(),
  });

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

export const getCodexUsage = getCodexQuota;

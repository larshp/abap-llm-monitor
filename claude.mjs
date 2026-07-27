import { query } from "@anthropic-ai/claude-agent-sdk";

async function* noInput() {}

const emptyWindow = {
  has_data: false,
  remaining_percent: 0,
  reset: "",
  window: "",
};

function hasNullSessionReset(usage) {
  const sessionLimit = usage?.rate_limits?.limits?.find((limit) => {
    return limit?.kind === "session" || limit?.group === "session";
  });

  return sessionLimit?.resets_at === null;
}

function normalizeWindow(label, limit) {
  // Claude Code's /usage hides a window whose utilization is null, so treat it as
  // no data instead of reporting a full window.
  if (!limit || typeof limit !== "object" || limit.utilization == null) {
    return { ...emptyWindow, window: label };
  }

  const utilization = Number(limit.utilization);
  if (!Number.isFinite(utilization)) return { ...emptyWindow, window: label };

  // /usage renders `${Math.floor(utilization)}% used`, so floor before inverting to
  // keep the remaining percentage in step with what Claude Code reports.
  const usedPercent = Math.max(0, Math.min(100, Math.floor(utilization)));

  return {
    has_data: true,
    remaining_percent: 100 - usedPercent,
    reset: typeof limit.resets_at === "string" ? limit.resets_at : "",
    window: label,
  };
}

function normalizeUsage(usage) {
  if (usage?.rate_limits_available !== true || !usage?.rate_limits) {
    return { windows: [], error: "Claude rate limits are not available" };
  }

  const rateLimits = usage.rate_limits;
  const modelScoped = Array.isArray(rateLimits.model_scoped) ? rateLimits.model_scoped : [];
  const windows = [
    normalizeWindow("5 hour", rateLimits.five_hour),
    normalizeWindow("weekly", rateLimits.seven_day),
    normalizeWindow("weekly oauth apps", rateLimits.seven_day_oauth_apps),
    normalizeWindow("weekly opus", rateLimits.seven_day_opus),
    normalizeWindow("weekly sonnet", rateLimits.seven_day_sonnet),
    ...modelScoped.map((limit) => normalizeWindow(limit?.display_name || "model", limit)),
  ].filter((window) => window.has_data);

  return { windows, error: "" };
}

function createSession(prompt) {
  return query({
    prompt,
    options: {
      cwd: process.cwd(),
    },
  });
}

async function readClaudeUsage() {
  const session = createSession(noInput());
  try {
    return await session.usage_EXPERIMENTAL_MAY_CHANGE_DO_NOT_RELY_ON_THIS_API_YET();
  } finally {
    session.close();
  }
}

async function createClaudeSession() {
  const session = createSession("hi");
  try {
    for await (const _message of session) {
      // Drain the response so Claude Code records the session before usage is read.
    }
  } finally {
    session.close();
  }
}

export async function getClaudeQuota() {
  const usage = await readClaudeUsage();

  if (!hasNullSessionReset(usage)) {
    return normalizeUsage(usage);
  }

  await createClaudeSession();
  return normalizeUsage(await readClaudeUsage());
}

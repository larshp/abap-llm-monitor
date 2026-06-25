import { query } from "@anthropic-ai/claude-agent-sdk";

async function* noInput() {}

function hasNullSessionReset(usage) {
  const sessionLimit = usage?.rate_limits?.limits?.find((limit) => {
    return limit?.kind === "session" || limit?.group === "session";
  });

  return sessionLimit?.resets_at === null;
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
    return usage;
  }

  await createClaudeSession();
  return await readClaudeUsage();
}
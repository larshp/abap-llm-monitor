import { query } from "@anthropic-ai/claude-agent-sdk";

async function* noInput() {}

export async function getClaudeQuota() {
  const session = query({
    prompt: noInput(),
    options: {
      cwd: process.cwd(),
    },
  });

  try {
    return await session.usage_EXPERIMENTAL_MAY_CHANGE_DO_NOT_RELY_ON_THIS_API_YET();
  } finally {
    session.close();
  }
}
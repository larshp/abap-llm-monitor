# abap-llm-monitor
Monitor LLM usage and more

Designed for use with [Corsair Xeneon Edge](https://www.corsair.com/us/en/p/monitors/cc-9011306-ww/xeneon-edge-14-5-lcd-touchscreen-cc-9011306-ww)

## Configuration

The `start` and `app` scripts load environment variables from `.env` via `node --env-file=.env`.

Set `OPENROUTER_API_KEY` to fetch remaining OpenRouter credits from `https://openrouter.ai/api/v1/credits`.

Set `CODEX_ACCESS_TOKEN` (preferred) or `CODEX_API_KEY` to fetch Codex usage limits from `https://chatgpt.com/backend-api/wham/usage`.

Optionally set `CODEX_ACCOUNT_ID` or `CHATGPT_ACCOUNT_ID` when your token requires an account header.

If no Codex token is configured, credentials are read from `~/.codex/auth.json` (or `CODEX_HOME/auth.json`).

`CODEX_PLAN`, `CHATGPT_PLAN`, and `CODEX_USAGE_URL` are currently not wired in the runtime.
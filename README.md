# abap-llm-monitor
Monitor LLM usage and more

Designed for use with [⁠Corsair Xeneon Edge](https://www.corsair.com/us/en/p/monitors/cc-9011306-ww/xeneon-edge-14-5-lcd-touchscreen-cc-9011306-ww)

## Configuration

Set `OPENROUTER_API_KEY` in a local `.env` file before starting the backend to fetch the remaining OpenRouter credits from `https://openrouter.ai/api/v1/credits`.

Set `CODEX_PLAN` or `CHATGPT_PLAN` to report the Codex quota tier. Supported values are `plus`, `pro-100`, `pro-200`, `business-standard`, `business-usage`, `enterprise`, and `edu`.

Set `CODEX_ACCESS_TOKEN` or `CODEX_API_KEY` to fetch Codex usage limits from `https://chatgpt.com/backend-api/wham/usage`. Optionally set `CODEX_ACCOUNT_ID` or `CHATGPT_ACCOUNT_ID` when the token needs an account header, and override the endpoint with `CODEX_USAGE_URL`.
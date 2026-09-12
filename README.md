# abap-llm-monitor
Monitor LLM usage and more

Designed for use with [Corsair Xeneon Edge](https://www.corsair.com/us/en/p/monitors/cc-9011306-ww/xeneon-edge-14-5-lcd-touchscreen-cc-9011306-ww)

## Configuration

The `start` and `app` scripts load environment variables from `.env` via `node --env-file=.env`.

Set `OPENROUTER_API_KEY` to fetch remaining OpenRouter credits from `https://openrouter.ai/api/v1/credits`.

Set `OPENCODE_API_KEY` to fetch OpenCode Go subscription usage from `https://opencode.ai/zen/go/v1/usage`. Without it the OpenCode Go panel is hidden and startup logs a reminder that the key can be added to `.env`.

CLASS zcl_env_config DEFINITION PUBLIC FINAL CREATE PRIVATE.
  PUBLIC SECTION.
    CLASS-DATA codex_access_token TYPE string.
    CLASS-DATA codex_account_id TYPE string.
    CLASS-DATA codex_usage_url TYPE string VALUE `https://chatgpt.com/backend-api/wham/usage`.
    CLASS-DATA openrouter_api_key TYPE string.
    CLASS-DATA openrouter_credits_url TYPE string VALUE `https://openrouter.ai/api/v1/credits`.
ENDCLASS.

CLASS zcl_env_config IMPLEMENTATION.
ENDCLASS.

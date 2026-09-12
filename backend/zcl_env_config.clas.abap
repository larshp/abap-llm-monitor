CLASS zcl_env_config DEFINITION PUBLIC FINAL CREATE PRIVATE.
  PUBLIC SECTION.
    CLASS-DATA openrouter_api_key TYPE string.
    CLASS-DATA opencode_api_key TYPE string.

    CLASS-DATA openrouter_credits_url TYPE string VALUE `https://openrouter.ai/api/v1/credits`.
    CLASS-DATA opencode_usage_url TYPE string VALUE `https://opencode.ai/zen/go/v1/usage`.
ENDCLASS.

CLASS zcl_env_config IMPLEMENTATION.
ENDCLASS.

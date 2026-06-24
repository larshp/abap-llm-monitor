CLASS zcl_provider DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    CLASS-METHODS get_metrics_json
      RETURNING
        VALUE(rv_json) TYPE string.
ENDCLASS.

CLASS zcl_provider IMPLEMENTATION.
  METHOD get_metrics_json.
    rv_json =
      '[' &&
      '{"id":"codex","logo":"/openai.svg","name":"OpenAI Codex","metrics":[' &&
      '{"kind":"usage","remainingPercent":58,"reset":"12:52 PM","window":"5 hour"},' &&
      '{"kind":"usage","remainingPercent":74,"reset":"Monday","window":"weekly"}' &&
      ']},' &&
      '{"id":"copilot","logo":"/githubcopilot.svg","name":"GitHub Copilot","metrics":[' &&
      '{"kind":"credits","period":"monthly","reset":"July 1, 12:00 AM","total":25000,"used":6580}' &&
      ']},' &&
      '{"id":"claude","logo":"/claude.svg","name":"Claude Code","metrics":[' &&
      '{"kind":"usage","remainingPercent":42,"reset":"1:20 PM","window":"5 hour"},' &&
      '{"kind":"usage","remainingPercent":63,"reset":"Monday","window":"weekly"}' &&
      ']},' &&
      '{"id":"openrouter","logo":"/openrouter.svg","name":"OpenRouter","metrics":[' &&
      '{"amount":12.4,"kind":"balance"}' &&
      ']}' &&
      ']'.
  ENDMETHOD.
ENDCLASS.
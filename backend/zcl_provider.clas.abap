CLASS zcl_provider DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_metric,
        kind              TYPE string,
        remaining_percent TYPE i,
        reset             TYPE string,
        window            TYPE string,
        period            TYPE string,
        total             TYPE i,
        used              TYPE i,
        amount            TYPE f,
        quota             TYPE string,
        multiplier        TYPE i,
        error             TYPE string,
      END OF ty_metric,
      ty_metrics TYPE STANDARD TABLE OF ty_metric WITH EMPTY KEY,
      BEGIN OF ty_provider,
        id      TYPE string,
        logo    TYPE string,
        name    TYPE string,
        metrics TYPE ty_metrics,
      END OF ty_provider,
      ty_providers TYPE STANDARD TABLE OF ty_provider WITH EMPTY KEY.

    CLASS-METHODS get_metrics
      RETURNING
        VALUE(rt_providers) TYPE ty_providers.

  PRIVATE SECTION.
    CLASS-METHODS random_percent
      RETURNING
        VALUE(rv_percent) TYPE i.

    CLASS-METHODS codex_usage
      RETURNING
        VALUE(rt_metrics) TYPE ty_metrics.

    CLASS-METHODS openrouter_balance
      RETURNING
        VALUE(rs_metric) TYPE ty_metric.
ENDCLASS.

CLASS zcl_provider IMPLEMENTATION.

  METHOD get_metrics.
    DATA(lt_codex_metrics) = VALUE ty_metrics( ).

    APPEND LINES OF codex_usage( ) TO lt_codex_metrics.

    rt_providers = VALUE #(
      ( id = `codex`
        logo = `/openai.svg`
        name = `OpenAI Codex`
        metrics = lt_codex_metrics )
      ( id = `copilot`
        logo = `/githubcopilot.svg`
        name = `GitHub Copilot`
        metrics = VALUE #(
          ( kind = `credits` period = `monthly` reset = `?` total = 25000 used = 0 ) ) )
      ( id = `claude`
        logo = `/claude.svg`
        name = `Claude Code`
        metrics = VALUE #(
          ( kind = `usage` remaining_percent = 0 reset = `?` window = `5 hour` )
          ( kind = `usage` remaining_percent = 0 reset = `?` window = `weekly` ) ) )
      ( id = `openrouter`
        logo = `/openrouter.svg`
        name = `OpenRouter`
        metrics = VALUE #(
          ( openrouter_balance( ) ) ) ) ).
  ENDMETHOD.

  METHOD codex_usage.
    DATA(ls_usage) = zcl_codex_client=>get_usage( ).

    IF ls_usage-error IS NOT INITIAL.
      rt_metrics = VALUE #(
        ( kind = `usage` window = `Codex` remaining_percent = 0 error = ls_usage-error ) ).
      RETURN.
    ENDIF.

    IF ls_usage-primary-has_data = abap_true.
      APPEND VALUE #(
        kind              = `usage`
        remaining_percent = ls_usage-primary-remaining_percent
        reset             = ls_usage-primary-reset
        window            = ls_usage-primary-window ) TO rt_metrics.
    ENDIF.

    IF ls_usage-secondary-has_data = abap_true.
      APPEND VALUE #(
        kind              = `usage`
        remaining_percent = ls_usage-secondary-remaining_percent
        reset             = ls_usage-secondary-reset
        window            = ls_usage-secondary-window ) TO rt_metrics.
    ENDIF.
  ENDMETHOD.

  METHOD openrouter_balance.
    DATA(ls_balance) = zcl_openrouter_client=>get_remaining_credits( ).

    rs_metric = VALUE #(
      kind   = `balance`
      amount = ls_balance-amount
      error  = ls_balance-error ).
  ENDMETHOD.

  METHOD random_percent.
    rv_percent = cl_abap_random_int=>create(
      min = 1
      max = 100 )->get_next( ).
  ENDMETHOD.
ENDCLASS.

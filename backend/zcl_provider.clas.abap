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

    CLASS-METHODS openrouter_balance
      RETURNING
        VALUE(rs_metric) TYPE ty_metric.
ENDCLASS.

CLASS zcl_provider IMPLEMENTATION.
  METHOD get_metrics.
    rt_providers = VALUE #(
      ( id = `codex`
        logo = `/openai.svg`
        name = `OpenAI Codex`
        metrics = VALUE #(
          ( kind = `usage` remaining_percent = random_percent( ) reset = `12:52 PM` window = `5 hour` )
          ( kind = `usage` remaining_percent = random_percent( ) reset = `Monday` window = `weekly` ) ) )
      ( id = `copilot`
        logo = `/githubcopilot.svg`
        name = `GitHub Copilot`
        metrics = VALUE #(
          ( kind = `credits` period = `monthly` reset = `July 1, 12:00 AM` total = 25000 used = 6580 ) ) )
      ( id = `claude`
        logo = `/claude.svg`
        name = `Claude Code`
        metrics = VALUE #(
          ( kind = `usage` remaining_percent = random_percent( ) reset = `1:20 PM` window = `5 hour` )
          ( kind = `usage` remaining_percent = random_percent( ) reset = `Monday` window = `weekly` ) ) )
      ( id = `openrouter`
        logo = `/openrouter.svg`
        name = `OpenRouter`
        metrics = VALUE #(
          ( openrouter_balance( ) ) ) ) ).
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
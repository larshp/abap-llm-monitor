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

    CLASS-METHODS codex_quota
      RETURNING
        VALUE(rs_metric) TYPE ty_metric.

    CLASS-METHODS codex_usage
      RETURNING
        VALUE(rt_metrics) TYPE ty_metrics.

    CLASS-METHODS openrouter_balance
      RETURNING
        VALUE(rs_metric) TYPE ty_metric.
ENDCLASS.

CLASS zcl_provider IMPLEMENTATION.
  METHOD get_metrics.
    DATA(lt_codex_metrics) = VALUE ty_metrics( ( codex_quota( ) ) ).

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

  METHOD codex_quota.
    DATA(lv_plan) = to_lower( zcl_env_config=>codex_plan ).

    REPLACE ALL OCCURRENCES OF `_` IN lv_plan WITH `-`.

    rs_metric = VALUE #( kind = `quota` ).

    CASE lv_plan.
      WHEN `plus`.
        rs_metric-quota = `Plus`.
        rs_metric-multiplier = 1.
      WHEN `pro` OR `pro-100` OR `pro-5x`.
        rs_metric-quota = `Pro 5x`.
        rs_metric-multiplier = 5.
      WHEN `pro-200` OR `pro-20x`.
        rs_metric-quota = `Pro 20x`.
        rs_metric-multiplier = 20.
      WHEN `business` OR `business-standard`.
        rs_metric-quota = `Business standard seat`.
      WHEN `business-usage` OR `business-usage-based`.
        rs_metric-quota = `Business usage-based seat`.
      WHEN `enterprise` OR `edu`.
        rs_metric-quota = `Enterprise/Edu workspace`.
      WHEN OTHERS.
        rs_metric-error = `Set CODEX_PLAN to plus, pro-100, pro-200, business-standard, business-usage, enterprise, or edu`.
    ENDCASE.
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

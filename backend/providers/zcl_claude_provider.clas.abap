CLASS zcl_claude_provider DEFINITION PUBLIC FINAL CREATE PUBLIC.
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
      ty_metrics TYPE STANDARD TABLE OF ty_metric WITH EMPTY KEY.

    CLASS-METHODS get_metrics
      RETURNING
        VALUE(rt_metrics) TYPE ty_metrics.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_rate_limit,
        utilization TYPE f,
        resets_at   TYPE string,
      END OF ty_rate_limit,
      BEGIN OF ty_model_rate_limit,
        display_name TYPE string,
        utilization  TYPE f,
        resets_at    TYPE string,
      END OF ty_model_rate_limit,
      ty_model_rate_limits TYPE STANDARD TABLE OF ty_model_rate_limit WITH EMPTY KEY,
      BEGIN OF ty_rate_limits,
        five_hour             TYPE ty_rate_limit,
        seven_day             TYPE ty_rate_limit,
        seven_day_oauth_apps  TYPE ty_rate_limit,
        seven_day_opus        TYPE ty_rate_limit,
        seven_day_sonnet      TYPE ty_rate_limit,
        model_scoped          TYPE ty_model_rate_limits,
      END OF ty_rate_limits,
      BEGIN OF ty_quota_response,
        rate_limits_available TYPE abap_bool,
        rate_limits           TYPE ty_rate_limits,
        error                 TYPE string,
      END OF ty_quota_response.

    CLASS-METHODS map_limit
      IMPORTING
        iv_window        TYPE string
        is_limit         TYPE ty_rate_limit
      RETURNING
        VALUE(rs_metric) TYPE ty_metric.

    CLASS-METHODS has_limit_data
      IMPORTING
        is_limit      TYPE ty_rate_limit
      RETURNING
        VALUE(rv_has) TYPE abap_bool.

    CLASS-METHODS remaining_percent
      IMPORTING
        iv_utilization TYPE f
      RETURNING
        VALUE(rv_percent) TYPE i.
ENDCLASS.

CLASS zcl_claude_provider IMPLEMENTATION.
  METHOD get_metrics.
    DATA(lv_json) = ``.
    DATA(ls_response) = VALUE ty_quota_response( ).

    WRITE '@KERNEL try { if (typeof globalThis.getClaudeQuota !== "function") { throw new Error("global getClaudeQuota is not registered"); } lv_json.set(JSON.stringify(await globalThis.getClaudeQuota())); } catch (e) { lv_json.set(JSON.stringify({ error: e instanceof Error ? (e.message || e.stack) : String(e) })); }'.

    /ui2/cl_json=>deserialize(
      EXPORTING
        json = lv_json
      CHANGING
        data = ls_response ).

    IF ls_response-error IS NOT INITIAL.
      rt_metrics = VALUE #(
        ( kind = `usage` window = `Claude` remaining_percent = 0 error = ls_response-error ) ).
      RETURN.
    ENDIF.

    IF ls_response-rate_limits_available <> abap_true.
      rt_metrics = VALUE #(
        ( kind = `usage` window = `Claude` remaining_percent = 0 error = `Claude rate limits are not available` ) ).
      RETURN.
    ENDIF.

    APPEND map_limit(
      iv_window = `5 hour`
      is_limit  = ls_response-rate_limits-five_hour ) TO rt_metrics.
    APPEND map_limit(
      iv_window = `weekly`
      is_limit  = ls_response-rate_limits-seven_day ) TO rt_metrics.

    IF has_limit_data( ls_response-rate_limits-seven_day_oauth_apps ) = abap_true.
      APPEND map_limit(
        iv_window = `weekly oauth apps`
        is_limit  = ls_response-rate_limits-seven_day_oauth_apps ) TO rt_metrics.
    ENDIF.

    IF has_limit_data( ls_response-rate_limits-seven_day_opus ) = abap_true.
      APPEND map_limit(
        iv_window = `weekly opus`
        is_limit  = ls_response-rate_limits-seven_day_opus ) TO rt_metrics.
    ENDIF.

    IF has_limit_data( ls_response-rate_limits-seven_day_sonnet ) = abap_true.
      APPEND map_limit(
        iv_window = `weekly sonnet`
        is_limit  = ls_response-rate_limits-seven_day_sonnet ) TO rt_metrics.
    ENDIF.

    LOOP AT ls_response-rate_limits-model_scoped INTO DATA(ls_model_limit).
      DATA(lv_window) = ls_model_limit-display_name.

      IF lv_window IS INITIAL.
        lv_window = `model`.
      ENDIF.

      APPEND map_limit(
        iv_window = lv_window
        is_limit  = CORRESPONDING #( ls_model_limit ) ) TO rt_metrics.
    ENDLOOP.
  ENDMETHOD.

  METHOD map_limit.
    rs_metric = VALUE #(
      kind              = `usage`
      window            = iv_window
      reset             = is_limit-resets_at
      remaining_percent = remaining_percent( is_limit-utilization ) ).
  ENDMETHOD.

  METHOD has_limit_data.
    rv_has = boolc( is_limit-utilization <> 0 OR is_limit-resets_at IS NOT INITIAL ).
  ENDMETHOD.

  METHOD remaining_percent.
    DATA(lv_percent) = 100 - iv_utilization.

    IF lv_percent < 0.
      rv_percent = 0.
    ELSEIF lv_percent > 100.
      rv_percent = 100.
    ELSE.
      rv_percent = lv_percent.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
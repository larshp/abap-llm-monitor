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
      BEGIN OF ty_usage_window,
        has_data          TYPE abap_bool,
        remaining_percent TYPE i,
        reset             TYPE string,
        window            TYPE string,
      END OF ty_usage_window,
      ty_usage_windows TYPE STANDARD TABLE OF ty_usage_window WITH EMPTY KEY,
      BEGIN OF ty_quota_response,
        windows TYPE ty_usage_windows,
        error   TYPE string,
      END OF ty_quota_response.
ENDCLASS.

CLASS zcl_claude_provider IMPLEMENTATION.
  METHOD get_metrics.
    DATA(lv_json) = ``.
    DATA(ls_response) = VALUE ty_quota_response( ).

    WRITE '@KERNEL try { if (typeof globalThis.getClaudeQuota !== "function") { throw new Error("global getClaudeQuota is not registered"); } lv_json.set(JSON.stringify(await globalThis.getClaudeQuota())); } catch (e) { lv_json.set(JSON.stringify({ windows: [], error: e instanceof Error ? (e.message || e.stack) : String(e) })); }'.

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

    LOOP AT ls_response-windows INTO DATA(ls_window).
      IF ls_window-has_data <> abap_true.
        CONTINUE.
      ENDIF.

      APPEND VALUE #(
        kind              = `usage`
        remaining_percent = ls_window-remaining_percent
        reset             = ls_window-reset
        window            = ls_window-window ) TO rt_metrics.
    ENDLOOP.

    IF rt_metrics IS INITIAL.
      rt_metrics = VALUE #(
        ( kind = `usage` window = `Claude` remaining_percent = 0 error = `Claude rate limits are not available` ) ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.

CLASS zcl_copilot_provider DEFINITION PUBLIC FINAL CREATE PUBLIC.
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
      BEGIN OF ty_quota_response,
        period            TYPE string,
        reset             TYPE string,
        total             TYPE i,
        used              TYPE i,
        remaining_percent TYPE i,
        error             TYPE string,
      END OF ty_quota_response.
ENDCLASS.

CLASS zcl_copilot_provider IMPLEMENTATION.
  METHOD get_metrics.
    DATA(lv_json) = ``.
    DATA(ls_response) = VALUE ty_quota_response( ).

    WRITE '@KERNEL try { if (typeof globalThis.getCopilotQuota !== "function") { throw new Error("global getCopilotQuota is not registered"); } const quota = await globalThis.getCopilotQuota(); const premium = quota?.quotaSnapshots?.premium_interactions ?? {}; lv_json.set(JSON.stringify({ period: "monthly", reset: premium.resetDate ?? "", total: premium.entitlementRequests ?? 0, used: premium.usedRequests ?? 0, remaining_percent: premium.remainingPercentage ?? 0 })); } catch (e) { lv_json.set(JSON.stringify({ error: e instanceof Error ? (e.message || e.stack) : String(e) })); }'.

    /ui2/cl_json=>deserialize(
      EXPORTING
        json = lv_json
      CHANGING
        data = ls_response ).

    IF ls_response-error IS NOT INITIAL.
      rt_metrics = VALUE #(
        ( kind = `credits` period = `monthly` error = ls_response-error ) ).
      RETURN.
    ENDIF.

    IF ls_response-total > 0.
      rt_metrics = VALUE #(
        ( kind       = `credits`
          period     = ls_response-period
          reset      = ls_response-reset
          total      = ls_response-total
          used       = ls_response-used ) ).
    ELSE.
      rt_metrics = VALUE #(
        ( kind       = `quota`
          quota      = lv_json ) ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.

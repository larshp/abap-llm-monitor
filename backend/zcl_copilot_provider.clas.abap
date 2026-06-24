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
ENDCLASS.

CLASS zcl_copilot_provider IMPLEMENTATION.
  METHOD get_metrics.
    DATA(lv_error) = ``.
    DATA(lv_period) = `monthly`.
    DATA(lv_quota) = ``.
    DATA(lv_reset) = ``.
    DATA(lv_total) = 0.
    DATA(lv_used) = 0.
    DATA(lv_multiplier) = 0.

    WRITE '@KERNEL try {'.
    WRITE '@KERNEL   if (typeof globalThis.getCopilotQuota !== "function") { throw new Error("global getCopilotQuota is not registered"); }'.
    WRITE '@KERNEL   const quota = await globalThis.getCopilotQuota();'.
    WRITE '@KERNEL   const candidates = [quota, quota?.quota, quota?.copilot, quota?.copilot_quota, quota?.data].filter(value => value && typeof value === "object");'.
    WRITE '@KERNEL   const pick = (...names) => { for (const source of candidates) { for (const name of names) { if (source[name] !== undefined && source[name] !== null) { return source[name]; } } } return undefined; };'.
    WRITE '@KERNEL   const asNumber = value => { const number = Number(value); return Number.isFinite(number) ? number : 0; };'.
    WRITE '@KERNEL   let total = asNumber(pick("total", "limit", "quota", "allowance", "included", "monthly_quota", "monthlyQuota"));'.
    WRITE '@KERNEL   let used = asNumber(pick("used", "usage", "consumed", "spent"));'.
    WRITE '@KERNEL   const remaining = asNumber(pick("remaining", "left", "available"));'.
    WRITE '@KERNEL   if (!total && remaining && used) { total = remaining + used; }'.
    WRITE '@KERNEL   if (!used && total && remaining) { used = Math.max(total - remaining, 0); }'.
    WRITE '@KERNEL   lv_total.set(Math.trunc(total));'.
    WRITE '@KERNEL   lv_used.set(Math.trunc(used));'.
    WRITE '@KERNEL   lv_multiplier.set(Math.trunc(asNumber(pick("multiplier", "usage_multiplier", "usageMultiplier"))));'.
    WRITE '@KERNEL   lv_reset.set(String(pick("reset", "reset_at", "resetAt", "resets_at", "resetsAt") ?? ""));'.
    WRITE '@KERNEL   lv_period.set(String(pick("period", "window") ?? "monthly"));'.
    WRITE '@KERNEL   lv_quota.set(String(pick("name", "plan", "sku", "label", "quota_name", "quotaName") ?? (total ? "" : JSON.stringify(quota ?? {}))));'.
    WRITE '@KERNEL } catch (e) {'.
    WRITE '@KERNEL   lv_error.set(e instanceof Error ? (e.message || e.stack) : String(e));'.
    WRITE '@KERNEL }'.

    IF lv_error IS NOT INITIAL.
      rt_metrics = VALUE #(
        ( kind = `credits` period = lv_period reset = lv_reset error = lv_error ) ).
      RETURN.
    ENDIF.

    IF lv_total > 0.
      rt_metrics = VALUE #(
        ( kind       = `credits`
          period     = lv_period
          reset      = lv_reset
          total      = lv_total
          used       = lv_used
          multiplier = lv_multiplier ) ).
    ELSE.
      rt_metrics = VALUE #(
        ( kind       = `quota`
          quota      = lv_quota
          multiplier = lv_multiplier ) ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.
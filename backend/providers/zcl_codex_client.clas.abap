CLASS zcl_codex_client DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_usage_window,
        has_data          TYPE abap_bool,
        remaining_percent TYPE i,
        reset             TYPE string,
        window            TYPE string,
      END OF ty_usage_window,
      BEGIN OF ty_usage,
        primary   TYPE ty_usage_window,
        secondary TYPE ty_usage_window,
        error     TYPE string,
      END OF ty_usage.

    CLASS-METHODS get_usage
      RETURNING
        VALUE(rs_usage) TYPE ty_usage.
ENDCLASS.

CLASS zcl_codex_client IMPLEMENTATION.
  METHOD get_usage.
    DATA(lv_json) = ``.

    WRITE '@KERNEL try { if (typeof globalThis.getCodexUsage !== "function") { throw new Error("global getCodexUsage is not registered"); } lv_json.set(JSON.stringify(await globalThis.getCodexUsage())); } catch (e) { lv_json.set(JSON.stringify({ error: e instanceof Error ? (e.message || e.stack) : String(e), primary: { has_data: false, remaining_percent: 0, reset: "", window: "" }, secondary: { has_data: false, remaining_percent: 0, reset: "", window: "" } })); }'.

    /ui2/cl_json=>deserialize(
      EXPORTING
        json = lv_json
      CHANGING
        data = rs_usage ).
  ENDMETHOD.
ENDCLASS.
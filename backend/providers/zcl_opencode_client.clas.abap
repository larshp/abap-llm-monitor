CLASS zcl_opencode_client DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_usage_window,
        has_data          TYPE abap_bool,
        remaining_percent TYPE i,
        reset             TYPE string,
        window            TYPE string,
      END OF ty_usage_window,
      ty_usage_windows TYPE STANDARD TABLE OF ty_usage_window WITH EMPTY KEY,
      BEGIN OF ty_usage,
        windows TYPE ty_usage_windows,
        error   TYPE string,
      END OF ty_usage.

    CLASS-METHODS get_usage
      RETURNING
        VALUE(rs_usage) TYPE ty_usage.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_window,
        status    TYPE string,
        percent   TYPE i,
        resets_at TYPE string,
      END OF ty_window,
      BEGIN OF ty_usage_data,
        rolling TYPE ty_window,
        weekly  TYPE ty_window,
        monthly TYPE ty_window,
      END OF ty_usage_data,
      BEGIN OF ty_usage_response,
        usage TYPE ty_usage_data,
      END OF ty_usage_response.

    CLASS-METHODS to_usage_window
      IMPORTING
        is_window        TYPE ty_window
        iv_label         TYPE string
      RETURNING
        VALUE(rs_window) TYPE ty_usage_window.
ENDCLASS.

CLASS zcl_opencode_client IMPLEMENTATION.
  METHOD get_usage.
    DATA li_client TYPE REF TO if_http_client.
    DATA(lv_status) = 0.
    DATA(lv_response) = ``.
    DATA(ls_response) = VALUE ty_usage_response( ).

    IF zcl_env_config=>opencode_api_key IS INITIAL.
      rs_usage-error = `Missing OPENCODE_API_KEY`.
      RETURN.
    ENDIF.

    TRY.
        cl_http_client=>create_by_url(
          EXPORTING
            url    = zcl_env_config=>opencode_usage_url
          IMPORTING
            client = li_client ).

        li_client->request->set_header_field(
          name  = `accept`
          value = `application/json` ).
        li_client->request->set_header_field(
          name  = `authorization`
          value = |Bearer { zcl_env_config=>opencode_api_key }| ).

        li_client->send( ).
        li_client->receive( ).
        li_client->response->get_status( IMPORTING code = lv_status ).

        IF lv_status <> 200.
          rs_usage-error = |OpenCode returned HTTP { lv_status }|.
          li_client->close( ).
          RETURN.
        ENDIF.

        lv_response = li_client->response->get_cdata( ).
        li_client->close( ).

        " the usage endpoint answers camelCase, eg "resetsAt"
        /ui2/cl_json=>deserialize(
          EXPORTING
            json        = lv_response
            pretty_name = /ui2/cl_json=>pretty_mode-camel_case
          CHANGING
            data        = ls_response ).

        rs_usage-windows = VALUE #(
          ( to_usage_window( is_window = ls_response-usage-rolling
                             iv_label  = `5 hour` ) )
          ( to_usage_window( is_window = ls_response-usage-weekly
                             iv_label  = `weekly` ) )
          ( to_usage_window( is_window = ls_response-usage-monthly
                             iv_label  = `monthly` ) ) ).
      CATCH cx_root.
        rs_usage-error = `OpenCode usage request failed`.
    ENDTRY.
  ENDMETHOD.

  METHOD to_usage_window.
    rs_window-window = iv_label.

    " a window missing from the response deserializes to an empty status
    IF is_window-status IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_remaining) = 100 - is_window-percent.
    IF lv_remaining < 0.
      lv_remaining = 0.
    ELSEIF lv_remaining > 100.
      lv_remaining = 100.
    ENDIF.

    rs_window-has_data = abap_true.
    rs_window-remaining_percent = lv_remaining.
    rs_window-reset = is_window-resets_at.
  ENDMETHOD.
ENDCLASS.

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

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_api_window,
        used_percent         TYPE i,
        limit_window_seconds TYPE i,
        reset_after_seconds  TYPE i,
        reset_at             TYPE i,
      END OF ty_api_window,
      BEGIN OF ty_rate_limit,
        primary_window   TYPE ty_api_window,
        secondary_window TYPE ty_api_window,
      END OF ty_rate_limit,
      BEGIN OF ty_response,
        rate_limit TYPE ty_rate_limit,
      END OF ty_response.

    CLASS-METHODS map_window
      IMPORTING
        is_window        TYPE ty_api_window
        iv_fallback_name TYPE string
      RETURNING
        VALUE(rs_window) TYPE ty_usage_window.

    CLASS-METHODS remaining_percent
      IMPORTING
        iv_used_percent TYPE i
      RETURNING
        VALUE(rv_percent) TYPE i.

    CLASS-METHODS reset_label
      IMPORTING
        iv_reset_after_seconds TYPE i
        iv_reset_at            TYPE i
      RETURNING
        VALUE(rv_label) TYPE string.

    CLASS-METHODS format_cet_timestamp
      IMPORTING
        iv_timestamp TYPE timestamp
      RETURNING
        VALUE(rv_text) TYPE string.

    CLASS-METHODS window_label
      IMPORTING
        iv_seconds TYPE i
        iv_fallback_name TYPE string
      RETURNING
        VALUE(rv_label) TYPE string.
ENDCLASS.

CLASS zcl_codex_client IMPLEMENTATION.
  METHOD get_usage.
    DATA li_client TYPE REF TO if_http_client.
    DATA(lv_status) = 0.
    DATA(lv_response) = ``.
    DATA(ls_response) = VALUE ty_response( ).

    IF zcl_env_config=>codex_access_token IS INITIAL.
      rs_usage-error = `Missing CODEX_ACCESS_TOKEN or CODEX_API_KEY`.
      RETURN.
    ENDIF.

    TRY.
        cl_http_client=>create_by_url(
          EXPORTING
            url    = zcl_env_config=>codex_usage_url
          IMPORTING
            client = li_client ).

        li_client->request->set_header_field(
          name  = `accept`
          value = `application/json` ).
        li_client->request->set_header_field(
          name  = `authorization`
          value = |Bearer { zcl_env_config=>codex_access_token }| ).
        li_client->request->set_header_field(
          name  = `user-agent`
          value = `codex-cli` ).

        IF zcl_env_config=>codex_account_id IS NOT INITIAL.
          li_client->request->set_header_field(
            name  = `ChatGPT-Account-Id`
            value = zcl_env_config=>codex_account_id ).
        ENDIF.

        li_client->send( ).
        li_client->receive( ).
        li_client->response->get_status( IMPORTING code = lv_status ).

        IF lv_status <> 200.
          rs_usage-error = |Codex usage returned HTTP { lv_status }|.
          li_client->close( ).
          RETURN.
        ENDIF.

        lv_response = li_client->response->get_cdata( ).
        li_client->close( ).

        /ui2/cl_json=>deserialize(
          EXPORTING
            json = lv_response
          CHANGING
            data = ls_response ).

        rs_usage-primary = map_window(
          is_window        = ls_response-rate_limit-primary_window
          iv_fallback_name = `primary` ).
        rs_usage-secondary = map_window(
          is_window        = ls_response-rate_limit-secondary_window
          iv_fallback_name = `secondary` ).

        IF rs_usage-primary-has_data = abap_false AND rs_usage-secondary-has_data = abap_false.
          rs_usage-error = `Codex usage response did not include rate limits`.
        ENDIF.
      CATCH cx_root.
        rs_usage-error = `Codex usage request failed`.
    ENDTRY.
  ENDMETHOD.

  METHOD map_window.
    IF is_window-used_percent = 0
        AND is_window-limit_window_seconds = 0
        AND is_window-reset_after_seconds = 0
        AND is_window-reset_at = 0.
      RETURN.
    ENDIF.

    rs_window = VALUE #(
      has_data          = abap_true
      remaining_percent = remaining_percent( is_window-used_percent )
      reset             = reset_label(
        iv_reset_after_seconds = is_window-reset_after_seconds
        iv_reset_at            = is_window-reset_at )
      window            = window_label(
        iv_seconds       = is_window-limit_window_seconds
        iv_fallback_name = iv_fallback_name ) ).
  ENDMETHOD.

  METHOD remaining_percent.
    rv_percent = 100 - iv_used_percent.

    IF rv_percent < 0.
      rv_percent = 0.
    ELSEIF rv_percent > 100.
      rv_percent = 100.
    ENDIF.
  ENDMETHOD.

  METHOD reset_label.
    DATA lv_reset_timestamp TYPE timestamp.
    DATA lv_specific_time TYPE string.

    IF iv_reset_at > 0.
      lv_reset_timestamp = cl_abap_tstmp=>add(
        tstmp = CONV timestamp( '19700101000000' )
        secs  = iv_reset_at ).
      lv_specific_time = format_cet_timestamp( lv_reset_timestamp ).
    ELSEIF iv_reset_after_seconds > 0.
      DATA(lv_now_utc) = CONV timestamp( 0 ).

      cl_abap_tstmp=>systemtstmp_syst2utc(
        EXPORTING
          syst_date = sy-datum
          syst_time = sy-uzeit
        IMPORTING
          utc_tstmp = lv_now_utc ).

      lv_reset_timestamp = cl_abap_tstmp=>add(
        tstmp = lv_now_utc
        secs  = iv_reset_after_seconds ).
      lv_specific_time = format_cet_timestamp( lv_reset_timestamp ).
    ENDIF.

    IF iv_reset_after_seconds >= 86400.
      rv_label = |in { iv_reset_after_seconds DIV 86400 } day(s)|.
    ELSEIF iv_reset_after_seconds >= 3600.
      rv_label = |in { iv_reset_after_seconds DIV 3600 } hour(s)|.
    ELSEIF iv_reset_after_seconds > 0.
      rv_label = |in { iv_reset_after_seconds DIV 60 } minute(s)|.
    ELSEIF iv_reset_at > 0.
      rv_label = |at { lv_specific_time }|.
    ENDIF.

    IF rv_label IS NOT INITIAL AND lv_specific_time IS NOT INITIAL
        AND rv_label NS `at `.
      rv_label = |{ rv_label } at { lv_specific_time }|.
    ENDIF.
  ENDMETHOD.

  METHOD format_cet_timestamp.
    DATA(lv_cest_timestamp) = cl_abap_tstmp=>add(
      tstmp = iv_timestamp
      secs  = 10800 ).
    DATA(lv_compact) = |{ lv_cest_timestamp }|.

    IF strlen( lv_compact ) < 12.
      rv_text = lv_compact.
      RETURN.
    ENDIF.

    rv_text = |{ lv_compact+0(4) }-{ lv_compact+4(2) }-{ lv_compact+6(2) } { lv_compact+8(2) }:{ lv_compact+10(2) } CET|.
  ENDMETHOD.

  METHOD window_label.
    IF iv_seconds >= 2592000.
      rv_label = `monthly`.
    ELSEIF iv_seconds >= 604800.
      rv_label = `weekly`.
    ELSEIF iv_seconds >= 86400.
      rv_label = |{ iv_seconds DIV 86400 } day|.
    ELSEIF iv_seconds >= 3600.
      rv_label = |{ iv_seconds DIV 3600 } hour|.
    ELSEIF iv_seconds >= 60.
      rv_label = |{ iv_seconds DIV 60 } minute|.
    ELSE.
      rv_label = iv_fallback_name.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
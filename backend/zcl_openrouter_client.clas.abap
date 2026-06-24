CLASS zcl_openrouter_client DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_balance,
        amount TYPE f,
        error  TYPE string,
      END OF ty_balance.

    CLASS-METHODS get_remaining_credits
      RETURNING
        VALUE(rs_balance) TYPE ty_balance.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_openrouter_data,
        total_credits TYPE f,
        total_usage   TYPE f,
      END OF ty_openrouter_data,
      BEGIN OF ty_openrouter_response,
        data TYPE ty_openrouter_data,
      END OF ty_openrouter_response.
ENDCLASS.

CLASS zcl_openrouter_client IMPLEMENTATION.
  METHOD get_remaining_credits.
    DATA li_client TYPE REF TO if_http_client.
    DATA(lv_status) = 0.
    DATA(lv_response) = ``.
    DATA(ls_response) = VALUE ty_openrouter_response( ).

    IF zcl_icf_handler=>openrouter_api_key IS INITIAL.
      rs_balance-error = `Missing OPENROUTER_API_KEY`.
      RETURN.
    ENDIF.

    TRY.
        cl_http_client=>create_by_url(
          EXPORTING
            url    = zcl_icf_handler=>openrouter_credits_url
          IMPORTING
            client = li_client ).

        li_client->request->set_header_field(
          name  = `accept`
          value = `application/json` ).
        li_client->request->set_header_field(
          name  = `authorization`
          value = |Bearer { zcl_icf_handler=>openrouter_api_key }| ).

        li_client->send( ).
        li_client->receive( ).
        li_client->response->get_status( IMPORTING code = lv_status ).

        IF lv_status <> 200.
          rs_balance-error = |OpenRouter returned HTTP { lv_status }|.
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

        rs_balance-amount = ls_response-data-total_credits - ls_response-data-total_usage.
      CATCH cx_root.
        rs_balance-error = `OpenRouter credits request failed`.
    ENDTRY.
  ENDMETHOD.
ENDCLASS.

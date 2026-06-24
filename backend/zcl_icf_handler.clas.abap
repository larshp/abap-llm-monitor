CLASS zcl_icf_handler DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_http_extension.

    CLASS-DATA openrouter_api_key TYPE string.
    CLASS-DATA openrouter_credits_url TYPE string VALUE `https://openrouter.ai/api/v1/credits`.
ENDCLASS.

CLASS zcl_icf_handler IMPLEMENTATION.
  METHOD if_http_extension~handle_request.
    DATA(path) = server->request->get_header_field( '~path' ).

    CASE path.
      WHEN '/metrics' OR '/metrics.json'.
        WAIT UP TO 1 SECONDS.

        server->response->set_header_field(
          name  = 'content-type'
          value = 'application/json; charset=utf-8' ).
        server->response->set_header_field(
          name  = 'cache-control'
          value = 'no-store' ).
        server->response->set_cdata( /ui2/cl_json=>serialize(
          data        = zcl_provider=>get_metrics( )
          compress    = abap_true
          pretty_name = /ui2/cl_json=>pretty_mode-camel_case ) ).
        server->response->set_status(
          code   = 200
          reason = 'OK' ).
      WHEN OTHERS.
        server->response->set_header_field(
          name  = 'content-type'
          value = 'application/json; charset=utf-8' ).
        server->response->set_cdata( '{"error":"not found"}' ).
        server->response->set_status(
          code   = 404
          reason = 'Not Found' ).
    ENDCASE.
  ENDMETHOD.
ENDCLASS.
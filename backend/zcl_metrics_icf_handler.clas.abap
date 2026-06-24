CLASS zcl_metrics_icf_handler DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_http_extension.
ENDCLASS.

CLASS zcl_metrics_icf_handler IMPLEMENTATION.
  METHOD if_http_extension~handle_request.
    DATA(path) = server->request->get_header_field( '~path' ).

    CASE path.
      WHEN '/metrics' OR '/metrics.json'.
        server->response->set_header_field(
          name  = 'content-type'
          value = 'application/json; charset=utf-8' ).
        server->response->set_header_field(
          name  = 'cache-control'
          value = 'no-store' ).
        server->response->set_cdata( zcl_metrics_provider=>get_metrics_json( ) ).
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
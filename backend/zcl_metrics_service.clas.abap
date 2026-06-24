CLASS zcl_metrics_service DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_http_service_extension.
ENDCLASS.

CLASS zcl_metrics_service IMPLEMENTATION.
  METHOD if_http_service_extension~handle_request.
    response->set_header_field(
      i_name  = 'content-type'
      i_value = 'application/json; charset=utf-8' ).
    response->set_header_field(
      i_name  = 'cache-control'
      i_value = 'no-store' ).
    response->set_text( zcl_metrics_provider=>get_metrics_json( ) ).
  ENDMETHOD.
ENDCLASS.
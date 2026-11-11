CLASS zcl_github_status_client DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_entry,
        label       TYPE string,
        description TYPE string,
        indicator   TYPE string,
        detail      TYPE string,
      END OF ty_entry,
      ty_entries TYPE STANDARD TABLE OF ty_entry WITH EMPTY KEY,
      BEGIN OF ty_status,
        entries TYPE ty_entries,
        error   TYPE string,
      END OF ty_status.

    CLASS-METHODS get_status
      RETURNING
        VALUE(rs_status) TYPE ty_status.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_page_status,
        indicator   TYPE string,
        description TYPE string,
      END OF ty_page_status,
      BEGIN OF ty_component,
        name   TYPE string,
        status TYPE string,
      END OF ty_component,
      ty_components TYPE STANDARD TABLE OF ty_component WITH EMPTY KEY,
      BEGIN OF ty_incident,
        name   TYPE string,
        status TYPE string,
        impact TYPE string,
      END OF ty_incident,
      ty_incidents TYPE STANDARD TABLE OF ty_incident WITH EMPTY KEY,
      BEGIN OF ty_summary,
        status     TYPE ty_page_status,
        components TYPE ty_components,
        incidents  TYPE ty_incidents,
      END OF ty_summary.

    CLASS-METHODS component_entry
      IMPORTING
        is_component    TYPE ty_component
      RETURNING
        VALUE(rs_entry) TYPE ty_entry.

    CLASS-METHODS humanize
      IMPORTING
        iv_value       TYPE string
      RETURNING
        VALUE(rv_text) TYPE string.
ENDCLASS.

CLASS zcl_github_status_client IMPLEMENTATION.
  METHOD get_status.
    DATA li_client TYPE REF TO if_http_client.
    DATA(lv_status) = 0.
    DATA(lv_response) = ``.
    DATA(ls_summary) = VALUE ty_summary( ).

    TRY.
        cl_http_client=>create_by_url(
          EXPORTING
            url    = zcl_env_config=>github_status_url
          IMPORTING
            client = li_client ).

        li_client->request->set_header_field(
          name  = `accept`
          value = `application/json` ).

        li_client->send( ).
        li_client->receive( ).
        li_client->response->get_status( IMPORTING code = lv_status ).

        IF lv_status <> 200.
          rs_status-error = |GitHub status returned HTTP { lv_status }|.
          li_client->close( ).
          RETURN.
        ENDIF.

        lv_response = li_client->response->get_cdata( ).
        li_client->close( ).

        /ui2/cl_json=>deserialize(
          EXPORTING
            json = lv_response
          CHANGING
            data = ls_summary ).
      CATCH cx_root.
        rs_status-error = `GitHub status request failed`.
        RETURN.
    ENDTRY.

    IF ls_summary-status-description IS INITIAL.
      rs_status-error = `GitHub status is not available`.
      RETURN.
    ENDIF.

    APPEND VALUE #(
      label       = `Overall status`
      description = ls_summary-status-description
      indicator   = ls_summary-status-indicator
      detail      = `githubstatus.com` ) TO rs_status-entries.

    " the summary only lists unresolved incidents
    LOOP AT ls_summary-incidents INTO DATA(ls_incident).
      APPEND VALUE #(
        label       = `Incident`
        description = ls_incident-name
        indicator   = ls_incident-impact
        detail      = |{ humanize( ls_incident-status ) }, { ls_incident-impact } impact| ) TO rs_status-entries.
    ENDLOOP.

    LOOP AT ls_summary-components INTO DATA(ls_component) WHERE status <> `operational`.
      APPEND component_entry( ls_component ) TO rs_status-entries.
    ENDLOOP.
  ENDMETHOD.

  METHOD component_entry.
    rs_entry-label = is_component-name.
    rs_entry-description = humanize( is_component-status ).
    rs_entry-detail = `Component`.

    " map component states onto the same scale as the overall indicator
    CASE is_component-status.
      WHEN `degraded_performance`.
        rs_entry-indicator = `minor`.
      WHEN `partial_outage`.
        rs_entry-indicator = `major`.
      WHEN `major_outage`.
        rs_entry-indicator = `critical`.
      WHEN `under_maintenance`.
        rs_entry-indicator = `maintenance`.
      WHEN OTHERS.
        rs_entry-indicator = `minor`.
    ENDCASE.
  ENDMETHOD.

  METHOD humanize.
    rv_text = replace( val = iv_value sub = `_` with = ` ` occ = 0 ).

    IF strlen( rv_text ) > 0.
      rv_text = to_upper( substring( val = rv_text len = 1 ) ) && substring( val = rv_text off = 1 ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.

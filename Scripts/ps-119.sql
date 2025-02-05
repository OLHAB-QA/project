DECLARE
    v_result VARCHAR2(4000);
BEGIN
    copy_table(
        p_source_scheme => 'HR',
        p_target_scheme => 'BACKUP',
        p_list_table    => 'EMPLOYEES,DEPARTMENTS',
        p_copy_data     => TRUE,
        po_result       => v_result
    );
    DBMS_OUTPUT.PUT_LINE(v_result);
END;
/

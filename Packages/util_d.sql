CREATE OR REPLACE PACKAGE util_d AS
    PROCEDURE fire_an_employee(p_employee_id IN NUMBER);
END util_d;
/



CREATE OR REPLACE PACKAGE BODY util_d AS

    
    FUNCTION is_working_time RETURN BOOLEAN IS
        v_day_of_week NUMBER;
        v_hour NUMBER;
    BEGIN
       
        v_day_of_week := TO_NUMBER(TO_CHAR(SYSDATE, 'D'));
       
        v_hour := TO_NUMBER(TO_CHAR(SYSDATE, 'HH24'));

      
        IF v_day_of_week IN (1, 7) OR v_hour < 8 OR v_hour >= 18 THEN
            RETURN FALSE;
        ELSE
            RETURN TRUE;
        END IF;
    END is_working_time;

    -- Процедура звільнення співробітника
    PROCEDURE fire_an_employee(p_employee_id IN NUMBER) IS
        v_first_name employees.first_name%TYPE;
        v_last_name employees.last_name%TYPE;
        v_job_id employees.job_id%TYPE;
        v_department_id employees.department_id%TYPE;
        v_exists NUMBER;
    BEGIN
       
        log_util.log_start(p_proc_name => 'fire_an_employee', p_text => 'Початок процедури звільнення.');

       
        IF NOT is_working_time THEN
            RAISE_APPLICATION_ERROR(-20001, 'Ви можете видаляти співробітника лише в робочий час');
        END IF;

    
        SELECT COUNT(*) INTO v_exists FROM employees WHERE employee_id = p_employee_id;
        IF v_exists = 0 THEN
            RAISE_APPLICATION_ERROR(-20002, 'Переданий співробітник не існує');
        END IF;

       
        SELECT first_name, last_name, job_id, department_id 
        INTO v_first_name, v_last_name, v_job_id, v_department_id
        FROM employees 
        WHERE employee_id = p_employee_id;

       
        INSERT INTO employees_history (history_id, employee_id, first_name, last_name, job_id, department_id, termination_date, reason)
        VALUES (employees_history_seq.NEXTVAL, p_employee_id, v_first_name, v_last_name, v_job_id, v_department_id, SYSDATE, 'Звільнення');

      
        BEGIN
            DELETE FROM employees WHERE employee_id = p_employee_id;
            COMMIT;
        EXCEPTION
            WHEN OTHERS THEN
                log_util.log_error(p_proc_name => 'fire_an_employee', p_sqlerrm => SQLERRM);
                RAISE;
        END;

      
        DBMS_OUTPUT.PUT_LINE('Співробітник ' || v_first_name || ' ' || v_last_name || ', ' || v_job_id || ', ' || v_department_id || ' успішно звільнений.');

       
        log_util.log_finish(p_proc_name => 'fire_an_employee', p_text => 'Процедура звільнення завершена.');
    
    END fire_an_employee;

END util_d;
/

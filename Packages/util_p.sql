CREATE OR REPLACE PACKAGE util_p AS
  PROCEDURE add_employee (
    p_first_name      IN VARCHAR2,
    p_last_name       IN VARCHAR2,
    p_email           IN VARCHAR2,
    p_phone_number    IN VARCHAR2,
    p_hire_date       IN DATE DEFAULT TRUNC(SYSDATE, 'dd'),
    p_job_id          IN VARCHAR2,
    p_salary          IN NUMBER,
    p_commission_pct  IN NUMBER DEFAULT NULL,
    p_manager_id      IN NUMBER DEFAULT 100,
    p_department_id   IN NUMBER
  );
  
  PROCEDURE fire_an_employee(p_employee_id IN NUMBER);
  
END util_p;
/




CREATE OR REPLACE PACKAGE BODY util_p AS
  PROCEDURE add_employee (
    p_first_name      IN VARCHAR2,
    p_last_name       IN VARCHAR2,
    p_email           IN VARCHAR2,
    p_phone_number    IN VARCHAR2,
    p_hire_date       IN DATE DEFAULT TRUNC(SYSDATE, 'dd'),
    p_job_id          IN VARCHAR2,
    p_salary          IN NUMBER,
    p_commission_pct  IN NUMBER DEFAULT NULL,
    p_manager_id      IN NUMBER DEFAULT 100,
    p_department_id   IN NUMBER
  ) IS
    v_employee_id      NUMBER;
    v_min_salary       NUMBER;
    v_max_salary       NUMBER;
    v_job_exists       NUMBER;
    v_department_exists NUMBER;
    v_day_of_week      VARCHAR2(10);
    v_hour             NUMBER;
  BEGIN
     
    log_util.log_start(p_proc_name => 'add_employee', p_text => 'Старт процедури додавання співробітника.');

  
    v_day_of_week := TO_CHAR(p_hire_date, 'DY', 'NLS_DATE_LANGUAGE=ENGLISH');
    v_hour := TO_NUMBER(TO_CHAR(p_hire_date, 'HH24'));

    IF v_day_of_week IN ( 'SAT','SUN') OR v_hour < 8 OR v_hour > 18 THEN
      RAISE_APPLICATION_ERROR(-20001, 'Ви можете додавати нового співробітника лише в робочий час');
    END IF;

    
    SELECT COUNT(*)
    INTO v_job_exists
    FROM JOBS
    WHERE JOB_ID = p_job_id;

    IF v_job_exists = 0 THEN
      RAISE_APPLICATION_ERROR(-20001, 'Введено неіснуючий код посади');
    END IF;

    
    SELECT COUNT(*)
    INTO v_department_exists
    FROM DEPARTMENTS
    WHERE DEPARTMENT_ID = p_department_id;

    IF v_department_exists = 0 THEN
      RAISE_APPLICATION_ERROR(-20001, 'Введено неіснуючий ідентифікатор відділу');
    END IF;

    
    SELECT MIN_SALARY, MAX_SALARY
    INTO v_min_salary, v_max_salary
    FROM JOBS
    WHERE JOB_ID = p_job_id;

    IF p_salary < v_min_salary OR p_salary > v_max_salary THEN
      RAISE_APPLICATION_ERROR(-20001, 'Введено неприпустиму заробітну плату для даного коду посади');
    END IF;

    
    SELECT NVL(MAX(EMPLOYEE_ID), 0) + 1
    INTO v_employee_id
    FROM EMPLOYEES;

    
    BEGIN
      INSERT INTO EMPLOYEES (
        EMPLOYEE_ID, FIRST_NAME, LAST_NAME, EMAIL, PHONE_NUMBER,
        HIRE_DATE, JOB_ID, SALARY, COMMISSION_PCT, MANAGER_ID, DEPARTMENT_ID
      ) VALUES (
        v_employee_id, p_first_name, p_last_name, p_email, p_phone_number,
        p_hire_date, p_job_id, p_salary, p_commission_pct, p_manager_id, p_department_id
      );

      DBMS_OUTPUT.PUT_LINE('Співробітник ' || p_first_name || ', ' || p_last_name || 
                           ', ' || p_job_id || ', ' || p_department_id || ' успішно додано до системи');
    EXCEPTION
      WHEN OTHERS THEN
        log_util.log_error(p_proc_name => 'add_employee', p_sqlerrm => SQLERRM, p_text => 'Помилка при додаванні співробітника.');
        RAISE_APPLICATION_ERROR(-20001, 'Помилка при додаванні співробітника: ' || SQLERRM);
    END;

   
    log_util.log_finish(p_proc_name => 'add_employee', p_text => 'Процедура додавання співробітника завершена успішно.');
  END add_employee;


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
END util_p;
/

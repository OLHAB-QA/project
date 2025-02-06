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
  
  PROCEDURE change_attribute_employee (
    p_employee_id      IN NUMBER,
    p_first_name       IN VARCHAR2 DEFAULT NULL,
    p_last_name        IN VARCHAR2 DEFAULT NULL,
    p_email            IN VARCHAR2 DEFAULT NULL,
    p_phone_number     IN VARCHAR2 DEFAULT NULL,
    p_job_id           IN VARCHAR2 DEFAULT NULL,
    p_salary           IN NUMBER DEFAULT NULL,
    p_commission_pct   IN NUMBER DEFAULT NULL,
    p_manager_id       IN NUMBER DEFAULT NULL,
    p_department_id    IN NUMBER DEFAULT NULL
  );
  
  
    PROCEDURE api_nbu_sync;
   
    FUNCTION get_needed_curr(p_valcode IN VARCHAR2 DEFAULT 'USD',
                             p_date IN DATE DEFAULT SYSDATE) RETURN VARCHAR2;

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
    
PROCEDURE change_attribute_employee (
    p_employee_id      IN NUMBER,
    p_first_name       IN VARCHAR2 DEFAULT NULL,
    p_last_name        IN VARCHAR2 DEFAULT NULL,
    p_email            IN VARCHAR2 DEFAULT NULL,
    p_phone_number     IN VARCHAR2 DEFAULT NULL,
    p_job_id           IN VARCHAR2 DEFAULT NULL,
    p_salary           IN NUMBER DEFAULT NULL,
    p_commission_pct   IN NUMBER DEFAULT NULL,
    p_manager_id       IN NUMBER DEFAULT NULL,
    p_department_id    IN NUMBER DEFAULT NULL
  ) IS
    v_changes_exist BOOLEAN := FALSE;
  BEGIN

    log_util.log_start(p_proc_name => 'change_attribute_employee', p_text => 'Старт процедури зміни атрибутів співробітника.');

    
    IF p_first_name IS NOT NULL OR
       p_last_name IS NOT NULL OR
       p_email IS NOT NULL OR
       p_phone_number IS NOT NULL OR
       p_job_id IS NOT NULL OR
       p_salary IS NOT NULL OR
       p_commission_pct IS NOT NULL OR
       p_manager_id IS NOT NULL OR
       p_department_id IS NOT NULL THEN
      v_changes_exist := TRUE;
    END IF;

  
    IF NOT v_changes_exist THEN
      log_util.log_finish(p_proc_name => 'change_attribute_employee', p_text => 'Жоден атрибут не було передано для оновлення.');
      RAISE_APPLICATION_ERROR(-20001, 'Не передано жодного атрибута для оновлення.');
    END IF;


    BEGIN
      IF p_first_name IS NOT NULL THEN
        UPDATE EMPLOYEES
        SET FIRST_NAME = p_first_name
        WHERE EMPLOYEE_ID = p_employee_id;
      END IF;

      IF p_last_name IS NOT NULL THEN
        UPDATE EMPLOYEES
        SET LAST_NAME = p_last_name
        WHERE EMPLOYEE_ID = p_employee_id;
      END IF;

      IF p_email IS NOT NULL THEN
        UPDATE EMPLOYEES
        SET EMAIL = p_email
        WHERE EMPLOYEE_ID = p_employee_id;
      END IF;

      IF p_phone_number IS NOT NULL THEN
        UPDATE EMPLOYEES
        SET PHONE_NUMBER = p_phone_number
        WHERE EMPLOYEE_ID = p_employee_id;
      END IF;

      IF p_job_id IS NOT NULL THEN
        UPDATE EMPLOYEES
        SET JOB_ID = p_job_id
        WHERE EMPLOYEE_ID = p_employee_id;
      END IF;

      IF p_salary IS NOT NULL THEN
        UPDATE EMPLOYEES
        SET SALARY = p_salary
        WHERE EMPLOYEE_ID = p_employee_id;
      END IF;

      IF p_commission_pct IS NOT NULL THEN
        UPDATE EMPLOYEES
        SET COMMISSION_PCT = p_commission_pct
        WHERE EMPLOYEE_ID = p_employee_id;
      END IF;

      IF p_manager_id IS NOT NULL THEN
        UPDATE EMPLOYEES
        SET MANAGER_ID = p_manager_id
        WHERE EMPLOYEE_ID = p_employee_id;
      END IF;

      IF p_department_id IS NOT NULL THEN
        UPDATE EMPLOYEES
        SET DEPARTMENT_ID = p_department_id
        WHERE EMPLOYEE_ID = p_employee_id;
      END IF;

   
      DBMS_OUTPUT.PUT_LINE('У співробітника з ID ' || p_employee_id || ' успішно оновлені атрибути.');

    EXCEPTION
      WHEN OTHERS THEN
        log_util.log_error(p_proc_name => 'change_attribute_employee', p_sqlerrm => SQLERRM, p_text => 'Помилка при оновленні атрибутів співробітника.');
        RAISE_APPLICATION_ERROR(-20001, 'Помилка при оновленні атрибутів: ' || SQLERRM);
    END;

    
    log_util.log_finish(p_proc_name => 'change_attribute_employee', p_text => 'Процедура завершена успішно.');
  END change_attribute_employee;
    
    
     
     
     
     
    
--SET DEFINE OFF;--
   
    FUNCTION get_needed_curr(p_valcode IN VARCHAR2 DEFAULT 'USD',
                             p_date IN DATE DEFAULT SYSDATE) 
    RETURN VARCHAR2 IS
        v_json VARCHAR2(1000);
        v_date VARCHAR2(15) := TO_CHAR(p_date, 'YYYYMMDD');
    BEGIN
      
        SELECT sys.get_nbu(p_url => 'https://bank.gov.ua/NBUStatService/v1/statdirectory/exchange?valcode=' 
                        || p_valcode || '&date=' || v_date || '&json') 
        INTO v_json
        FROM dual;

        RETURN v_json;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN NULL;  
    END get_needed_curr;

   
    PROCEDURE api_nbu_sync IS
        v_list_currencies VARCHAR2(2000);
        v_currency        VARCHAR2(10);
        v_json            VARCHAR2(1000);
        v_r030            NUMBER;
        v_txt             VARCHAR2(100);
        v_rate            NUMBER;
        v_exchangedate    DATE;
        v_error_message   VARCHAR2(4000);
    BEGIN
        log_util.log_start(p_proc_name => 'api_nbu_sync', p_text => 'Старт оновлення курсу валют.');

       
        BEGIN
            SELECT value_text INTO v_list_currencies
            FROM sys_params
            WHERE param_name = 'list_currencies';

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                v_error_message := 'Параметр list_currencies не знайдено у sys_params.';
                log_util.log_error('api_nbu_sync', SQLERRM, v_error_message);
                RAISE_APPLICATION_ERROR(-20001, v_error_message);
            WHEN OTHERS THEN
                v_error_message := 'Помилка при отриманні list_currencies: ' || SQLERRM;
                log_util.log_error('api_nbu_sync', SQLERRM, v_error_message);
                RAISE_APPLICATION_ERROR(-20002, v_error_message);
        END;

      
        FOR cc IN (SELECT REGEXP_SUBSTR(v_list_currencies, '[^,]+', 1, LEVEL) AS curr
                   FROM DUAL
                   CONNECT BY REGEXP_SUBSTR(v_list_currencies, '[^,]+', 1, LEVEL) IS NOT NULL) LOOP
            BEGIN
               
                v_json := get_needed_curr(cc.curr, SYSDATE);

               
                IF v_json IS NOT NULL THEN
                    SELECT JSON_VALUE(v_json, '$.r030'),
                           JSON_VALUE(v_json, '$.txt'),
                           JSON_VALUE(v_json, '$.rate'),
                           JSON_VALUE(v_json, '$.cc'),
                           TO_DATE(JSON_VALUE(v_json, '$.exchangedate'), 'DD.MM.YYYY')
                    INTO v_r030, v_txt, v_rate, v_currency, v_exchangedate
                    FROM dual;

                   
                    MERGE INTO cur_exchange ce
                    USING (SELECT v_r030 AS r030, v_txt AS txt, v_rate AS rate, v_currency AS cur, v_exchangedate AS exchangedate FROM DUAL) new_data
                    ON (ce.r030 = new_data.r030 AND ce.exchangedate = new_data.exchangedate)
                    WHEN MATCHED THEN
                        UPDATE SET ce.rate = new_data.rate
                    WHEN NOT MATCHED THEN
                        INSERT (r030, txt, rate, cur, exchangedate)
                        VALUES (new_data.r030, new_data.txt, new_data.rate, new_data.cur, new_data.exchangedate);

                    COMMIT;
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    v_error_message := 'Помилка при оновленні курсу для ' || cc.curr || ': ' || SQLERRM;
                    log_util.log_error('api_nbu_sync', SQLERRM, v_error_message);
                    RAISE_APPLICATION_ERROR(-20003, v_error_message);
            END;
        END LOOP;

        log_util.log_finish(p_proc_name => 'api_nbu_sync', p_text => 'Оновлення курсу валют завершено.');
    END api_nbu_sync;

    
END util_p;
/
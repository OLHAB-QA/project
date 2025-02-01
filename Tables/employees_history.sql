CREATE TABLE employees_history (
    history_id NUMBER PRIMARY KEY,
    employee_id NUMBER,
    first_name VARCHAR2(100),
    last_name VARCHAR2(100),
    job_id VARCHAR2(20),
    department_id NUMBER,
    termination_date DATE DEFAULT SYSDATE,
    reason VARCHAR2(500)
);

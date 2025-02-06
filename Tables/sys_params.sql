CREATE TABLE sys_params (
    param_name    VARCHAR2(150) PRIMARY KEY,
    value_date    DATE DEFAULT SYSDATE,
    value_text    VARCHAR2(2000),
    value_number  NUMBER,
    param_descr   VARCHAR2(200)
);

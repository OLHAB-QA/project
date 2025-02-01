BEGIN
  util_p.add_employee(
    p_first_name      => 'Olha',
    p_last_name       => 'Beshota',
    p_email           => 'Olha77@example.com',
    p_phone_number    => '123-456-7890',
    p_hire_date       => SYSDATE,
    p_job_id          => 'FI_ACCOUNT',
    p_salary          => 8000,
    p_commission_pct  => NULL,
    p_manager_id      => 101,
    p_department_id   => 60
  );
END;
/

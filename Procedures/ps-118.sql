
BEGIN
  util_p.change_attribute_employee(
    p_employee_id    => 209,
    p_first_name     => 'test',
    p_last_name      => 'Beshota',
    p_email          => 'olha.beshota@example.com',
    p_salary         => 11000
  );
END;
/
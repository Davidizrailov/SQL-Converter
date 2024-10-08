DECLARE
v_job_titleemployees.job_title%TYPE;
v_avg_salary NUMBER;
v_total_salary NUMBER;
v_employee_count NUMBER;
    CURSOR c_job_titles IS
    SELECT DISTINCT job_title
    FROM employees;
      CURSOR c_employees (p_job_title IN employees.job_title%TYPE) IS
    SELECT salary
    FROM employees
    WHERE job_title = p_job_title;
BEGIN
  DBMS_OUTPUT.PUT_LINE('Job Title' || CHR(9) || 'Average Salary');
  DBMS_OUTPUT.PUT_LINE('-----------------------------------');
    OPEN c_job_titles;
  FETCH c_job_titles INTO v_job_title;
    WHILE c_job_titles%FOUND LOOP
v_total_salary := 0;
v_employee_count := 0;
        OPEN c_employees(v_job_title);
    FETCH c_employees INTO v_avg_salary;
        WHILE c_employees%FOUND LOOP
v_total_salary := v_total_salary + v_avg_salary;
v_employee_count := v_employee_count + 1;
      FETCH c_employees INTO v_avg_salary;
    END LOOP;
        CLOSE c_employees;
        IF v_employee_count> 0 THEN
v_avg_salary := v_total_salary / v_employee_count;
    ELSE
v_avg_salary := 0;
    END IF;
        DBMS_OUTPUT.PUT_LINE(v_job_title || CHR(9) || v_avg_salary);
        FETCH c_job_titles INTO v_job_title;
  END LOOP;
    CLOSE c_job_titles;
END;
/
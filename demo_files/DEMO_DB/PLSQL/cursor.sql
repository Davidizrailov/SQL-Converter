DECLARE
    var_record       employees%ROWTYPE;
    CURSOR cur_test (max_sal NUMBER) IS
        SELECT * FROM employees WHERE salary < max_sal;
BEGIN
    OPEN cur_test(76000);
    LOOP
        FETCH cur_test INTO var_record;
        EXIT WHEN cur_test%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE('Name: ' || var_record.first_name || chr(9)||' salary: '
            || var_record.salary);
    END LOOP;
    CLOSE cur_test;
END;
/
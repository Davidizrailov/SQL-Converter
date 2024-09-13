CREATE OR REPLACE PACKAGE jta_employee_ops IS
    PROCEDURE sunday_check (
        p_staff_id IN staff.staff_id%TYPE,
        p_month IN DATE,
        p_sundays OUT NOCOPY INTEGER,
        p_available OUT NOCOPY BOOLEAN
    );
    
    PROCEDURE payout (
        p_staff_id IN staff.staff_id%TYPE,
        p_begin_date IN DATE,
        p_end_date IN DATE,
        p_gross_pay OUT NOCOPY payroll.gross_pay%TYPE,
        p_net_pay OUT NOCOPY payroll.net_pay%TYPE,
        p_hlt OUT NOCOPY payroll.hlt_surcharge_deduction%TYPE,
        p_nat OUT NOCOPY payroll.nat_insurance_deduction%TYPE,
        p_deductions OUT NOCOPY payroll.net_pay%TYPE
    );
    
    FUNCTION get_name (
        p_staff_id staff.staff_id%TYPE
    ) RETURN VARCHAR2;
    
    PROCEDURE get_hours (
        p_staff_id IN staff.staff_id%TYPE,
        start_date IN DATE,
        end_date IN DATE,
        basic OUT NOCOPY INTEGER,
        overtime OUT NOCOPY INTEGER,
        doubletime OUT NOCOPY INTEGER
    );
END jta_employee_ops;
/

CREATE OR REPLACE PACKAGE BODY jta_employee_ops IS
    
    PROCEDURE sunday_check (
        p_staff_id IN staff.staff_id%TYPE,
        p_month IN DATE,
        p_sundays OUT NOCOPY INTEGER,
        p_available OUT NOCOPY BOOLEAN
    )
    IS
        -- work days for this staff memeber, for month begin to end
        CURSOR work_days IS
            SELECT * FROM work_hours 
            WHERE staff_id = p_staff_id
            AND work_date BETWEEN TRUNC(p_month, 'MONTH') 
            AND add_months(TRUNC(p_month, 'MONTH'), 1) -1;
    BEGIN

        p_sundays := 0;
        p_available := TRUE;
        
        -- find sundays for the month
        FOR work_day IN work_days LOOP
            IF to_char(work_day.work_date, 'd') = '1' THEN
                p_sundays := p_sundays + 1;
            END IF;
        END LOOP;
        
        -- check if available to work another sunday
        IF p_sundays >= 2 THEN
            p_available := FALSE;
        END IF;
        
    EXCEPTION
        WHEN no_data_found THEN
            p_sundays := 0;
            p_available := TRUE;
        WHEN OTHERS THEN
            jta_error.log_error(SQLCODE, SQLERRM);
            p_sundays := NULL;
            p_available := NULL;
    END sunday_check;

    PROCEDURE payout (
        p_staff_id IN staff.staff_id%TYPE,
        p_begin_date IN DATE,
        p_end_date IN DATE,
        p_gross_pay OUT NOCOPY payroll.gross_pay%TYPE,
        p_net_pay OUT NOCOPY payroll.net_pay%TYPE,
        p_hlt OUT NOCOPY payroll.hlt_surcharge_deduction%TYPE,
        p_nat OUT NOCOPY payroll.nat_insurance_deduction%TYPE,
        p_deductions OUT NOCOPY payroll.net_pay%TYPE
    )
    IS 
    BEGIN 
        
        -- select the sum of gross and net pay from payroll
        -- if date_recieved is null, that means the pay hasn't been collected yet
        SELECT SUM(gross_pay), SUM(net_pay), SUM(hlt_surcharge_deduction), SUM(nat_insurance_deduction)
        INTO p_gross_pay, p_net_pay, p_hlt, p_nat
        FROM payroll
        WHERE staff_id = p_staff_id
        AND date_staff_received BETWEEN p_begin_date AND p_end_date;
        
        -- calculate deductions
        p_deductions := p_hlt + p_nat;
        
    EXCEPTION 
        WHEN no_data_found THEN
            -- staff didn't work? doesn't exist? 
            p_gross_pay := 0;
            p_net_pay := 0;
            p_deductions := 0;
            -- no need worry about too many rows because select uses aggregate function
        WHEN OTHERS THEN
            jta_error.log_error(SQLCODE, SQLERRM);
            p_gross_pay := NULL;
            p_net_pay := NULL;
            p_deductions := NULL;
    END payout;

    FUNCTION get_name (
        p_staff_id staff.staff_id%TYPE
    ) RETURN VARCHAR2
    IS 
        v_return VARCHAR2(100);
    BEGIN
        SELECT first_name || ' ' || last_name INTO v_return
        FROM staff WHERE staff_id = p_staff_id;
        
        RETURN v_return;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 'Unknown';
    END get_name;

    PROCEDURE get_hours (
        p_staff_id IN staff.staff_id%TYPE,
        start_date IN DATE,
        end_date IN DATE,
        basic OUT NOCOPY INTEGER,
        overtime OUT NOCOPY INTEGER,
        doubletime OUT NOCOPY INTEGER
    )
    IS
    BEGIN
        
        basic := 0;
        overtime := 0;
        doubletime := 0;
        
        SELECT nvl(SUM(hours_worked), 0) INTO doubletime
            FROM work_hours
            WHERE work_date BETWEEN start_date AND end_date 
            AND staff_id = p_staff_id 
            AND to_char(work_date, 'd') = '1';
            
        SELECT nvl(SUM(hours_worked), 0) INTO basic
            FROM work_hours
            WHERE work_date BETWEEN start_date AND end_date 
            AND staff_id = p_staff_id 
            AND to_char(work_date, 'd') != '1';
        
        IF basic > 40 THEN
            overtime := basic - 40;
            basic := 40;
        END IF;
            
    -- excpetions will be handled in called procedure
    END get_hours;

END jta_employee_ops;
/

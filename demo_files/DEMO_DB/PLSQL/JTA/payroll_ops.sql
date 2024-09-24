CREATE OR REPLACE PACKAGE jta_payroll_ops IS
    PROCEDURE process_payroll (
        p_date IN DATE
    );
    
    PROCEDURE get_hours (
        p_staff_id IN staff.staff_id%TYPE,
        start_date IN DATE,
        end_date IN DATE,
        basic OUT NOCOPY INTEGER,
        overtime OUT NOCOPY INTEGER,
        doubletime OUT NOCOPY INTEGER
    );
END jta_payroll_ops;

CREATE OR REPLACE PACKAGE BODY jta_payroll_ops IS
    PROCEDURE process_payroll (
        p_date IN DATE
    )
    IS
    
        -- date range is Sunday to Sat for this day (friday)
        v_start_date DATE := TRUNC(p_date, 'DAY');
        v_end_date DATE := v_start_date + 6 
            + numtodsinterval(23, 'hour')
            + numtodsinterval(59, 'minute')
            + numtodsinterval(59, 'second'); 
        
        -- gets a list of staff_ids for workers who worked for the week    
        CURSOR c_staff_worked 
            IS SELECT DISTINCT staff_id FROM work_hours
            WHERE work_date BETWEEN v_start_date AND v_end_date
            ORDER BY staff_id;
        
        doubletime payroll.hours_doubletime%TYPE;
        overtime payroll.hours_overtime%TYPE;
        basic payroll.hours_basic%TYPE;
        payrate staff.wage_rate%TYPE;
        gross_pay payroll.gross_pay%TYPE;
        nat_insurance_deduction payroll.nat_insurance_deduction%TYPE;
        hlt_surcharge_deduction payroll.hlt_surcharge_deduction%TYPE;
        net_pay payroll.net_pay%TYPE;
        
        v_count INTEGER := 0;
        
    BEGIN
    
        --dbms_output.put_line(to_char(v_start_date, 'yyyy-Mon-dd, HH24:MI:SS'));
        --dbms_output.put_line(to_char(v_end_date, 'yyyy-Mon-dd, HH24:MI:SS'));
    
       -- note that the procedure essentially do nothing if there are no work data for this week 
        
        -- delete rows from payroll table if they already exist with current dates
        DELETE FROM payroll WHERE payroll.start_date = v_start_date AND payroll.end_date = v_end_date;
        
        -- for each staff that worked this week
        FOR current_staff IN c_staff_worked LOOP
        
            -- get the hours each staff member worked for
            get_hours(current_staff.staff_id, v_start_date, v_end_date, basic, overtime, doubletime);
            -- get staff pay rate
            SELECT wage_rate INTO payrate FROM staff WHERE staff_id = current_staff.staff_id;
            -- calculate and save gross pay
            gross_pay := (basic * payrate) + (overtime * payrate * 1.5) + (doubletime * payrate * 2);
            -- calculate and save deductions
            nat_insurance_deduction := ROUND((gross_pay * nat_insurance_rate) / 3, 2);
            hlt_surcharge_deduction := ROUND((gross_pay * hlt_surcharge_rate), 2);
            -- calculate and save net pay
            net_pay := gross_pay - (nat_insurance_deduction + hlt_surcharge_deduction); 
            
            -- insert new row into payroll table
            INSERT INTO payroll ( 
                payroll_id, staff_id, start_date, end_date, 
                hours_basic, hours_overtime, hours_doubletime, 
                basic_pay_rate, gross_pay, 
                nat_insurance_deduction, hlt_surcharge_deduction, 
                net_pay)
            VALUES (
                payroll_id_seq.NEXTVAL, current_staff.staff_id, v_start_date, v_end_date,
                basic, overtime, doubletime,
                payrate, gross_pay,
                nat_insurance_deduction, hlt_surcharge_deduction, 
                net_pay);
            
                v_count := v_count + 1;
        END LOOP;
        
        IF v_count > 0 THEN
            COMMIT; -- commit when done and only when rows modified
        ELSE 
            -- this exception is caught but not logged since it is trivial
            jta_error.throw(-20201, 'There was no work hours recorded for this week: '
                || to_char(v_start_date, 'yyyy-Mon-dd, HH24:MI:SS') || ' to '
                || to_char(v_end_date, 'yyyy-Mon-dd, HH24:MI:SS'));
        END IF;
        
    EXCEPTION
        WHEN jta_error.invalid_input THEN
            jta_error.show_in_console(SQLCODE, SQLERRM);
            ROLLBACK;
        WHEN OTHERS THEN
            -- all OTHER exceptions will be logged into error table...
            jta_error.log_error(SQLCODE, SQLERRM);  
            ROLLBACK;
    END process_payroll;

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
END jta_payroll_ops;
/
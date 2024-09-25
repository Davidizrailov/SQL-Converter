CREATE OR REPLACE PACKAGE jta_financial_ops IS
    PROCEDURE process_payroll (
        p_date IN DATE
    );

    PROCEDURE get_profits_for (
        p_start_date IN DATE,
        p_end_date IN DATE,
        p_goods_sold OUT NOCOPY NUMBER,
        p_gross_gain OUT NOCOPY NUMBER,
        p_costs OUT NOCOPY NUMBER,
        p_net_gain OUT NOCOPY NUMBER
    );
    
    FUNCTION get_money_inflow (
        p_location_id locations.location_id%TYPE,
        p_start_date DATE,
        p_end_date DATE,
        p_type VARCHAR2 := 'cash'
    ) RETURN cashier_drawer_assignments.cash_amount_start%TYPE;
END jta_financial_ops;
/

CREATE OR REPLACE PACKAGE BODY jta_financial_ops IS
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
    
        PROCEDURE get_profits_for (
        p_start_date IN DATE,
        p_end_date IN DATE,
        p_goods_sold OUT NOCOPY NUMBER,
        p_gross_gain OUT NOCOPY NUMBER,
        p_costs OUT NOCOPY NUMBER,
        p_net_gain OUT NOCOPY NUMBER
    )
    IS
    BEGIN
        -- complex query to get values
        -- this is actually more efficient that using several cursors
        WITH avg_cost AS (
            SELECT
                bi.bill_line_id,
                bi.quantity AS "Quantity",
                bi.quantity * bi.price_rate AS "Gross Gain",
                cb.date_time_created AS "Date",
                ( SELECT average_cost_per_unit 
                    FROM cost_sales_tracker
                    WHERE date_time = (SELECT MAX(date_time)
                    FROM cost_sales_tracker
                    WHERE cb.date_time_created >= date_time AND bi.product_id = product_id)  
                ) AS "Average Cost"
            FROM billed_items bi JOIN customer_bills cb ON (cb.bill_id = bi.bill_id)
        ),
        total_cost AS (
              SELECT 
                  bi.bill_line_id,
                  bi.quantity * av."Average Cost" AS "Cost"
              FROM billed_items bi JOIN avg_cost av ON (bi.bill_line_id = av.bill_line_id)
        ),
        net_gain AS (
              SELECT  
                  av.bill_line_id,
                  av."Gross Gain" - co."Cost" AS "Net Gain"
              FROM avg_cost av JOIN total_cost co ON (av.bill_line_id = co.bill_line_id)
        )
        SELECT  
            SUM(av."Quantity"), SUM(av."Gross Gain"), SUM(co."Cost"), SUM(ng."Net Gain") 
            INTO p_goods_sold, p_gross_gain, p_costs, p_net_gain
        FROM avg_cost av JOIN total_cost co ON (av.bill_line_id = co.bill_line_id)
        JOIN net_gain ng ON (ng.bill_line_id = av.bill_line_id)
        WHERE av."Date" BETWEEN p_start_date AND p_end_date;

    EXCEPTION
        WHEN OTHERS THEN
            -- all exceptions will be logged into error table...
            jta_error.log_error(SQLCODE, SQLERRM);   
            p_goods_sold := NULL;
            p_gross_gain := NULL;
            p_costs := NULL;
            p_net_gain := NULL;
    END get_profits_for;

    FUNCTION get_money_inflow (
        p_location_id locations.location_id%TYPE,
        p_start_date DATE,
        p_end_date DATE,
        p_type VARCHAR2 := 'cash'
    ) RETURN cashier_drawer_assignments.cash_amount_start%TYPE
    IS 
        v_cash_flow cashier_drawer_assignments.cash_amount_start%TYPE;
        v_location locations.location_id%TYPE;
    BEGIN
    
        BEGIN
            SELECT location_id INTO v_location
            FROM locations
            where location_id = p_location_id;
        EXCEPTION
            WHEN no_data_found THEN
                jta_error.throw(-20201, 'location does not exist');
        END;
        
        
        IF p_type = 'cash' THEN
            SELECT SUM(cash_amount_end) INTO v_cash_flow 
            FROM cashier_drawer_assignments cda
            JOIN cashier_stations cs ON (cs.station_id = cda.station_id)
            WHERE TRUNC(cda.start_time, 'dd') BETWEEN p_start_date AND p_end_date
            AND cs.location_id = p_location_id;
        ELSIF p_type = 'non-cash' THEN
            SELECT SUM(non_cash_tender) INTO v_cash_flow
            FROM cashier_drawer_assignments cda
            JOIN cashier_stations cs ON (cs.station_id = cda.station_id)
            WHERE TRUNC(cda.start_time, 'dd') BETWEEN p_start_date AND p_end_date
            AND cs.location_id = p_location_id;
        ELSE
            jta_error.throw(-20201, 'invalid type, valid types: cash, non-cash');
        END IF;
    
    RETURN v_cash_flow;
    
    EXCEPTION
        
        WHEN no_data_found THEN
            -- no need to log an error
            -- this means that there was no gain for that day or payment type
            RETURN 0;
        WHEN jta_error.invalid_input THEN
            -- no need to log error, will output something to console for us to see
            jta_error.show_in_console(SQLCODE, SQLERRM);
            RETURN NULL;
        WHEN OTHERS THEN
            -- all other exceptions will be logged into error table...
            jta_error.log_error(SQLCODE, SQLERRM);  
            -- return null instead of zero because of fail
            RETURN NULL;
    END get_money_inflow;

END jta_financial_ops;
/
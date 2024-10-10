```python
CREATE OR REPLACE PROCEDURE process_payroll(p_date DATE)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'run_process_payroll'
AS
$$
from snowflake.snowpark import Session
from snowflake.snowpark.functions import col, trunc
from datetime import timedelta

def run_process_payroll(session: Session, p_date: str):
    try:
        v_start_date = session.sql(f"SELECT TRUNC('{p_date}'::TIMESTAMP, 'DAY')").collect()[0][0]
        v_end_date = v_start_date + timedelta(days=6, hours=23, minutes=59, seconds=59)
        
        session.sql(f"DELETE FROM payroll WHERE start_date = '{v_start_date}' AND end_date = '{v_end_date}'").collect()
        
        staff_worked = session.sql(f"""
            SELECT DISTINCT staff_id FROM work_hours
            WHERE work_date BETWEEN '{v_start_date}' AND '{v_end_date}'
            ORDER BY staff_id
        """).collect()
        
        v_count = 0
        
        for staff in staff_worked:
            staff_id = staff['STAFF_ID']
            
            hours = session.call("get_hours", staff_id, v_start_date, v_end_date).collect()
            basic = hours[0]['BASIC']
            overtime = hours[0]['OVERTIME']
            doubletime = hours[0]['DOUBLETIME']
            
            payrate = session.sql(f"SELECT wage_rate FROM staff WHERE staff_id = {staff_id}").collect()[0][0]
            
            gross_pay = (basic * payrate) + (overtime * payrate * 1.5) + (doubletime * payrate * 2)
            nat_insurance_deduction = round((gross_pay * session.sql("SELECT nat_insurance_rate FROM some_table").collect()[0][0]) / 3, 2)
            hlt_surcharge_deduction = round(gross_pay * session.sql("SELECT hlt_surcharge_rate FROM some_table").collect()[0][0], 2)
            net_pay = gross_pay - (nat_insurance_deduction + hlt_surcharge_deduction)
            
            session.sql(f"""
                INSERT INTO payroll (
                    payroll_id, staff_id, start_date, end_date, 
                    hours_basic, hours_overtime, hours_doubletime, 
                    basic_pay_rate, gross_pay, 
                    nat_insurance_deduction, hlt_surcharge_deduction, 
                    net_pay
                )
                VALUES (
                    payroll_id_seq.NEXTVAL, {staff_id}, '{v_start_date}', '{v_end_date}',
                    {basic}, {overtime}, {doubletime},
                    {payrate}, {gross_pay},
                    {nat_insurance_deduction}, {hlt_surcharge_deduction}, 
                    {net_pay}
                )
            """).collect()
            
            v_count += 1

        if v_count > 0:
            session.sql("COMMIT").collect()
        else:
            raise ValueError(f"There was no work hours recorded for this week: {v_start_date} to {v_end_date}")

    except Exception as e:
        session.sql("ROLLBACK").collect()
        session.sql(f"INSERT INTO error_log (error_code, error_message) VALUES ({e.args[0]}, '{e.args[1]}')").collect()
        return "Error Occurred"

    return "Payroll Processed Successfully"
$$;

CALL process_payroll('2023-01-06');
```

```python
CREATE OR REPLACE PROCEDURE get_profits_for(p_start_date DATE, p_end_date DATE)
RETURNS TABLE(goods_sold NUMBER, gross_gain NUMBER, costs NUMBER, net_gain NUMBER)
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'run_get_profits_for'
AS
$$
from snowflake.snowpark import Session

def run_get_profits_for(session: Session, p_start_date: str, p_end_date: str):
    try:
        result = session.sql(f"""
            WITH avg_cost AS (
                SELECT
                    bi.bill_line_id,
                    bi.quantity AS Quantity,
                    bi.quantity * bi.price_rate AS Gross_Gain,
                    cb.date_time_created AS Date,
                    (SELECT average_cost_per_unit 
                     FROM cost_sales_tracker
                     WHERE date_time = (SELECT MAX(date_time)
                     FROM cost_sales_tracker
                     WHERE cb.date_time_created >= date_time AND bi.product_id = product_id)) AS Average_Cost
                FROM billed_items bi
                JOIN customer_bills cb ON (cb.bill_id = bi.bill_id)
            ),
            total_cost AS (
                SELECT 
                    bi.bill_line_id,
                    bi.quantity * av.Average_Cost AS Cost
                FROM billed_items bi
                JOIN avg_cost av ON (bi.bill_line_id = av.bill_line_id)
            ),
            net_gain AS (
                SELECT  
                    av.bill_line_id,
                    av.Gross_Gain - co.Cost AS Net_Gain
                FROM avg_cost av
                JOIN total_cost co ON (av.bill_line_id = co.bill_line_id)
            )
            SELECT  
                SUM(av.Quantity), SUM(av.Gross_Gain), SUM(co.Cost), SUM(ng.Net_Gain)
            FROM avg_cost av
            JOIN total_cost co ON (av.bill_line_id = co.bill_line_id)
            JOIN net_gain ng ON (ng.bill_line_id = av.bill_line_id)
            WHERE av.Date BETWEEN '{p_start_date}' AND '{p_end_date}'
        """).collect()

        if result:
            return result[0]
        else:
            return (None, None, None, None)

    except Exception as e:
        session.sql(f"INSERT INTO error_log (error_code, error_message) VALUES ({e.args[0]}, '{e.args[1]}')").collect()
        return (None, None, None, None)
$$;

CALL get_profits_for('2023-01-01', '2023-01-31');
```

```python
CREATE OR REPLACE FUNCTION get_money_inflow(p_location_id INT, p_start_date DATE, p_end_date DATE, p_type STRING DEFAULT 'cash')
RETURNS FLOAT
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'run_get_money_inflow'
AS
$$
from snowflake.snowpark import Session

def run_get_money_inflow(session: Session, p_location_id: int, p_start_date: str, p_end_date: str, p_type: str):
    try:
        v_location = session.sql(f"SELECT location_id FROM locations WHERE location_id = {p_location_id}").collect()
        if not v_location:
            raise ValueError('Location does not exist')

        if p_type == 'cash':
            cash_flow = session.sql(f"""
                SELECT SUM(cash_amount_end) FROM cashier_drawer_assignments cda
                JOIN cashier_stations cs ON (cs.station_id = cda.station_id)
                WHERE TRUNC(cda.start_time, 'dd') BETWEEN '{p_start_date}' AND '{p_end_date}'
                AND cs.location_id = {p_location_id}
            """).collect()[0][0]
        elif p_type == 'non-cash':
            cash_flow = session.sql(f"""
                SELECT SUM(non_cash_tender) FROM cashier_drawer_assignments cda
                JOIN cashier_stations cs ON (cs.station_id = cda.station_id)
                WHERE TRUNC(cda.start_time, 'dd') BETWEEN '{p_start_date}' AND '{p_end_date}'
                AND cs.location_id = {p_location_id}
            """).collect()[0][0]
        else:
            raise ValueError('Invalid type, valid types: cash, non-cash')

        return cash_flow if cash_flow else 0

    except Exception as e:
        session.sql(f"INSERT INTO error_log (error_code, error_message) VALUES ({e.args[0]}, '{e.args[1]}')").collect()
        return None
$$;

SELECT get_money_inflow(1, '2023-01-01', '2023-01-31', 'cash');
```
```python
CREATE OR REPLACE PROCEDURE process_payroll(p_date DATE)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'process_payroll_handler'
AS
$$
import snowflake.snowpark as snowpark
from snowflake.snowpark.functions import col, sum as snow_sum, to_date, date_trunc, dateadd
from datetime import datetime, timedelta

def process_payroll_handler(session: snowpark.Session, p_date: datetime):
    try:
        v_start_date = date_trunc('WEEK', p_date)
        v_end_date = dateadd('SECOND', 86399, dateadd('DAY', 6, v_start_date))
        
        session.sql(f"DELETE FROM payroll WHERE start_date = '{v_start_date}' AND end_date = '{v_end_date}'").collect()
        
        staff_worked = session.sql(f"SELECT DISTINCT staff_id FROM work_hours WHERE work_date BETWEEN '{v_start_date}' AND '{v_end_date}' ORDER BY staff_id").collect()
        
        v_count = 0
        
        for staff in staff_worked:
            current_staff_id = staff['STAFF_ID']
            basic = 0
            overtime = 0
            doubletime = 0
            
            doubletime = session.sql(f"""
                SELECT COALESCE(SUM(hours_worked), 0) AS doubletime
                FROM work_hours
                WHERE work_date BETWEEN '{v_start_date}' AND '{v_end_date}'
                AND staff_id = {current_staff_id}
                AND DAYOFWEEK(work_date) = 1
            """).collect()[0]['DOUBLETIME']
            
            basic = session.sql(f"""
                SELECT COALESCE(SUM(hours_worked), 0) AS basic
                FROM work_hours
                WHERE work_date BETWEEN '{v_start_date}' AND '{v_end_date}'
                AND staff_id = {current_staff_id}
                AND DAYOFWEEK(work_date) != 1
            """).collect()[0]['BASIC']
            
            if basic > 40:
                overtime = basic - 40
                basic = 40
            
            payrate = session.sql(f"SELECT wage_rate FROM staff WHERE staff_id = {current_staff_id}").collect()[0]['WAGE_RATE']
            gross_pay = (basic * payrate) + (overtime * payrate * 1.5) + (doubletime * payrate * 2)
            nat_insurance_deduction = round((gross_pay * session.sql("SELECT nat_insurance_rate FROM system_values").collect()[0]['NAT_INSURANCE_RATE']) / 3, 2)
            hlt_surcharge_deduction = round((gross_pay * session.sql("SELECT hlt_surcharge_rate FROM system_values").collect()[0]['HLT_SURCHARGE_RATE']), 2)
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
                    (SELECT COALESCE(MAX(payroll_id), 0) + 1 FROM payroll), {current_staff_id}, '{v_start_date}', '{v_end_date}',
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
            raise Exception('No work hours recorded for this week')
    
    except Exception as e:
        session.sql("ROLLBACK").collect()
        return str(e)
    
    return "Process completed successfully"

$$;

CALL process_payroll(CURRENT_DATE());
```
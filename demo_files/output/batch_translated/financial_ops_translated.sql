```sql
CREATE OR REPLACE PROCEDURE process_payroll(p_date DATE)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'process_payroll_handler'
AS
$$
import snowflake.snowpark as snowpark
from snowflake.snowpark.functions import col, lit
from datetime import datetime, timedelta

def process_payroll_handler(session: snowpark.Session, p_date: datetime) -> str:
    v_start_date = p_date - timedelta(days=p_date.weekday())
    v_end_date = v_start_date + timedelta(days=6, hours=23, minutes=59, seconds=59)
    
    c_staff_worked = session.sql(f"""
        SELECT DISTINCT staff_id FROM work_hours
        WHERE work_date BETWEEN '{v_start_date}' AND '{v_end_date}'
        ORDER BY staff_id
    """).collect()
    
    v_count = 0
    
    session.sql(f"""
        DELETE FROM payroll WHERE start_date = '{v_start_date}' AND end_date = '{v_end_date}'
    """).collect()
    
    for row in c_staff_worked:
        current_staff_id = row['STAFF_ID']
        
        hours = session.call('get_hours', current_staff_id, v_start_date, v_end_date).collect()
        basic, overtime, doubletime = hours[0]['BASIC'], hours[0]['OVERTIME'], hours[0]['DOUBLETIME']
        
        payrate = session.sql(f"""
            SELECT wage_rate FROM staff WHERE staff_id = {current_staff_id}
        """).collect()[0]['WAGE_RATE']
        
        gross_pay = (basic * payrate) + (overtime * payrate * 1.5) + (doubletime * payrate * 2)
        nat_insurance_deduction = round((gross_pay * session.sql("SELECT nat_insurance_rate FROM rates").collect()[0]['NAT_INSURANCE_RATE']) / 3, 2)
        hlt_surcharge_deduction = round((gross_pay * session.sql("SELECT hlt_surcharge_rate FROM rates").collect()[0]['HLT_SURCHARGE_RATE']), 2)
        net_pay = gross_pay - (nat_insurance_deduction + hlt_surcharge_deduction)
        
        session.sql(f"""
            INSERT INTO payroll (payroll_id, staff_id, start_date, end_date, hours_basic, hours_overtime, hours_doubletime, basic_pay_rate, gross_pay, nat_insurance_deduction, hlt_surcharge_deduction, net_pay)
            VALUES (payroll_id_seq.NEXTVAL, {current_staff_id}, '{v_start_date}', '{v_end_date}', {basic}, {overtime}, {doubletime}, {payrate}, {gross_pay}, {nat_insurance_deduction}, {hlt_surcharge_deduction}, {net_pay})
        """).collect()
        
        v_count += 1
    
    if v_count > 0:
        session.sql("COMMIT").collect()
        return "Payroll processed successfully."
    else:
        return f"No work hours recorded for the week: {v_start_date} to {v_end_date}"

$$;

CALL process_payroll('2023-10-06');
```
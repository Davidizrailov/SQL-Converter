```sql
CREATE OR REPLACE PROCEDURE process_payroll(p_date DATE)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'process_payroll_handler'
AS
$$
from snowflake.snowpark import Session
from snowflake.snowpark.functions import col, lit, sum as snowflake_sum
from datetime import datetime, timedelta

def get_hours(session, p_staff_id, start_date, end_date):
    basic = 0
    overtime = 0
    doubletime = 0

    doubletime_hours = session.table("work_hours") \
        .filter((col("work_date") >= lit(start_date)) & (col("work_date") <= lit(end_date)) & (col("staff_id") == lit(p_staff_id)) & (col("work_date").dt.dayofweek == 6)) \
        .select(snowflake_sum("hours_worked").alias("doubletime")).collect()[0]["DOUBLETIME"]

    basic_hours = session.table("work_hours") \
        .filter((col("work_date") >= lit(start_date)) & (col("work_date") <= lit(end_date)) & (col("staff_id") == lit(p_staff_id)) & (col("work_date").dt.dayofweek != 6)) \
        .select(snowflake_sum("hours_worked").alias("basic")).collect()[0]["BASIC"]

    if basic_hours > 40:
        overtime = basic_hours - 40
        basic_hours = 40

    return basic_hours, overtime, doubletime_hours

def process_payroll_handler(session: Session, p_date: datetime):
    v_start_date = p_date - timedelta(days=p_date.weekday())
    v_end_date = v_start_date + timedelta(days=6, hours=23, minutes=59, seconds=59)

    c_staff_worked = session.table("work_hours") \
        .filter((col("work_date") >= lit(v_start_date)) & (col("work_date") <= lit(v_end_date))) \
        .select("staff_id").distinct().collect()

    v_count = 0

    session.sql(f"DELETE FROM payroll WHERE start_date = '{v_start_date}' AND end_date = '{v_end_date}'").collect()

    for staff in c_staff_worked:
        current_staff_id = staff["STAFF_ID"]
        basic, overtime, doubletime = get_hours(session, current_staff_id, v_start_date, v_end_date)

        payrate = session.table("staff").filter(col("staff_id") == lit(current_staff_id)).select("wage_rate").collect()[0]["WAGE_RATE"]

        gross_pay = (basic * payrate) + (overtime * payrate * 1.5) + (doubletime * payrate * 2)
        nat_insurance_deduction = round((gross_pay * session.sql("SELECT nat_insurance_rate FROM rates").collect()[0]["NAT_INSURANCE_RATE"]) / 3, 2)
        hlt_surcharge_deduction = round((gross_pay * session.sql("SELECT hlt_surcharge_rate FROM rates").collect()[0]["HLT_SURCHARGE_RATE"]), 2)
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
        raise Exception(f"There was no work hours recorded for this week: {v_start_date} to {v_end_date}")

$$;

CALL process_payroll('2023-10-06'::DATE);
```
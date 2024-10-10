CREATE OR REPLACE PROCEDURE jta_employee_ops()
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'main'
AS
$$
import snowflake.snowpark as snowpark
from snowflake.snowpark.functions import col, date_trunc, dayofweek, sum, when
from datetime import datetime, timedelta

def sunday_check(session, staff_id, month_year):
    try:
        df = session.table("payroll").filter((col("STAFF_ID") == staff_id) & 
                                             (date_trunc('MONTH', col("WORK_DATE")) == month_year) & 
                                             (dayofweek(col("WORK_DATE")) == 1))
        sunday_count = df.count()
        return "Available" if sunday_count < 2 else "Not Available"
    except snowpark.exceptions.SnowparkSQLException as e:
        if "no data" in str(e).lower():
            return "No data found"
        else:
            return f"Error: {str(e)}"

def payout(session, staff_id, start_date, end_date):
    try:
        df = session.table("payroll").filter((col("STAFF_ID") == staff_id) & 
                                             (col("WORK_DATE").between(start_date, end_date)))
        result = df.agg(
            sum("BASIC_HOURS").alias("TOTAL_BASIC_HOURS"),
            sum("OT_HOURS").alias("TOTAL_OT_HOURS"),
            sum("SUNDAY_HOURS").alias("TOTAL_SUNDAY_HOURS")
        ).collect()[0]
        
        gross_pay = (result["TOTAL_BASIC_HOURS"] * 10 + 
                     result["TOTAL_OT_HOURS"] * 15 + 
                     result["TOTAL_SUNDAY_HOURS"] * 20)
        deductions = gross_pay * 0.2
        net_pay = gross_pay - deductions
        
        return f"Gross Pay: {gross_pay}, Net Pay: {net_pay}, Deductions: {deductions}"
    except snowpark.exceptions.SnowparkSQLException as e:
        if "no data" in str(e).lower():
            return "No data found"
        else:
            return f"Error: {str(e)}"

def get_name(session, staff_id):
    try:
        df = session.table("employees").filter(col("STAFF_ID") == staff_id)
        result = df.select(col("FIRST_NAME") + " " + col("LAST_NAME")).collect()
        return result[0][0] if result else "Unknown"
    except Exception:
        return "Unknown"

def get_hours(session, staff_id, start_date, end_date):
    try:
        df = session.table("payroll").filter((col("STAFF_ID") == staff_id) & 
                                             (col("WORK_DATE").between(start_date, end_date)))
        result = df.agg(
            sum(when(dayofweek(col("WORK_DATE")) == 1, col("HOURS_WORKED"), 0)).alias("SUNDAY_HOURS"),
            sum(when(dayofweek(col("WORK_DATE")) != 1, col("HOURS_WORKED"), 0)).alias("NON_SUNDAY_HOURS")
        ).collect()[0]
        
        sunday_hours = result["SUNDAY_HOURS"]
        non_sunday_hours = result["NON_SUNDAY_HOURS"]
        basic_hours = min(non_sunday_hours, 40)
        overtime_hours = max(non_sunday_hours - 40, 0)
        
        return f"Basic Hours: {basic_hours}, Overtime Hours: {overtime_hours}, Double-time Hours: {sunday_hours}"
    except snowpark.exceptions.SnowparkSQLException as e:
        if "no data" in str(e).lower():
            return "No data found"
        else:
            return f"Error: {str(e)}"

def main(session: snowpark.Session):
    staff_id = 1001
    month_year = datetime(2023, 5, 1)
    start_date = datetime(2023, 5, 1)
    end_date = datetime(2023, 5, 31)
    
    sunday_result = sunday_check(session, staff_id, month_year)
    payout_result = payout(session, staff_id, start_date, end_date)
    name_result = get_name(session, staff_id)
    hours_result = get_hours(session, staff_id, start_date, end_date)
    
    return f"Sunday Check: {sunday_result}\nPayout: {payout_result}\nName: {name_result}\nHours: {hours_result}"

$$;

CALL jta_employee_ops();
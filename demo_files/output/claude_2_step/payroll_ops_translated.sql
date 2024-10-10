CREATE OR REPLACE PROCEDURE jta_payroll_ops()
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'process_payroll'
AS
$$
import snowflake.snowpark as snowpark
from snowflake.snowpark.functions import col, date_trunc, dayofweek, sum
from datetime import datetime, timedelta

def get_hours(session, staff_id, start_date, end_date):
    basic_hours = overtime_hours = doubletime_hours = 0
    
    # Calculate doubletime hours (Sundays)
    doubletime_query = session.sql(f"""
        SELECT SUM(DATEDIFF('hour', START_TIME, END_TIME)) AS sunday_hours
        FROM WORK_HOURS
        WHERE STAFF_ID = {staff_id}
        AND START_TIME >= '{start_date}'
        AND END_TIME <= '{end_date}'
        AND DAYOFWEEK(START_TIME) = 0
    """)
    doubletime_result = doubletime_query.collect()
    doubletime_hours = doubletime_result[0]['SUNDAY_HOURS'] if doubletime_result[0]['SUNDAY_HOURS'] else 0

    # Calculate basic hours (other days)
    basic_query = session.sql(f"""
        SELECT SUM(DATEDIFF('hour', START_TIME, END_TIME)) AS total_hours
        FROM WORK_HOURS
        WHERE STAFF_ID = {staff_id}
        AND START_TIME >= '{start_date}'
        AND END_TIME <= '{end_date}'
        AND DAYOFWEEK(START_TIME) != 0
    """)
    basic_result = basic_query.collect()
    basic_hours = basic_result[0]['TOTAL_HOURS'] if basic_result[0]['TOTAL_HOURS'] else 0

    # Adjust basic and overtime hours
    if basic_hours > 40:
        overtime_hours = basic_hours - 40
        basic_hours = 40

    return basic_hours, overtime_hours, doubletime_hours

def process_payroll(session):
    try:
        # Calculate start and end dates for the payroll week
        current_date = datetime.now()
        end_date = date_trunc('week', current_date) - timedelta(days=1)
        start_date = end_date - timedelta(days=6)

        # Get staff IDs who worked during the week
        staff_query = session.sql(f"""
            SELECT DISTINCT STAFF_ID
            FROM WORK_HOURS
            WHERE START_TIME >= '{start_date}'
            AND END_TIME <= '{end_date}'
        """)
        staff_ids = [row['STAFF_ID'] for row in staff_query.collect()]

        # Delete existing payroll records for the current week
        session.sql(f"""
            DELETE FROM PAYROLL
            WHERE WEEK_ENDING = '{end_date}'
        """).collect()

        # Process payroll for each staff member
        for staff_id in staff_ids:
            basic_hours, overtime_hours, doubletime_hours = get_hours(session, staff_id, start_date, end_date)
            
            # Get wage rate for the staff member
            wage_query = session.sql(f"""
                SELECT WAGE_RATE
                FROM STAFF
                WHERE STAFF_ID = {staff_id}
            """)
            wage_rate = wage_query.collect()[0]['WAGE_RATE']

            # Calculate pay
            basic_pay = basic_hours * wage_rate
            overtime_pay = overtime_hours * wage_rate * 1.5
            doubletime_pay = doubletime_hours * wage_rate * 2
            gross_pay = basic_pay + overtime_pay + doubletime_pay

            # Calculate deductions (simplified for this example)
            tax_deduction = gross_pay * 0.2
            other_deduction = gross_pay * 0.05
            total_deduction = tax_deduction + other_deduction
            net_pay = gross_pay - total_deduction

            # Insert new payroll record
            session.sql(f"""
                INSERT INTO PAYROLL (STAFF_ID, WEEK_ENDING, BASIC_HOURS, OVERTIME_HOURS, DOUBLETIME_HOURS,
                                     BASIC_PAY, OVERTIME_PAY, DOUBLETIME_PAY, GROSS_PAY,
                                     TAX_DEDUCTION, OTHER_DEDUCTION, NET_PAY)
                VALUES ({staff_id}, '{end_date}', {basic_hours}, {overtime_hours}, {doubletime_hours},
                        {basic_pay}, {overtime_pay}, {doubletime_pay}, {gross_pay},
                        {tax_deduction}, {other_deduction}, {net_pay})
            """).collect()

        session.sql("COMMIT").collect()
        return "Payroll processed successfully"
    except Exception as e:
        session.sql("ROLLBACK").collect()
        return f"Error processing payroll: {str(e)}"

# Handler function
def process_payroll_handler(snowpark_session):
    return process_payroll(snowpark_session)
$$;

CALL jta_payroll_ops();
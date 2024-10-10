CREATE OR REPLACE PROCEDURE jta_financial_ops()
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'main'
AS
$$
import snowflake.snowpark as snowpark
from snowflake.snowpark.functions import col, sum, when, lit
from datetime import datetime, timedelta
import logging

def process_payroll(session, start_date, end_date):
    try:
        # Calculate payroll for the given date range
        payroll_data = session.sql(f"""
            SELECT staff_id, SUM(hours_worked) as total_hours, 
                   MAX(pay_rate) as pay_rate
            FROM staff_hours
            WHERE work_date BETWEEN '{start_date}' AND '{end_date}'
            GROUP BY staff_id
        """).collect()

        # Insert payroll data
        for row in payroll_data:
            gross_pay = row['total_hours'] * row['pay_rate']
            deductions = gross_pay * 0.2  # Assuming 20% deductions
            net_pay = gross_pay - deductions

            session.sql(f"""
                INSERT INTO payroll (staff_id, pay_period_start, pay_period_end, 
                                     gross_pay, deductions, net_pay)
                VALUES ({row['staff_id']}, '{start_date}', '{end_date}', 
                        {gross_pay}, {deductions}, {net_pay})
            """).collect()

        return "Payroll processed successfully"
    except Exception as e:
        logging.error(f"Error in process_payroll: {str(e)}")
        raise

def get_profits_for(session, start_date, end_date):
    try:
        profits_data = session.sql(f"""
            WITH sales AS (
                SELECT SUM(amount) as total_sales
                FROM transactions
                WHERE transaction_date BETWEEN '{start_date}' AND '{end_date}'
            ),
            costs AS (
                SELECT SUM(amount) as total_costs
                FROM expenses
                WHERE expense_date BETWEEN '{start_date}' AND '{end_date}'
            )
            SELECT 
                total_sales as gross_gain,
                total_costs as costs,
                (total_sales - total_costs) as net_gain
            FROM sales, costs
        """).collect()

        if profits_data:
            return profits_data[0]
        else:
            return "No profit data found for the given period"
    except Exception as e:
        logging.error(f"Error in get_profits_for: {str(e)}")
        raise

def get_money_inflow(session, location, start_date, end_date, inflow_type):
    try:
        if inflow_type not in ['cash', 'non-cash']:
            raise ValueError("Invalid inflow type. Must be 'cash' or 'non-cash'")

        inflow_data = session.sql(f"""
            SELECT SUM(amount) as total_inflow
            FROM transactions
            WHERE location = '{location}'
              AND transaction_date BETWEEN '{start_date}' AND '{end_date}'
              AND payment_type = {'cash' if inflow_type == 'cash' else 'non-cash'}
        """).collect()

        if inflow_data and inflow_data[0]['total_inflow'] is not None:
            return inflow_data[0]['total_inflow']
        else:
            return 0
    except Exception as e:
        logging.error(f"Error in get_money_inflow: {str(e)}")
        raise

def main(session: snowpark.Session):
    try:
        # Example usage of the procedures
        start_date = '2023-01-01'
        end_date = '2023-01-07'
        
        payroll_result = process_payroll(session, start_date, end_date)
        profits = get_profits_for(session, start_date, end_date)
        cash_inflow = get_money_inflow(session, 'Store A', start_date, end_date, 'cash')

        return f"Payroll: {payroll_result}, Profits: {profits}, Cash Inflow: {cash_inflow}"
    except Exception as e:
        logging.error(f"Error in main procedure: {str(e)}")
        return f"Error: {str(e)}"

$$;

-- Call the procedure
CALL jta_financial_ops();
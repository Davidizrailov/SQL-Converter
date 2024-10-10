```python
CREATE OR REPLACE PROCEDURE jta_employee_ops_snowflake()
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'main'
AS
$$
from snowflake.snowpark import Session
from snowflake.snowpark.functions import col, sum as sum_, to_char, nvl
import datetime
from typing import Tuple

def sunday_check(session: Session, p_staff_id: int, p_month: datetime.date) -> Tuple[int, bool]:
    start_month = p_month.replace(day=1)
    end_month = (start_month + datetime.timedelta(days=31)).replace(day=1) - datetime.timedelta(days=1)
    
    work_days_df = session.table("work_hours").filter(
        (col("staff_id") == p_staff_id) &
        (col("work_date").between(start_month, end_month))
    )
    
    p_sundays = work_days_df.filter(to_char(col("work_date"), 'd') == '1').count()
    p_available = p_sundays < 2
    
    return p_sundays, p_available

def payout(session: Session, p_staff_id: int, p_begin_date: datetime.date, p_end_date: datetime.date) -> Tuple[float, float, float, float, float]:
    payroll_df = session.table("payroll").filter(
        (col("staff_id") == p_staff_id) &
        (col("date_staff_received").between(p_begin_date, p_end_date))
    )
    
    result = payroll_df.select(
        sum_("gross_pay").alias("gross_pay"),
        sum_("net_pay").alias("net_pay"),
        sum_("hlt_surcharge_deduction").alias("hlt"),
        sum_("nat_insurance_deduction").alias("nat")
    ).collect()[0]
    
    gross_pay = result["GROSS_PAY"] or 0
    net_pay = result["NET_PAY"] or 0
    hlt = result["HLT"] or 0
    nat = result["NAT"] or 0
    deductions = hlt + nat
    
    return gross_pay, net_pay, hlt, nat, deductions

def get_name(session: Session, p_staff_id: int) -> str:
    result = session.table("staff").filter(col("staff_id") == p_staff_id).select(
        (col("first_name") + ' ' + col("last_name")).alias("full_name")
    ).collect()
    
    return result[0]["FULL_NAME"] if result else "Unknown"

def get_hours(session: Session, p_staff_id: int, start_date: datetime.date, end_date: datetime.date) -> Tuple[int, int, int]:
    work_hours_df = session.table("work_hours").filter(
        (col("staff_id") == p_staff_id) &
        (col("work_date").between(start_date, end_date))
    )
    
    doubletime = work_hours_df.filter(to_char(col("work_date"), 'd') == '1').agg(nvl(sum_("hours_worked"), 0)).collect()[0][0]
    basic = work_hours_df.filter(to_char(col("work_date"), 'd') != '1').agg(nvl(sum_("hours_worked"), 0)).collect()[0][0]
    
    overtime = 0
    if basic > 40:
        overtime = basic - 40
        basic = 40
    
    return int(basic), int(overtime), int(doubletime)

def main(session: Session) -> str:
    # Example usage
    sunday_check_result = sunday_check(session, 1, datetime.date(2023, 10, 1))
    payout_result = payout(session, 1, datetime.date(2023, 10, 1), datetime.date(2023, 10, 31))
    name_result = get_name(session, 1)
    hours_result = get_hours(session, 1, datetime.date(2023, 10, 1), datetime.date(2023, 10, 31))

    return f"sunday_check: {sunday_check_result}, payout: {payout_result}, name: {name_result}, hours: {hours_result}"

$$;

CALL jta_employee_ops_snowflake();
```
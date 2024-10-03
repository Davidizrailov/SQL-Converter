```sql
CREATE OR REPLACE PROCEDURE sunday_check(
    p_staff_id STRING,
    p_month DATE,
    p_sundays OUT INTEGER,
    p_available OUT BOOLEAN
)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'sunday_check_handler'
AS
$$
from snowflake.snowpark import Session
from snowflake.snowpark.functions import col, to_date, lit

def sunday_check_handler(session: Session, p_staff_id: str, p_month: str):
    try:
        work_days = session.table("work_hours").filter(
            (col("staff_id") == p_staff_id) &
            (col("work_date").between(to_date(lit(p_month)), to_date(lit(p_month)).add_months(1).add_days(-1)))
        ).collect()

        p_sundays = sum(1 for work_day in work_days if work_day["work_date"].weekday() == 6)
        p_available = p_sundays < 2

        return f"p_sundays: {p_sundays}, p_available: {p_available}"
    except Exception as e:
        return f"Error: {str(e)}"
$$;

CALL sunday_check('staff_id_example', '2023-10-01', p_sundays, p_available);

CREATE OR REPLACE PROCEDURE payout(
    p_staff_id STRING,
    p_begin_date DATE,
    p_end_date DATE,
    p_gross_pay OUT FLOAT,
    p_net_pay OUT FLOAT,
    p_hlt OUT FLOAT,
    p_nat OUT FLOAT,
    p_deductions OUT FLOAT
)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'payout_handler'
AS
$$
from snowflake.snowpark import Session
from snowflake.snowpark.functions import col, sum as snowflake_sum

def payout_handler(session: Session, p_staff_id: str, p_begin_date: str, p_end_date: str):
    try:
        payroll_data = session.table("payroll").filter(
            (col("staff_id") == p_staff_id) &
            (col("date_staff_received").between(to_date(lit(p_begin_date)), to_date(lit(p_end_date))))
        ).select(
            snowflake_sum("gross_pay").alias("gross_pay"),
            snowflake_sum("net_pay").alias("net_pay"),
            snowflake_sum("hlt_surcharge_deduction").alias("hlt"),
            snowflake_sum("nat_insurance_deduction").alias("nat")
        ).collect()

        if payroll_data:
            p_gross_pay = payroll_data[0]["gross_pay"]
            p_net_pay = payroll_data[0]["net_pay"]
            p_hlt = payroll_data[0]["hlt"]
            p_nat = payroll_data[0]["nat"]
            p_deductions = p_hlt + p_nat
        else:
            p_gross_pay = 0
            p_net_pay = 0
            p_deductions = 0

        return f"p_gross_pay: {p_gross_pay}, p_net_pay: {p_net_pay}, p_deductions: {p_deductions}"
    except Exception as e:
        return f"Error: {str(e)}"
$$;

CALL payout('staff_id_example', '2023-10-01', '2023-10-31', p_gross_pay, p_net_pay, p_hlt, p_nat, p_deductions);

CREATE OR REPLACE PROCEDURE get_name(
    p_staff_id STRING
)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'get_name_handler'
AS
$$
from snowflake.snowpark import Session

def get_name_handler(session: Session, p_staff_id: str):
    try:
        staff_data = session.table("staff").filter(col("staff_id") == p_staff_id).select("first_name", "last_name").collect()
        if staff_data:
            return f"{staff_data[0]['first_name']} {staff_data[0]['last_name']}"
        else:
            return "Unknown"
    except Exception as e:
        return f"Error: {str(e)}"
$$;

CALL get_name('staff_id_example');

CREATE OR REPLACE PROCEDURE get_hours(
    p_staff_id STRING,
    start_date DATE,
    end_date DATE,
    basic OUT INTEGER,
    overtime OUT INTEGER,
    doubletime OUT INTEGER
)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'get_hours_handler'
AS
$$
from snowflake.snowpark import Session
from snowflake.snowpark.functions import col, sum as snowflake_sum, to_date, lit

def get_hours_handler(session: Session, p_staff_id: str, start_date: str, end_date: str):
    try:
        basic = 0
        overtime = 0
        doubletime = 0

        doubletime_hours = session.table("work_hours").filter(
            (col("work_date").between(to_date(lit(start_date)), to_date(lit(end_date)))) &
            (col("staff_id") == p_staff_id) &
            (col("work_date").weekday() == 6)
        ).select(snowflake_sum("hours_worked").alias("doubletime")).collect()

        basic_hours = session.table("work_hours").filter(
            (col("work_date").between(to_date(lit(start_date)), to_date(lit(end_date)))) &
            (col("staff_id") == p_staff_id) &
            (col("work_date").weekday() != 6)
        ).select(snowflake_sum("hours_worked").alias("basic")).collect()

        if doubletime_hours:
            doubletime = doubletime_hours[0]["doubletime"]
        if basic_hours:
            basic = basic_hours[0]["basic"]

        if basic > 40:
            overtime = basic - 40
            basic = 40

        return f"basic: {basic}, overtime: {overtime}, doubletime: {doubletime}"
    except Exception as e:
        return f"Error: {str(e)}"
$$;

CALL get_hours('staff_id_example', '2023-10-01', '2023-10-31', basic, overtime, doubletime);
```
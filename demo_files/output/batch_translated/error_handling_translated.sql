```sql
CREATE OR REPLACE PROCEDURE throw(p_code NUMBER, p_message STRING)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'throw_handler'
AS
$$
def throw_handler(session, p_code, p_message):
    raise Exception(f"Error {p_code}: {p_message}")
$$;

CREATE OR REPLACE PROCEDURE log_error(p_code NUMBER, p_message STRING)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'log_error_handler'
AS
$$
from snowflake.snowpark import Session
from snowflake.snowpark.functions import col
from datetime import datetime

def log_error_handler(session: Session, p_code: int, p_message: str) -> str:
    session.sql(f"""
        INSERT INTO jta_errors (error_id, date_time, user_name, code, message)
        VALUES (error_seq.NEXTVAL, '{datetime.now()}', '{session.get_current_user()}', {p_code}, '{p_message}')
    """).collect()
    return f"Error logged: {p_message}"
$$;

CREATE OR REPLACE PROCEDURE show_in_console(p_code NUMBER = NULL, p_message STRING)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'show_in_console_handler'
AS
$$
def show_in_console_handler(session, p_code, p_message):
    return f"A trivial error occurred: {p_message}"
$$;

-- Example calls to the procedures
CALL throw(20201, 'Invalid input');
CALL log_error(20202, 'Missing data');
CALL show_in_console(NULL, 'This is a test message');
```
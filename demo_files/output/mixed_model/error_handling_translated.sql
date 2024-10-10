```sql
CREATE OR REPLACE PROCEDURE jta_error_throw(p_code FLOAT, p_message STRING)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'throw_error'
AS $$
def throw_error(session, p_code, p_message):
    raise Exception(f"Code: {p_code}, Message: {p_message}")
$$;

CREATE OR REPLACE PROCEDURE jta_error_log_error(p_code FLOAT, p_message STRING)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'log_error'
AS $$
def log_error(session, p_code, p_message):
    print(f"Error logged: {p_message}")
    session.sql("""
        INSERT INTO jta_errors (error_id, date_time, user_name, code, message)
        VALUES (error_seq.NEXTVAL, current_timestamp(), CURRENT_USER(), %(p_code)s, %(p_message)s)
    """, params={"p_code": p_code, "p_message": p_message}).collect()
    session.commit()
$$;

CREATE OR REPLACE PROCEDURE jta_error_show_in_console(p_code FLOAT DEFAULT NULL, p_message STRING)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'show_in_console'
AS $$
def show_in_console(session, p_code, p_message):
    message = f"A trivial error occurred: {p_message}" if p_code is None else f"Error {p_code}: {p_message}"
    print(message)
$$;

-- Call the procedures
CALL jta_error_throw(-20201, 'Invalid input error');
CALL jta_error_log_error(-20202, 'Missing data error');
CALL jta_error_show_in_console(NULL, 'This is a trivial message');
```
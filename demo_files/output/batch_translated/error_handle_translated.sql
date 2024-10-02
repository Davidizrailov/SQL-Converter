```sql
CREATE OR REPLACE PROCEDURE handle_division()
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'run'
AS
$$
def run(session):
    dividend = 10
    divisor = 0
    try:
        result = dividend / divisor
        return f'Result: {result}'
    except ZeroDivisionError:
        return 'Error: Division by zero'

CALL handle_division();
$$;
```
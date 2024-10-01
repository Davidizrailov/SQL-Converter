```sql
CREATE OR REPLACE PROCEDURE loop_example()
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'run'
AS
$$
def run(session):
    n = 0
    while True:
        session.sql(f"SELECT 'The value of n inside the loop is: {n}'").show()
        n += 1
        if n > 5:
            break
    session.sql(f"SELECT 'The value of n outside the loop is: {n}'").show()
    return "Procedure completed successfully"
$$;

CALL loop_example();
```
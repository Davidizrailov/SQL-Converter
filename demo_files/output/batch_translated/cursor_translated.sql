```sql
CREATE OR REPLACE PROCEDURE fetch_employees(max_sal FLOAT)
RETURNS TABLE(first_name STRING, salary FLOAT)
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'fetch_employees_handler'
AS
$$
from snowflake.snowpark import Session
from snowflake.snowpark.functions import col

def fetch_employees_handler(session: Session, max_sal: float):
    employees_df = session.table("employees").filter(col("salary") < max_sal)
    result = []
    for row in employees_df.collect():
        result.append((row['first_name'], row['salary']))
        print(f"Name: {row['first_name']}\tsalary: {row['salary']}")
    return result
$$;

CALL fetch_employees(76000);
```
CREATE OR REPLACE PROCEDURE jta_error()
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'main'
AS
$$
import snowflake.snowpark as snowpark
from snowflake.snowpark.exceptions import SnowparkSQLException

class JTAError:
    def __init__(self, session):
        self.session = session
        self.invalid_input = SnowparkSQLException("Invalid input")
        self.missing_data = SnowparkSQLException("Missing data")

    def throw(self, error_code, error_message):
        raise SnowparkSQLException(f"Error {error_code}: {error_message}")

    def log_error(self, error_code, error_message):
        print(f"Error {error_code}: {error_message}")  # For development purposes
        self.session.sql(f"""
            INSERT INTO jta_errors (error_code, error_message, created_at)
            VALUES ({error_code}, '{error_message}', CURRENT_TIMESTAMP())
        """).collect()

    def show_in_console(self, error_code=None, error_message=""):
        if error_code:
            print(f"Error {error_code}: {error_message}")
        else:
            print(f"Error: {error_message}")

def main(session: snowpark.Session):
    jta_error = JTAError(session)
    
    try:
        # Example usage
        jta_error.throw(1001, "Sample error")
    except SnowparkSQLException as e:
        jta_error.log_error(1001, str(e))
        jta_error.show_in_console(1001, str(e))

    return "JTA Error procedure executed successfully"

$$;

CALL jta_error();
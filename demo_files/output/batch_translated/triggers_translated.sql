```sql
CREATE OR REPLACE PROCEDURE update_job_history_trigger()
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'update_job_history_handler'
AS
$$
from snowflake.snowpark import Session
from snowflake.snowpark.functions import col
from snowflake.snowpark.types import StructType, StructField, StringType, TimestampType

def update_job_history_handler(session: Session) -> str:
    try:
        # Update the date_ended for the old job_id
        session.sql("""
            UPDATE job_posts_history SET
                date_ended = CURRENT_TIMESTAMP()
            WHERE staff_id = :OLD.staff_id AND job_id = :OLD.job_id
        """).collect()

        # Insert a new record for the new job_id
        session.sql("""
            INSERT INTO job_posts_history (staff_id, job_id, date_started, date_ended)
            VALUES (:OLD.staff_id, :NEW.job_id, CURRENT_TIMESTAMP(), NULL)
        """).collect()

        return "SUCCESS"
    except Exception as e:
        session.sql(f"CALL jta_error.log_error({e.args[0]}, '{e.args[1]}')")
        return "FAILURE"
$$;

CALL update_job_history_trigger();

CREATE OR REPLACE PROCEDURE email_on_inv_trigger()
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'email_on_inv_handler'
AS
$$
from snowflake.snowpark import Session
from snowflake.snowpark.functions import col

def email_on_inv_handler(session: Session) -> str:
    try:
        v_email = ''
        v_product_name = ''
        v_subject = ''
        v_message = ''

        if :OLD.quantity > :OLD.min_stock_level and :NEW.quantity < :NEW.min_stock_level:
            if :OLD.location_id in (10, 12):
                v_email = 'carlton_center_purchasing@jta.com'
            elif :OLD.location_id == 11:
                v_email = 'marabella_purchasing@jta.com'

            v_product_name = session.table('products').filter(col('product_id') == :OLD.product_id).select('product_name').collect()[0][0]
            v_subject = f'subject: purchase needed for: {v_product_name}'
            v_message = f'instock = {NEW.quantity}, min stock level = {OLD.min_stock_level}, reorder level = {OLD.reorder_level}'

            print(' ')
            print('---------------------------------------')
            print('restock trigger activated')
            print('from:  database@jta.com')
            print(f'to: {v_email}')
            print(f'subject: {v_subject}')
            print(f'message: {v_message}')
            print('---------------------------------------')
            print(' ')

        return "SUCCESS"
    except Exception as e:
        session.sql(f"CALL jta_error.log_error({e.args[0]}, '{e.args[1]}')")
        return "FAILURE"
$$;

CALL email_on_inv_trigger();

CREATE OR REPLACE PROCEDURE logon_trigger()
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'logon_handler'
AS
$$
from snowflake.snowpark import Session

def logon_handler(session: Session) -> str:
    try:
        session.sql("""
            INSERT INTO jta_events (event_id, user_name, date_time, event, ip_address)
            VALUES (event_seq.nextval, CURRENT_USER(), CURRENT_TIMESTAMP(), 'LOGON', CURRENT_CLIENT_IP())
        """).collect()

        try:
            session.sql("""
                SELECT ip_address INTO v_ip 
                FROM authorized_ip_addresses 
                WHERE ip_address = CURRENT_CLIENT_IP()
            """).collect()
        except:
            pass

        return "SUCCESS"
    except Exception as e:
        session.sql(f"CALL jta_error.log_error({e.args[0]}, '{e.args[1]}')")
        return "FAILURE"
$$;

CALL logon_trigger();

CREATE OR REPLACE PROCEDURE logoff_trigger()
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'logoff_handler'
AS
$$
from snowflake.snowpark import Session

def logoff_handler(session: Session) -> str:
    try:
        session.sql("""
            INSERT INTO jta_events (event_id, user_name, date_time, event, ip_address)
            VALUES (event_seq.nextval, CURRENT_USER(), CURRENT_TIMESTAMP(), 'LOGOFF', NULL)
        """).collect()

        return "SUCCESS"
    except Exception as e:
        session.sql(f"CALL jta_error.log_error({e.args[0]}, '{e.args[1]}')")
        return "FAILURE"
$$;

CALL logoff_trigger();
```
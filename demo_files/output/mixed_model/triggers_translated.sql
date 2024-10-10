```sql
CREATE OR REPLACE PROCEDURE update_job_history_trigger()
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'run_update_job_history'
AS
$$
def run_update_job_history(session):
    try:
        session.sql("""
        UPDATE job_posts_history SET
            date_ended = CURRENT_TIMESTAMP()
        WHERE staff_id = :OLD.staff_id AND job_id = :OLD.job_id
        """).collect()

        session.sql("""
        INSERT INTO job_posts_history (staff_id, job_id, date_started, date_ended)
        VALUES (:OLD.staff_id, :NEW.job_id, CURRENT_TIMESTAMP(), NULL)
        """).collect()

        return "update_job_history_trigger completed successfully"
    except Exception as e:
        return f"Error: {str(e)}"
$$;

CALL update_job_history_trigger();

CREATE OR REPLACE PROCEDURE email_on_inv_trigger()
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'run_email_on_inv'
AS
$$
def run_email_on_inv(session):
    try:
        if :OLD.quantity > :OLD.min_stock_level and :NEW.quantity < :NEW.min_stock_level:
            v_email = 'carlton_center_purchasing@jta.com' if :OLD.location_id in (10, 12) else 'marabella_purchasing@jta.com'

            v_product_name = session.sql("""
            SELECT product_name FROM products WHERE product_id = :OLD.product_id
            """).collect()[0][0]

            v_subject = f"subject: purchase needed for: {v_product_name}"
            v_message = f"instock = {NEW.quantity}, min stock level = {OLD.min_stock_level}, reorder level = {OLD.reorder_level}"

            print("\n---------------------------------------")
            print("restock trigger activated")
            print("from:  database@jta.com")
            print(f"to: {v_email}")
            print(f"subject: {v_subject}")
            print(f"message: {v_message}")
            print("---------------------------------------\n")

        return "email_on_inv_trigger completed successfully"
    except Exception as e:
        return f"Error: {str(e)}"
$$;

CALL email_on_inv_trigger();

CREATE OR REPLACE PROCEDURE logon_trigger()
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'run_logon'
AS
$$
def run_logon(session):
    try:
        session.sql("""
        INSERT INTO jta_events (event_id, user_name, date_time, event, ip_address)
        VALUES (event_seq.nextval, CURRENT_USER(), CURRENT_TIMESTAMP(), 'LOGON', NULL)
        """).collect()

        try:
            v_ip = session.sql("""
            SELECT ip_address FROM authorized_ip_adresses 
            WHERE ip_address = NULL
            """).collect()[0][0]
        except:
            pass

        return "logon_trigger completed successfully"
    except Exception as e:
        return f"Error: {str(e)}"
$$;

CALL logon_trigger();

CREATE OR REPLACE PROCEDURE logoff_trigger()
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'run_logoff'
AS
$$
def run_logoff(session):
    try:
        session.sql("""
        INSERT INTO jta_events (event_id, user_name, date_time, event, ip_address)
        VALUES (event_seq.nextval, CURRENT_USER(), CURRENT_TIMESTAMP(), 'LOGOFF', NULL)
        """).collect()

        return "logoff_trigger completed successfully"
    except Exception as e:
        return f"Error: {str(e)}"
$$;

CALL logoff_trigger();
```
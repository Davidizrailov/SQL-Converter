CREATE OR REPLACE PROCEDURE update_job_history()
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'update_job_history'
AS
$$
def update_job_history(session):
    try:
        # Update old job record
        session.sql("""
            UPDATE job_posts_history
            SET date_ended = CURRENT_DATE()
            WHERE staff_id = (SELECT staff_id FROM staff WHERE job_id <> OLD.job_id)
            AND date_ended IS NULL
        """).collect()

        # Insert new job record
        session.sql("""
            INSERT INTO job_posts_history (staff_id, job_id, date_started)
            SELECT staff_id, job_id, CURRENT_DATE()
            FROM staff
            WHERE job_id <> OLD.job_id
        """).collect()

        return "Job history updated successfully"
    except Exception as e:
        return f"Error updating job history: {str(e)}"

def email_on_inv(session):
    try:
        # Check for inventory below minimum stock level
        result = session.sql("""
            SELECT i.location_id, i.product_id, i.quantity, i.min_stock_level, p.product_name
            FROM inventory_by_location i
            JOIN products p ON i.product_id = p.product_id
            WHERE i.quantity < i.min_stock_level
            AND OLD.quantity >= i.min_stock_level
        """).collect()

        if result:
            for row in result:
                location_id = row['LOCATION_ID']
                product_name = row['PRODUCT_NAME']
                quantity = row['QUANTITY']
                min_stock_level = row['MIN_STOCK_LEVEL']

                # Determine email address based on location_id
                email_address = session.sql(f"SELECT email FROM location_emails WHERE location_id = {location_id}").collect()[0]['EMAIL']

                # Construct email subject and message
                subject = f"Low Stock Alert: {product_name}"
                message = f"Product {product_name} is below minimum stock level.\nCurrent quantity: {quantity}\nMinimum stock level: {min_stock_level}"

                # Output email details (replace with actual email sending logic)
                print(f"To: {email_address}\nSubject: {subject}\nMessage: {message}")

        return "Inventory check completed"
    except Exception as e:
        session.sql(f"CALL jta_error.log_error('email_on_inv_trigger', '{str(e)}')").collect()
        return f"Error in email_on_inv: {str(e)}"

def logon(session):
    try:
        # Insert logon event
        session.sql("""
            INSERT INTO jta_events (event_type, user_name, event_date, ip_address)
            VALUES ('LOGON', CURRENT_USER(), CURRENT_TIMESTAMP(), CURRENT_CLIENT())
        """).collect()

        # Verify IP address
        ip_check = session.sql("""
            SELECT COUNT(*) as count
            FROM authorized_ip_addresses
            WHERE ip_address = CURRENT_CLIENT()
        """).collect()[0]['COUNT']

        if ip_check == 0:
            print(f"Warning: Unauthorized IP address detected: {session.sql('SELECT CURRENT_CLIENT()').collect()[0][0]}")

        return "Logon event recorded"
    except Exception as e:
        session.sql(f"CALL jta_error.log_error('logon_trigger', '{str(e)}')").collect()
        return f"Error in logon trigger: {str(e)}"

def logoff(session):
    try:
        # Insert logoff event
        session.sql("""
            INSERT INTO jta_events (event_type, user_name, event_date)
            VALUES ('LOGOFF', CURRENT_USER(), CURRENT_TIMESTAMP())
        """).collect()

        return "Logoff event recorded"
    except Exception as e:
        session.sql(f"CALL jta_error.log_error('logoff_trigger', '{str(e)}')").collect()
        return f"Error in logoff trigger: {str(e)}"
$$;

CALL update_job_history();
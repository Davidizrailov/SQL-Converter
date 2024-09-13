CREATE OR REPLACE TRIGGER update_job_history_trigger
AFTER INSERT OR UPDATE OF job_id ON staff FOR EACH ROW
WHEN (NEW.job_id != OLD.job_id)
BEGIN
    UPDATE job_posts_history SET
        date_ended = sysdate 
    WHERE staff_id = :OLD.staff_id AND job_id = :OLD.job_id;

    INSERT INTO job_posts_history (staff_id, job_id, date_started, date_ended)
    VALUES (:OLD.staff_id, :NEW.job_id, sysdate, NULL);
END update_job_history_trigger;
/

CREATE OR REPLACE TRIGGER email_on_inv_trigger
AFTER UPDATE OF quantity ON inventory_by_location FOR EACH ROW
WHEN (NEW.quantity < OLD.quantity)
BEGIN
    DECLARE
        v_email VARCHAR2(50);
        v_product_name products.product_name%TYPE;
        v_subject VARCHAR2(200);
        v_message VARCHAR2(200);
    BEGIN
        IF :OLD.quantity > :old.min_stock_level and :NEW.quantity < :NEW.min_stock_level THEN
            IF :OLD.location_id = 10 OR :OLD.location_id = 12 THEN
                v_email := 'carlton_center_purchasing@jta.com';
            ELSIF :OLD.location_id = 11 THEN
                v_email := 'marabella_purchasing@jta.com';
            END IF;
        
            SELECT product_name INTO v_product_name 
            FROM products WHERE product_id = :OLD.product_id;
            
            v_subject := 'subject: purchase needed for: ' || v_product_name;
            v_message := 'instock = ' || :NEW.quantity
                        || ', min stock level = ' || :OLD.min_stock_level
                        || ', reorder level = ' || :OLD.reorder_level;
        
            -- Output the email message in the console for debugging purposes
            dbms_output.put_line(' ');
            dbms_output.put_line('---------------------------------------');
            dbms_output.put_line('restock trigger activated');
            dbms_output.put_line('from:  database@jta.com');
            dbms_output.put_line('to: ' || v_email);
            dbms_output.put_line('subject: ' || v_subject);
            dbms_output.put_line('message: ' || v_message);
            dbms_output.put_line('---------------------------------------');
            dbms_output.put_line(' ');

        END IF;
    EXCEPTION 
        WHEN OTHERS THEN
            jta_error.log_error(SQLCODE, SQLERRM);
    END;
END email_on_inv_trigger;
/

CREATE OR REPLACE TRIGGER logon_trigger
AFTER LOGON ON SCHEMA
BEGIN
    INSERT INTO jta_events (event_id, user_name, date_time, event, ip_address)
    VALUES (event_seq.nextval, USER, SYSDATE, ora_sysevent, ora_client_ip_address);
    
    COMMIT;

    DECLARE
        v_ip VARCHAR2(20);
    BEGIN
        SELECT ip_address INTO v_ip 
        FROM authorized_ip_adresses 
        WHERE ip_address = ora_client_ip_address;
    EXCEPTION
        WHEN no_data_found THEN
            NULL;
    END;
EXCEPTION
    WHEN OTHERS THEN
        jta_error.log_error(SQLCODE, SQLERRM);    
END logon_trigger;
/

CREATE OR REPLACE TRIGGER logoff_trigger
BEFORE LOGOFF ON SCHEMA 
BEGIN
    INSERT INTO jta_events (event_id, user_name, date_time, event, ip_address)
    VALUES (event_seq.nextval, USER, SYSDATE, ora_sysevent, NULL);
    
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        jta_error.log_error(SQLCODE, SQLERRM);     
END logoff_trigger;
/

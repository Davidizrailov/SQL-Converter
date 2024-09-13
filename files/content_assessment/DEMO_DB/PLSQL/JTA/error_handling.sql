CREATE OR REPLACE PACKAGE jta_error IS
    invalid_input EXCEPTION;
    PRAGMA exception_init (invalid_input, -20201);
    missing_data EXCEPTION;
    PRAGMA exception_init (missing_data, -20202);
    
    PROCEDURE throw (
        p_code IN NUMBER,
        p_message IN VARCHAR2
    );
    
    PROCEDURE log_error (
        p_code IN NUMBER,
        p_message IN VARCHAR2
    );
    
    PROCEDURE show_in_console (
        p_code IN NUMBER := NULL,
        p_message IN VARCHAR2
    );
END jta_error;
/

CREATE OR REPLACE PACKAGE BODY jta_error
IS

    /*
        Throw an exception, this makes coding a little simpler
    */
    PROCEDURE throw (
        p_code IN NUMBER,
        p_message   IN VARCHAR2
    )
    IS
    BEGIN
        raise_application_error(p_code, p_message);
    END;
    
    /*
        Log the exception to an error table.
        
        Most procedures will do this when exceptions occur.
        For development we will show the error in console as well.
    */
    PROCEDURE log_error (
      p_code IN NUMBER,
      p_message   IN VARCHAR2
    )
    IS
        -- autonomous transaction needed, otherwise rollback will remove log entry
        PRAGMA autonomous_transaction; 
    BEGIN
        -- show info in console, disable this line in production
        dbms_output.put_line('error logged: ' || p_message);
        -- log error into error table
        INSERT INTO jta_errors (error_id, date_time, user_name, code, message)
        VALUES (error_seq.NEXTVAL, sysdate, USER, p_code, p_message);
        COMMIT;
    END;
    
    /*
        Show an error in the console.
        
        Sometimes you don't want to log an error because it is not a
        note worthy failure, e.g. it is not a problem if no data was 
        found for a query.
        
        This procedure is available for testing purposes
    */
    PROCEDURE show_in_console (
        p_code IN NUMBER := NULL,
        p_message IN VARCHAR2
    )
    IS
    BEGIN
        dbms_output.put_line('A trivial error occured: ' || p_message);        
    END;
    
END jta_error;
/
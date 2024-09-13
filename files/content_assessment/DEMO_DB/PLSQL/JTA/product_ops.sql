CREATE OR REPLACE PACKAGE jta_product_ops IS
    FUNCTION get_price_changes (
        p_product_id products.product_id%type,
        p_start_date DATE,
        p_end_date DATE
    ) RETURN price_changes_table;

    PROCEDURE get_recommended_price_for (
        p_product_id IN products.product_id%TYPE,
        p_avg_cost OUT NOCOPY products.price_rate%TYPE,
        p_old_price OUT NOCOPY products.price_rate%TYPE,
        p_new_price OUT NOCOPY products.price_rate%TYPE
    );

    FUNCTION get_quantity_sold (
        p_product_id products.product_id%TYPE,
        p_location_id locations.location_id%TYPE,
        p_date_start DATE,
        p_date_end DATE
    ) RETURN NUMBER;
END jta_product_ops;

CREATE OR REPLACE PACKAGE BODY jta_product_ops IS
    FUNCTION get_price_changes (
        p_product_id products.product_id%type,
        p_start_date DATE,
        p_end_date DATE
    ) RETURN price_changes_table
    IS
        -- cursor, retrieves price change history for this product
        CURSOR price_changes IS
            SELECT 
                hist.product_id, 
                pr.product_name,
                hist.start_date,
                hist.price_rate
            FROM price_history hist JOIN products pr 
            ON (hist.product_id = pr.product_id)
            WHERE hist.product_id = p_product_id
            AND hist.start_date BETWEEN p_start_date AND p_end_date
            ORDER BY start_date;
        
        -- record for each change
        v_price_record price_change_record;
        
        -- return this index by table of records
        v_return_table price_changes_table;
        
        -- return empty table if exception
        v_empty price_changes_table;
        
        -- index for table
        v_index BINARY_INTEGER := 1;
    
    BEGIN
        
        FOR pc_record IN price_changes LOOP
            -- insert values into record
            v_price_record.product_id := pc_record.product_id;
            v_price_record.product_name := pc_record.product_name;
            v_price_record.date_changed := pc_record.start_date;
            v_price_record.new_price := pc_record.price_rate;
            
            -- get old price for this product change
            BEGIN 
                SELECT price_rate into v_price_record.old_price
                FROM price_history
                WHERE start_date = (
                      SELECT MAX(start_date)
                      FROM price_history
                      WHERE start_date < v_price_record.date_changed
                ) AND product_id = p_product_id;
            EXCEPTION
                WHEN no_data_found THEN
                    v_price_record.old_price := 0;
            END;
            
                
            -- calculate direcion
            IF v_price_record.new_price > v_price_record.old_price THEN
                v_price_record.direction := 'UP';
            ELSIF v_price_record.new_price < v_price_record.old_price THEN
                v_price_record.direction := 'DOWN';
            ELSE
                v_price_record.direction := '--';
            END IF;
            
            -- add to index by table of records
            v_return_table(v_index) := v_price_record;
            v_index := v_index + 1;
        END LOOP;
        
        RETURN v_return_table;
        
    EXCEPTION
        WHEN OTHERS THEN
            -- all exceptions will be logged into error table...
            jta_error.log_error(SQLCODE, SQLERRM);       
            RETURN v_empty;
    END get_price_changes;

    PROCEDURE get_recommended_price_for (
        p_product_id IN products.product_id%TYPE,
        p_avg_cost OUT NOCOPY products.price_rate%TYPE,
        p_old_price OUT NOCOPY products.price_rate%TYPE,
        p_new_price OUT NOCOPY products.price_rate%TYPE
    ) 
    IS
        v_avg products.price_rate%TYPE;
        v_tax tax_rates.tax_rate%TYPE;
    BEGIN
        
        -- try to get current price and average cost and perform calculations, 
        -- log our own error if doesn't exist.
        BEGIN
            SELECT price_rate, tax_rate INTO p_old_price, v_tax
            FROM products pr JOIN tax_rates tr ON (pr.tax_code = tr.tax_code)
            WHERE pr.product_id = p_product_id;
        
            SELECT average_cost_per_unit INTO v_avg
            FROM cost_sales_tracker
            WHERE transaction_id IN (SELECT 
                MAX(transaction_id) FROM cost_sales_tracker
            WHERE product_id = p_product_id);
            
            p_avg_cost := v_avg;    
            
            p_new_price := CEIL((v_avg * 1.3) 
                + (v_avg * 1.3 * (v_tax/100))) 
                - 0.01;
            
        EXCEPTION
            WHEN no_data_found THEN
            -- outside procedure will log this error insead of a generic no data found error
            jta_error.throw(-20202, 'product does not exist or has not been added to inventory');
        END;
     
    EXCEPTION
        WHEN OTHERS THEN
            -- all exceptions will be logged into error table...
            jta_error.log_error(SQLCODE, SQLERRM); 
            p_avg_cost := NULL;
            p_old_price := NULL;
            p_new_price := NULL;
    END get_recommended_price_for;

    FUNCTION get_quantity_sold (
        p_product_id products.product_id%TYPE,
        p_location_id locations.location_id%TYPE,
        p_date_start DATE,
        p_date_end DATE
    ) RETURN NUMBER
    IS 
        v_quantity NUMBER;
    BEGIN
    
        -- raise our own invalid input error if product id or location id not in database
        DECLARE
            v_product products.product_id%TYPE;
            v_location locations.location_id%TYPE;
        BEGIN
            -- check if product id in db
            SELECT product_id INTO v_product
            FROM products
            WHERE product_id = p_product_id;
            -- check if location id in db
            SELECT location_id INTO v_location
            FROM locations
            WHERE location_id = p_location_id;
            
        EXCEPTION
            WHEN no_data_found THEN
                -- raise this instead of no data, for these conditions
                jta_error.throw(-20201, 'invalid location or product id when finding quantity sold');
        END;
        
        SELECT SUM(quantity) 
        INTO v_quantity
        FROM billed_items bi JOIN customer_bills cb USING (bill_id)
        JOIN cashier_drawer_assignments cda USING (assignment_id)
        JOIN cashier_stations cs USING (station_id)
        WHERE cb.date_time_created BETWEEN p_date_start AND p_date_end
        AND cs.location_id = p_location_id and bi.product_id = p_product_id;
    
        RETURN v_quantity;
    EXCEPTION
        WHEN no_data_found THEN
            -- this item did not sell at this location during time period
            RETURN 0;
        WHEN jta_error.invalid_input THEN
            -- application alert, this can be modified to do something else instead
            -- no need to log this error.
            jta_error.show_in_console(SQLCODE, SQLERRM);
            RETURN NULL;
        WHEN OTHERS THEN
            -- log error and return null if other exceptions occur
            jta_error.log_error(SQLCODE, SQLERRM);
            RETURN NULL;
    END get_quantity_sold;
END jta_product_ops;
/
CREATE OR REPLACE PACKAGE jta_general_ops IS
    PROCEDURE lookup_barcode (
        p_barcode IN VARCHAR2,
        p_product_id OUT NOCOPY products.product_id%TYPE,
        p_product_name OUT NOCOPY products.product_name%TYPE,
        p_price_rate OUT NOCOPY products.price_rate%TYPE,
        p_tax_code OUT NOCOPY tax_rates.tax_code%TYPE,
        p_tax_rate OUT NOCOPY tax_rates.tax_rate%TYPE
    );

    PROCEDURE stock_check (
        p_product_id IN products.product_id%TYPE,
        p_location_id IN locations.location_id%TYPE,
        p_value_counted INTEGER,
        p_in_stock OUT NOCOPY INTEGER
    );
END jta_general_ops;

CREATE OR REPLACE PACKAGE BODY jta_general_ops IS
    PROCEDURE lookup_barcode (
        p_barcode IN VARCHAR2,
        p_product_id OUT NOCOPY products.product_id%TYPE,
        p_product_name OUT NOCOPY products.product_name%TYPE,
        p_price_rate OUT NOCOPY products.price_rate%TYPE,
        p_tax_code OUT NOCOPY tax_rates.tax_code%TYPE,
        p_tax_rate OUT NOCOPY tax_rates.tax_rate%TYPE
    )
    IS
    BEGIN
        /*
            SUBSTR is used to test the barcode to find if it is a PLU or not 
            and to extract the id and price if needed.
        */
        IF SUBSTR(p_barcode, 1, 1) = '2' THEN
            -- price rate is calculated from the barcode itself
            p_price_rate := TO_NUMBER(SUBSTR(p_barcode, 7, 5)/100);
            -- get id and name from products table
            SELECT pr.product_id, pr.product_name, tr.tax_code, tr.tax_rate 
            INTO p_product_id, p_product_name, p_tax_code, p_tax_rate
            FROM products pr JOIN tax_rates tr ON (pr.tax_code = tr.tax_code) 
            WHERE price_lookup_code = SUBSTR(p_barcode, 1, 5);
        ELSE
            -- regular look up from products table
            SELECT pr.product_id, pr.product_name, pr.price_rate, tr.tax_code, tr.tax_rate
            INTO p_product_id, p_product_name, p_price_rate, p_tax_code, p_tax_rate
            FROM products pr JOIN tax_rates tr ON (pr.tax_code = tr.tax_code) 
            WHERE barcode = p_barcode;
        END IF;
        
    EXCEPTION
        WHEN no_data_found THEN
            -- log a missing data exception instead of no data exception
            jta_error.log_error(-20202, 'price look up for item that does not exist');
            p_product_id := NULL;
            p_product_name := NULL;
            p_price_rate := NULL;
            p_tax_code := NULL;
            p_tax_rate := NULL;
        WHEN OTHERS THEN
            -- all OTHER exceptions will be logged into error table...
            jta_error.log_error(SQLCODE, SQLERRM);
            p_product_id := NULL;
            p_product_name := NULL;
            p_price_rate := NULL;
            p_tax_code := NULL;
            p_tax_rate := NULL;
    END lookup_barcode;

    PROCEDURE stock_check (
        p_product_id IN products.product_id%TYPE,
        p_location_id IN locations.location_id%TYPE,
        p_value_counted INTEGER,
        p_in_stock OUT NOCOPY INTEGER
    )
    IS 
        v_difference INTEGER;
    BEGIN
        
        -- get current in stock for product by location
        -- product_id and location_id make up a composite key
        -- therefore we don't need to worry about too many rows
        SELECT quantity INTO p_in_stock
        FROM inventory_by_location
        WHERE product_id = p_product_id 
        AND location_id = p_location_id;
        
        
        IF p_in_stock > p_value_counted THEN
            -- there are missing items...
            
            v_difference := p_in_stock - p_value_counted;
            
            -- insert missing items into table
            INSERT INTO missing_items (m_item_id, product_id, date_recorded, quantity)
            VALUES (m_item_id_seq.nextval, p_product_id, sysdate, v_difference);
            
            v_difference := v_difference * -1;
            
            -- update the inventory to reflect the counted stock value
            UPDATE inventory_by_location SET
                quantity = p_value_counted
            WHERE product_id = p_product_id AND location_id = p_location_id;
            
            -- call update inventory and pass in a negative value for this product.
            jta.update_inventory(p_product_id, v_difference, NULL);
            
        /* 
        ELSIF p_in_stock < value_counted
            -- what happens when you have more than what you expect
            -- in inventory. currently we don't do anything but this 
            -- comment is here to show that something could be done
        */
        END IF;
        
    EXCEPTION 
        WHEN no_data_found THEN
            -- select statment failed because item/location doesn't exist
            -- or there was no inventory data for the item
            p_in_stock := NULL;
            jta_error.show_in_console(SQLCODE, SQLERRM);
        WHEN OTHERS THEN
            -- log error and return null if other exceptions occur
            jta_error.log_error(SQLCODE, SQLERRM);
            p_in_stock := NULL;
    END stock_check;
END jta_general_ops;
/

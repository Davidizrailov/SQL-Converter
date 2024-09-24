CREATE OR REPLACE PACKAGE jta_inventory_ops IS
    PROCEDURE update_inventory (
        p_product_id IN cost_sales_tracker.product_id%TYPE,
        p_quantity IN NUMBER,
        p_new_cost IN cost_sales_tracker.cost_per_unit%TYPE
    );
    
    PROCEDURE restock_urgent (
        p_staff_id IN staff.staff_id%TYPE
    );
    
    PROCEDURE evaluate_po_order_line (
        p_line_id IN purchase_order_lines.po_line_id%TYPE,
        p_not_enough_to_restock OUT NOCOPY BOOLEAN,
        p_not_at_min_level OUT NOCOPY BOOLEAN
    );
END jta_inventory_ops;

CREATE OR REPLACE PACKAGE BODY jta_inventory_ops IS
    PROCEDURE update_inventory (
        p_product_id IN cost_sales_tracker.product_id%TYPE,
        p_quantity IN NUMBER,
        p_new_cost IN cost_sales_tracker.cost_per_unit%TYPE
    )
    IS
        v_direction cost_sales_tracker.direction%TYPE := 'OUT';
        v_old_total cost_sales_tracker.total%TYPE;
        v_new_total cost_sales_tracker.total%TYPE;
        v_old_avg cost_sales_tracker.average_cost_per_unit%TYPE;
        v_new_avg cost_sales_tracker.average_cost_per_unit%TYPE;
        v_test_id products.product_id%TYPE;
        v_cost cost_sales_tracker.cost_per_unit%TYPE;
        
    BEGIN
    
        -- if zero quantity, raise error
        IF p_quantity = 0 THEN
            jta_error.throw(-20201, 'cannot update a zero amount to inventory');
        END IF;
        
        
        -- if not actual product raise error
        BEGIN
            -- see if product id exists in product table
            SELECT product_id INTO v_test_id FROM products WHERE product_id = p_product_id;
        EXCEPTION
            WHEN no_data_found THEN
                jta_error.throw(-20201, 'non existing product being updated to inventory');
            WHEN OTHERS THEN
                RAISE; -- outer procedure will deal with it
        END;
        
        
        -- get old total from db, if exists
        v_old_total := 0;
        BEGIN
            SELECT total INTO v_old_total
            FROM cost_sales_tracker
            WHERE product_id = p_product_id 
            AND transaction_id IN (
            SELECT MAX(transaction_id) FROM cost_sales_tracker WHERE product_id = p_product_id);
        EXCEPTION
            WHEN no_data_found THEN
                -- if a previous entry was not made for this product it will remain zero
                NULL; 
            WHEN OTHERS THEN
                RAISE;
        END;
        
        -- get old average if exists
        v_old_avg := 0;
        BEGIN
            SELECT average_cost_per_unit INTO v_old_avg
            FROM cost_sales_tracker
            WHERE product_id = p_product_id 
            AND transaction_id IN (SELECT MAX(transaction_id) FROM cost_sales_tracker 
            WHERE product_id = p_product_id);
        EXCEPTION
            WHEN no_data_found THEN
                -- if we never added a this product before, the old average is zero
                NULL;
            WHEN OTHERS THEN
                RAISE;
        END;
        

        -- update to new total, 
        IF p_quantity > 0 THEN
        
            -- if adding an item, the cost must be positive, otherwise it is ignored
            IF p_new_cost <= 0 OR p_new_cost IS NULL THEN
                jta_error.throw(-20201, 'cannot update inventory with non positive cost per unit');
            ELSE
                v_cost := p_new_cost;            
            END IF;
            
            -- switch direction 
            v_direction := 'IN';
            
            -- update new average
            v_new_avg := ROUND(((v_old_avg * v_old_total) + (p_quantity * p_new_cost) ) / (v_old_total + p_quantity), 2);
            
            -- calculate new total
            v_new_total := v_old_total + p_quantity; 
                
        ELSE
            -- cost is ignored if removing items,
            v_cost := NULL;
            -- average also remains the same
            
            -- reduce quantity (its a negative number)
            v_new_total := v_old_total + p_quantity; 

            -- throw error if negative
            IF v_new_total < 0 THEN
                jta_error.throw(-20201, 'cannot remove more items than already exists in inventory');
            END IF;
            
            -- set old average as new average, 
            -- if old average doesn't exist, the above negative error would have been thrown            
            v_new_avg := v_old_avg; 
            
        END IF;
        
        -- insert data into database
        INSERT INTO cost_sales_tracker (
            transaction_id, product_id, direction, date_time, quantity,
            total, average_cost_per_unit, cost_per_unit
        )
        VALUES (
            transaction_id_seq.NEXTVAL, p_product_id, v_direction, sysdate, p_quantity,
            v_new_total, v_new_avg, v_cost
        );
        
        COMMIT;
        
    EXCEPTION
        WHEN OTHERS THEN
            -- all exceptions will be logged into error table...
            jta_error.log_error(SQLCODE, SQLERRM);  
            ROLLBACK;
    END update_inventory;

    PROCEDURE restock_urgent (
        p_staff_id IN staff.staff_id%TYPE
    )
    IS 

        -- find products that need to be restocked 
        -- by checking reorder-level and min_stock_level and quantity
        -- for a specific supplier's goods and location
        CURSOR urgent(
            p_supplier_id suppliers_per_products.supplier_id%TYPE, 
            p_location_id inventory_by_location.location_id%TYPE
        ) IS
            SELECT inv.product_id, inv.reorder_level 
            FROM inventory_by_location inv
            JOIN products pr ON (inv.product_id = pr.product_id)
            JOIN suppliers_per_products sp ON (sp.product_id = pr.product_id) 
            WHERE inv.reorder_level <= (inv.min_stock_level - inv.quantity)
            AND inv.location_id = p_location_id AND sp.supplier_id = p_supplier_id;

        -- find distinct list of suppliers whose products need restocking
        CURSOR suppliers IS
            SELECT DISTINCT supplier_id, location_id
            FROM inventory_by_location inv
            JOIN products pr ON (inv.product_id = pr.product_id)
            JOIN suppliers_per_products sp ON (sp.product_id = pr.product_id) 
            WHERE inv.reorder_level <= (inv.min_stock_level - inv.quantity);
          
        -- current purchase order being worked on    
        v_current_po purchase_orders.po_id%TYPE;

    BEGIN
        
        -- for all suppliers who need restocking at each inventory location...
        FOR supplier IN suppliers LOOP
            -- create purchase orders for each supplier
            v_current_po := po_id_seq.NEXTVAL;
            INSERT INTO purchase_orders (po_id, supplier_id, staff_id, location_id, pending, approved, submitted_date)
            VALUES (v_current_po, supplier.supplier_id, p_staff_id, supplier.location_id, 'T', 'F', sysdate);

            -- add purchase order lines for this supplier
            FOR stock IN urgent(supplier.supplier_id, supplier.location_id) LOOP
                INSERT INTO purchase_order_lines (po_line_id, po_id, product_id, quantity, price_rate)
                VALUES(po_line_id_seq.NEXTVAL, v_current_po, stock.product_id, stock.reorder_level, NULL );
            END LOOP;
            
        END LOOP;
        
        COMMIT;
        
    EXCEPTION
        WHEN OTHERS THEN
            -- all exceptions will be logged into error table...
            jta_error.log_error(SQLCODE, SQLERRM);    
            ROLLBACK;
    END restock_urgent;

    PROCEDURE evaluate_po_order_line (
        p_line_id IN purchase_order_lines.po_line_id%TYPE,
        p_not_enough_to_restock OUT NOCOPY BOOLEAN,
        p_not_at_min_level OUT NOCOPY BOOLEAN
    )
    IS
        v_quantity_ordered purchase_order_lines.quantity%TYPE;
        v_in_stock inventory_by_location.quantity%TYPE;
        v_min_stock inventory_by_location.min_stock_level%TYPE;
        v_reorder_level inventory_by_location.reorder_level%TYPE;
        
    BEGIN
        
        -- get relevant data for this purchase order line        
        SELECT pol.quantity, inv.quantity, inv.min_stock_level, inv.reorder_level
        INTO v_quantity_ordered, v_in_stock, v_min_stock, v_reorder_level
        FROM purchase_order_lines pol 
        JOIN purchase_orders po ON (po.po_id = pol.po_id) 
        JOIN inventory_by_location inv ON (inv.product_id = pol.product_id AND inv.location_id = po.location_id)
        WHERE pol.po_line_id = p_line_id;
        
        IF (v_in_stock + v_quantity_ordered) < v_min_stock THEN
            p_not_enough_to_restock := TRUE;
        ELSE
            p_not_enough_to_restock := FALSE;
        END IF;
        
        IF v_quantity_ordered < v_reorder_level THEN
            p_not_at_min_level := TRUE;
        ELSE
            p_not_at_min_level := FALSE;
        END IF;
        
    EXCEPTION
        WHEN no_data_found THEN
            -- log a missing data exception
            jta_error.log_error(-20202, 'purchase not exist or inventory has never been added for this item');
            p_not_enough_to_restock := TRUE;
            p_not_at_min_level := TRUE;
        WHEN OTHERS THEN
            -- all OTHER exceptions will be logged into error table...
            jta_error.log_error(SQLCODE, SQLERRM); 
            p_not_enough_to_restock := TRUE;
            p_not_at_min_level := TRUE;
    END evaluate_po_order_line;
END jta_inventory_ops;
/

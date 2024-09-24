CREATE OR REPLACE PACKAGE jta_billing IS
    PROCEDURE add_item_to_bill (
        p_bill_id IN customer_bills.bill_id%TYPE,
        p_barcode IN products.barcode%TYPE
    );
    
    PROCEDURE update_from_bill (
        p_bill_id IN customer_bills.bill_id%TYPE
    );
    
    PROCEDURE update_sales;
    
    FUNCTION receive_payment (
        p_bill_id customer_bills.bill_id%TYPE,
        p_type customer_bills.payment_type%TYPE,
        p_amount customer_bills.payment_amount%TYPE
    ) RETURN NUMBER;

    FUNCTION get_tax_payment_due (
        p_tax_code tax_rates.tax_code%TYPE,
        p_year DATE
    ) RETURN NUMBER;
END jta_billing;
/

CREATE OR REPLACE PACKAGE jta_billing IS

    PROCEDURE add_item_to_bill (
        p_bill_id IN customer_bills.bill_id%TYPE,
        p_barcode IN products.barcode%TYPE
    )
    IS 
        
        v_price products.price_rate%TYPE;
        v_product_id products.product_id%TYPE;
        v_tax_code tax_rates.tax_code%TYPE;
        v_tax_rate tax_rates.tax_rate%TYPE;
        v_line_id billed_items.bill_line_id%TYPE := NULL;
        v_bill_id customer_bills.bill_id%TYPE;
        
        -- not used in this function, but retrieved in lookup_barcode procedure
        v_name products.product_name%TYPE;
        
        
    BEGIN 
        -- if bill already paid or pending then throw exception,
        BEGIN
            SELECT bill_id INTO v_bill_id 
            FROM customer_bills 
            WHERE bill_id = p_bill_id AND payment_status = 'unpaid'; 
                -- exception thrown here if status not unpaid
                -- payment_status column constrained to paid, pending and unpaid via DDL 
        EXCEPTION
            WHEN no_data_found THEN
                jta_error.throw(-20201, 'failed to update bill items because bill status not unpaid');
        END;
        
        -- find price and tax info using lookup_barcode procedure
        jta.lookup_barcode (p_barcode, v_product_id, v_name, v_price, v_tax_code, v_tax_rate);
        -- test if item already in bill 
        -- the same item may be cashed several times e.g. customer buys to sacks of flour
        BEGIN
            -- query billed_items to see if this product exists for this bill
            SELECT bill_line_id INTO v_line_id 
            FROM billed_items 
            WHERE product_id = v_product_id AND bill_id = p_bill_id;
        EXCEPTION
            WHEN no_data_found THEN 
                NULL; -- ignore and proceed
        END; 
        
        -- item alread exists, will update its quantity
        IF v_line_id IS NOT NULL THEN
            UPDATE billed_items SET
                quantity = quantity + 1
            WHERE bill_line_id = v_line_id;
            
        -- otherwise, insert new item for this product
        ELSE
            INSERT INTO billed_items (
                bill_line_id, bill_id, product_id, quantity, 
                price_rate, tax_code, tax_rate
            )
            VALUES (
                bill_line_id_seq.NEXTVAL, p_bill_id, v_product_id, 1,
                v_price, v_tax_code, v_tax_rate
            );
        END IF;
        
        -- update price of bill,
        UPDATE customer_bills SET
            payment_tender = nvl(payment_tender, 0) + v_price
        WHERE bill_id = p_bill_id;

        COMMIT;
    EXCEPTION
        WHEN jta_error.invalid_input THEN
            -- this code can change to invoke an application layer event or something...
            jta_error.show_in_console(SQLCODE, SQLERRM);
            ROLLBACK;
        WHEN OTHERS THEN
            -- all OTHER exceptions will be logged into error table regardless
            jta_error.log_error(SQLCODE, SQLERRM);
            ROLLBACK;
    END add_item_to_bill;

    PROCEDURE update_from_bill (
        p_bill_id IN customer_bills.bill_id%TYPE
    )
    IS 
        -- products, and their inventory location from current bill
        CURSOR items_in_bill IS
            SELECT bit.product_id, inv.location_id, bit.quantity, pr.barcode 
            FROM billed_items bit 
            JOIN customer_bills cb ON (bit.bill_id = cb.bill_id)
            JOIN products pr ON (pr.product_id = bit.product_id)
            JOIN cashier_drawer_assignments cda ON (cda.assignment_id = cb.assignment_id)
            JOIN cashier_stations cs ON (cs.station_id = cda.station_id)
            JOIN inventory_by_location inv ON (cs.location_id = inv.location_id 
                AND bit.product_id = inv.product_id)
            WHERE cb.bill_id = p_bill_id
            FOR UPDATE OF inv.quantity; -- for update lock to prevent issues
                
    BEGIN
    
        FOR item IN items_in_bill LOOP
            -- if the product is not a plu item then we track it in inventory 
            -- (see barcode info in document appendix)
            IF item.barcode IS NOT NULL THEN
            
                -- if one item throws an excpetion, we still want to 
                -- proceed through the cursor to other items
                -- hence, we have this sub-block to catch exceptions here
                BEGIN
                    -- updates don't throw errors if 0 rows updated
                    UPDATE inventory_by_location SET
                        quantity = quantity - item.quantity
                    WHERE product_id = item.product_id AND location_id = item.location_id;
                    -- throw error if didn't update anything
                    IF SQL%rowcount = 0 THEN
                        jta_error.throw(-20202, 'product not in inventory');
                    END IF;
                    -- insert into sold products, 
                    -- only inserts if above exception was not thrown
                    INSERT INTO sold_products (sold_products_id, product_id, quantity)
                    VALUES (sold_products_seq.NEXTVAL, item.product_id, item.quantity);
                EXCEPTION
                    WHEN OTHERS THEN
                        -- log all errors regardless of type (including 20202)
                        jta_error.log_error(SQLCODE, SQLERRM);
                        -- then proceed through cursor
                END;
            END IF;
        END LOOP;
        
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            -- all OTHER exceptions will be logged into error table as well
            jta_error.log_error(SQLCODE, SQLERRM);
            ROLLBACK; -- roll back only if something terrible happened
    END update_from_bill;

    PROCEDURE update_sales 
    IS 
        -- current date to add cost_sales_tracker
        v_date DATE := sysdate;
        
        -- index by to bulk collect all products sold
        TYPE v_sold_products IS TABLE OF sold_products%ROWTYPE 
        INDEX BY BINARY_INTEGER;
        v_all v_sold_products;
        
        -- collection to hold sum of quantities
        TYPE v_sum_type IS TABLE OF sold_products.quantity%TYPE
        INDEX BY BINARY_INTEGER;
        v_sum v_sum_type;
        
        -- hold current quantity from collection
        v_current_sum sold_products.quantity%TYPE;
        v_current_product sold_products.product_id%TYPE;
    BEGIN
        -- perform a commit, 
        -- if application freezes and a rollback is needed because we 
        -- locked a bunch of tables without unlocking them, it will rollback
        -- to this point. 
        COMMIT;
        
        -- lock the tables before doing anything
        LOCK TABLE sold_products, customer_bills, billed_items IN EXCLUSIVE MODE NOWAIT;
    
        -- bulk collect all rows
        SELECT * BULK COLLECT INTO v_all FROM sold_products 
        ORDER BY product_id;
        -- loop through all and records and sum up products quantities 
        -- into v_sum collection
        FOR indx IN v_all.FIRST..v_all.LAST LOOP
            -- try to update v_sum as if it already has an entry for this product
            BEGIN
                v_current_product := v_all(indx).product_id;
                v_current_sum := v_sum(v_current_product);
                v_sum(v_current_product) := v_current_sum + v_all(indx).quantity;
            EXCEPTION
                -- if the above throws a no data found exception,
                -- it means we didn't have an entry before,
                -- now we insert a new one like normal
                WHEN no_data_found THEN
                v_sum(v_all(indx).product_id) := v_all(indx).quantity;
            END;
            --dbms_output.put_line(v_all(indx).product_id || ' - ' || v_sum(v_all(indx).product_id) );
        END LOOP;
        
        -- update inventory
        FOR indx IN v_sum.FIRST..v_sum.LAST LOOP
            --dbms_output.put_line(indx || ' - ' || (v_sum(indx) * -1) );
            update_inventory (indx, (v_sum(indx) * -1), NULL);
        END LOOP;
        
        -- remove all entries from sold_products table
        DELETE FROM sold_products;
        
        -- a commit here or a rollback in the excpetion will unlock all the locked tables
        COMMIT;
    EXCEPTION
        WHEN no_data_found THEN
        -- there was nothing to update, this isn't an error per se
        dbms_output.put_line('*alert application layer*, there was no data to update');
        WHEN OTHERS THEN
            -- all exceptions will be logged into error table regardless
            jta_error.log_error(SQLCODE, SQLERRM);
            ROLLBACK; 
    END update_sales;

    FUNCTION receive_payment (
        p_bill_id customer_bills.bill_id%TYPE,
        p_type customer_bills.payment_type%TYPE,
        p_amount customer_bills.payment_amount%TYPE
    ) RETURN NUMBER
    IS 
        -- this function performs DML, therefore it is set to autonomous
        -- that way it won't cause issues like committing during a query
        PRAGMA autonomous_transaction;
        
        -- hold amount due
        v_tender customer_bills.payment_tender%TYPE;
        -- hold previous payment if exists
        v_prev customer_bills.payment_amount%TYPE;
        -- hold cashier assigned to bill
        v_assignment customer_bills.assignment_id%TYPE;
        -- return cash amount (change for customer)
        v_return_change NUMBER := 0;
        -- hold status of this bill
        v_status customer_bills.payment_status%TYPE;
        -- update inventory after payment received?
        v_do_update_inventory BOOLEAN := TRUE;
        
    BEGIN 
        
        -- check payment type, throw (raise) error if not valid
        IF p_type NOT IN ('cash', 'cheque', 'creditcard', 'linx') THEN
            jta_error.throw(-20201, 'invalid payment type, valid types: cash, cheque, creditcard, linx');
        END IF;
    
        -- get tender (amount due) from bill
        SELECT assignment_id, nvl(payment_tender, 0), nvl(payment_amount, 0), nvl(payment_status, 'unpaid') 
        INTO v_assignment, v_tender, v_prev, v_status
        FROM customer_bills WHERE bill_id = p_bill_id;
        
        -- check if already paid, throw (raise) error if it did
        IF v_status = 'paid' THEN
            -- throw (raise) invalid input error
            jta_error.throw(-20201, 'attempt to pay on bill that has already received full payment');
        end if;
        
        -- check if amount is valid, change status depending on if full amount is paid
        IF p_amount <= 0 THEN
            -- throw (raise) invalid input error
            jta_error.throw(-20201, 'invalid money amount, negative number');
        end if;
        
        -- check if bill is pending (has previous payment on it)
        IF v_status = 'pending' THEN
            -- amount due is now less
            v_tender := v_tender - v_prev;
            v_do_update_inventory := FALSE; -- no need to remove items from inventory
        END IF;
        
        -- perform new payment calculation
        IF p_amount < v_tender THEN
            -- no change given, however bill is set to pending...
            -- this means that the customer owes the supermaket money
            -- sometimes they let frequent customers do this if they forget their wallet etc.
            -- the goods are usually kept at the grocery (in a special area) until the full amount is paid
            -- or sometimes they will let the customer leave with the goods if they the owners trust them.
            v_status := 'pending';
        ELSE
            v_status := 'paid';
            -- calculate change, 
                -- **note: although non cash payments usually do not have change,
                -- sometimes a customer will request to pay more than the bill amount in order to receive change.
                -- otherwise the exact value is processed, which results in zero change here.
            v_return_change := p_amount - v_tender;
        END IF;    
        
        -- update bill with payment
        UPDATE customer_bills SET
            payment_amount = v_prev + (p_amount - v_return_change),
            payment_type = p_type,
            payment_status = v_status,
            date_time_paid = sysdate
        WHERE bill_id = p_bill_id;
        
        -- if paying in cash, update cashier's cash on hand
        IF p_type = 'cash' THEN
            -- update cashier cash amount on hand
            UPDATE cashier_drawer_assignments SET
                cash_amount_end = nvl(cash_amount_end, 0) + (p_amount - v_return_change)
            WHERE assignment_id = v_assignment;
        
        -- if non-cash, then update non_cash_tender
        ELSE
            UPDATE cashier_drawer_assignments SET
                non_cash_tender = nvl(non_cash_tender, 0) + p_amount,
                cash_amount_end = nvl(cash_amount_end, 0) - v_return_change
            WHERE assignment_id = v_assignment;
        END IF;
        
        -- MAGIC!! call procedure to update inventory for bill, only if status was not pending
        IF v_do_update_inventory THEN
            jta.update_from_bill(p_bill_id);
        END IF;
        
        COMMIT;
        RETURN v_return_change;
    EXCEPTION 
        WHEN jta_error.invalid_input THEN
            -- if amount is less than payment, then this error isn't logged,
            -- however the application layer should be alerted.
            jta_error.show_in_console(SQLCODE, SQLERRM);
            ROLLBACK;
            RETURN NULL;
        WHEN OTHERS THEN
            -- all exceptions will be logged into error table regardless
            jta_error.log_error(SQLCODE, SQLERRM);
            ROLLBACK; 
            RETURN NULL;
    END receive_payment;

    FUNCTION get_tax_payment_due (
        p_tax_code tax_rates.tax_code%TYPE,
        p_year DATE
    ) RETURN NUMBER
    IS 
        v_begin DATE;
        v_end DATE;
        v_tax_value NUMBER;
    BEGIN 
        -- sysdate can be passed in to find out for this year, 
        -- therefore we need to find the begin and end for the year provided
        v_begin := TRUNC(p_year, 'YEAR');
        -- for end, we add 12 months, then subract one day
        -- then add 23 hours, 59 mins and 59 seconds
        v_end := add_months(v_begin, 12); 
        v_end := v_end - 1;
        v_end := v_end + numtodsinterval(23, 'hour');
        v_end := v_end + numtodsinterval(59, 'minute');
        v_end := v_end + numtodsinterval(59, 'second'); 
            -- since we don't use timestamps, we don't have to add milliseconds.
            -- it was decided that bills, payroll and other transactions only needed 
            -- to record up the the seconds time frame and there is no security or 
            -- liability difference between 11:50:59.0000 and 11:50:59.9999

        -- get tax value from querying bills        
        SELECT SUM(ROUND(((tax_rate/100) * (price_rate * quantity)), 2))
        INTO v_tax_value
        FROM billed_items bi JOIN customer_bills cb ON (bi.bill_id = cb.bill_id)
        WHERE cb.date_time_created BETWEEN v_begin AND v_end
        AND bi.tax_code = p_tax_code;
        
        RETURN v_tax_value;
        
        /*
            Development Note:
            since this query is likely to end up processing millions of rows,
            it will probably be very slow and should run after business hours.
            
            thankfully, the company usually closes for stock taking during 
            the new years holdiday, at which time they do these kinds of queries.
            
            Further note: 
            bulk collect may not solve this issue since it is aggregate function 
            (one context switch). One possible solution is to modify the database 
            to use plsql to save tax payout in a table everytime a bill is processed.
            much like the sold_products table. However, they might not want the day to day 
            overhead and would most likely double check billed_items anyway. 
        */
    EXCEPTION 
        WHEN no_data_found THEN
            -- return zero if no data, 
            -- this means the supermarket didn't sell anything for that year (incorrect date provided?)
            RETURN 0;
        WHEN OTHERS THEN
            -- log error and return null if other exceptions occur
            jta_error.log_error(SQLCODE, SQLERRM);
            RETURN NULL;
    END get_tax_payment_due;

END jta_billing;
/
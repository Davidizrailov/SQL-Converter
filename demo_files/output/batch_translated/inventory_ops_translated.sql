```sql
CREATE OR REPLACE PROCEDURE update_inventory(p_product_id STRING, p_quantity NUMBER, p_new_cost NUMBER)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'update_inventory_handler'
AS
$$
import snowflake.snowpark as snowpark
from snowflake.snowpark.exceptions import SnowparkSQLException

def update_inventory_handler(session: snowpark.Session, p_product_id: str, p_quantity: int, p_new_cost: float) -> str:
    try:
        # Check if quantity is zero
        if p_quantity == 0:
            raise ValueError('Cannot update a zero amount to inventory')

        # Verify if product exists
        product_check = session.sql(f"SELECT product_id FROM products WHERE product_id = '{p_product_id}'").collect()
        if not product_check:
            raise ValueError('Non-existing product being updated to inventory')

        # Get old total and average cost
        old_total = session.sql(f"""
            SELECT total FROM cost_sales_tracker
            WHERE product_id = '{p_product_id}' 
            AND transaction_id = (SELECT MAX(transaction_id) FROM cost_sales_tracker WHERE product_id = '{p_product_id}')
        """).collect()
        old_total = old_total[0]['TOTAL'] if old_total else 0

        old_avg = session.sql(f"""
            SELECT average_cost_per_unit FROM cost_sales_tracker
            WHERE product_id = '{p_product_id}' 
            AND transaction_id = (SELECT MAX(transaction_id) FROM cost_sales_tracker WHERE product_id = '{p_product_id}')
        """).collect()
        old_avg = old_avg[0]['AVERAGE_COST_PER_UNIT'] if old_avg else 0

        # Calculate new total and average cost
        if p_quantity > 0:
            if p_new_cost <= 0 or p_new_cost is None:
                raise ValueError('Cannot update inventory with non-positive cost per unit')
            new_avg = round(((old_avg * old_total) + (p_quantity * p_new_cost)) / (old_total + p_quantity), 2)
            new_total = old_total + p_quantity
        else:
            new_total = old_total + p_quantity
            if new_total < 0:
                raise ValueError('Cannot remove more items than already exist in inventory')
            new_avg = old_avg

        # Insert updated inventory data
        session.sql(f"""
            INSERT INTO cost_sales_tracker (transaction_id, product_id, direction, date_time, quantity, total, average_cost_per_unit, cost_per_unit)
            VALUES (transaction_id_seq.NEXTVAL, '{p_product_id}', '{'IN' if p_quantity > 0 else 'OUT'}', CURRENT_TIMESTAMP, {p_quantity}, {new_total}, {new_avg}, {p_new_cost if p_quantity > 0 else 'NULL'})
        """).collect()
        session.commit()
        return "Inventory updated successfully"
    except Exception as e:
        session.rollback()
        session.sql(f"INSERT INTO error_log (error_code, error_message) VALUES ({e.args[0]}, '{str(e)}')").collect()
        return str(e)
$$;

CREATE OR REPLACE PROCEDURE restock_urgent(p_staff_id STRING)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'restock_urgent_handler'
AS
$$
import snowflake.snowpark as snowpark

def restock_urgent_handler(session: snowpark.Session, p_staff_id: str) -> str:
    try:
        suppliers = session.sql("""
            SELECT DISTINCT supplier_id, location_id
            FROM inventory_by_location inv
            JOIN products pr ON inv.product_id = pr.product_id
            JOIN suppliers_per_products sp ON sp.product_id = pr.product_id
            WHERE inv.reorder_level <= (inv.min_stock_level - inv.quantity)
        """).collect()

        for supplier in suppliers:
            v_current_po = session.sql("SELECT po_id_seq.NEXTVAL").collect()[0]['NEXTVAL']
            session.sql(f"""
                INSERT INTO purchase_orders (po_id, supplier_id, staff_id, location_id, pending, approved, submitted_date)
                VALUES ({v_current_po}, '{supplier['SUPPLIER_ID']}', '{p_staff_id}', '{supplier['LOCATION_ID']}', 'T', 'F', CURRENT_TIMESTAMP)
            """).collect()

            urgent = session.sql(f"""
                SELECT inv.product_id, inv.reorder_level 
                FROM inventory_by_location inv
                JOIN products pr ON inv.product_id = pr.product_id
                JOIN suppliers_per_products sp ON sp.product_id = pr.product_id
                WHERE inv.reorder_level <= (inv.min_stock_level - inv.quantity)
                AND inv.location_id = '{supplier['LOCATION_ID']}' AND sp.supplier_id = '{supplier['SUPPLIER_ID']}'
            """).collect()

            for stock in urgent:
                session.sql(f"""
                    INSERT INTO purchase_order_lines (po_line_id, po_id, product_id, quantity, price_rate)
                    VALUES (po_line_id_seq.NEXTVAL, {v_current_po}, '{stock['PRODUCT_ID']}', {stock['REORDER_LEVEL']}, NULL)
                """).collect()

        session.commit()
        return "Urgent restock completed successfully"
    except Exception as e:
        session.rollback()
        session.sql(f"INSERT INTO error_log (error_code, error_message) VALUES ({e.args[0]}, '{str(e)}')").collect()
        return str(e)
$$;

CREATE OR REPLACE PROCEDURE evaluate_po_order_line(p_line_id STRING)
RETURNS TABLE (p_not_enough_to_restock BOOLEAN, p_not_at_min_level BOOLEAN)
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'evaluate_po_order_line_handler'
AS
$$
import snowflake.snowpark as snowpark

def evaluate_po_order_line_handler(session: snowpark.Session, p_line_id: str):
    try:
        result = session.sql(f"""
            SELECT pol.quantity, inv.quantity, inv.min_stock_level, inv.reorder_level
            FROM purchase_order_lines pol 
            JOIN purchase_orders po ON po.po_id = pol.po_id 
            JOIN inventory_by_location inv ON inv.product_id = pol.product_id AND inv.location_id = po.location_id
            WHERE pol.po_line_id = '{p_line_id}'
        """).collect()

        if not result:
            raise ValueError('Purchase order line does not exist or inventory has never been added for this item')

        v_quantity_ordered = result[0]['QUANTITY']
        v_in_stock = result[0]['QUANTITY']
        v_min_stock = result[0]['MIN_STOCK_LEVEL']
        v_reorder_level = result[0]['REORDER_LEVEL']

        p_not_enough_to_restock = (v_in_stock + v_quantity_ordered) < v_min_stock
        p_not_at_min_level = v_quantity_ordered < v_reorder_level

        return [(p_not_enough_to_restock, p_not_at_min_level)]
    except Exception as e:
        session.sql(f"INSERT INTO error_log (error_code, error_message) VALUES ({e.args[0]}, '{str(e)}')").collect()
        return [(True, True)]
$$;

-- Call the procedures
CALL update_inventory('product_123', 10, 5.0);
CALL restock_urgent('staff_456');
CALL evaluate_po_order_line('po_line_789');
```
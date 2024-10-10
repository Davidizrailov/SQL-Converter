```python
CREATE OR REPLACE PROCEDURE update_inventory(
    p_product_id STRING,
    p_quantity NUMBER,
    p_new_cost NUMBER
)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'update_inventory_handler'
AS
$$
def update_inventory_handler(session, p_product_id, p_quantity, p_new_cost):
    from snowflake.snowpark.exceptions import SnowparkSQLException
    import snowflake.snowpark.functions as F

    try:
        if p_quantity == 0:
            raise ValueError('cannot update a zero amount to inventory')

        # Check if product exists
        product = session.table("products").filter(F.col("product_id") == p_product_id).collect()
        if not product:
            raise ValueError('non existing product being updated to inventory')

        # Get old total
        v_old_total = 0
        try:
            v_old_total = session.table("cost_sales_tracker").filter(
                (F.col("product_id") == p_product_id) &
                (F.col("transaction_id") == session.table("cost_sales_tracker")
                 .filter(F.col("product_id") == p_product_id)
                 .select(F.max("transaction_id")).collect()[0][0])
            ).select("total").collect()[0][0]
        except SnowparkSQLException:
            v_old_total = 0

        # Get old average
        v_old_avg = 0
        try:
            v_old_avg = session.table("cost_sales_tracker").filter(
                (F.col("product_id") == p_product_id) &
                (F.col("transaction_id") == session.table("cost_sales_tracker")
                 .filter(F.col("product_id") == p_product_id)
                 .select(F.max("transaction_id")).collect()[0][0])
            ).select("average_cost_per_unit").collect()[0][0]
        except SnowparkSQLException:
            v_old_avg = 0

        # Update new values
        if p_quantity > 0:
            if p_new_cost <= 0 or p_new_cost is None:
                raise ValueError('cannot update inventory with non positive cost per unit')
            v_cost = p_new_cost
            v_direction = 'IN'
            v_new_avg = round(((v_old_avg * v_old_total) + (p_quantity * p_new_cost)) / (v_old_total + p_quantity), 2)
            v_new_total = v_old_total + p_quantity
        else:
            v_cost = None
            v_new_total = v_old_total + p_quantity
            if v_new_total < 0:
                raise ValueError('cannot remove more items than already exists in inventory')
            v_new_avg = v_old_avg
            v_direction = 'OUT'

        # Insert new record
        session.table("cost_sales_tracker").insert((session.table("transaction_id_seq").select(F.nextval("transaction_id_seq")).collect()[0][0],
                                                    p_product_id, v_direction, F.current_timestamp(), p_quantity,
                                                    v_new_total, v_new_avg, v_cost))
        session.commit()
        return "Inventory updated successfully."
    except Exception as e:
        session.rollback()
        session.sql("CALL jta_error.log_error(?, ?)", (e.args[0], str(e))).collect()
        return str(e)
$$;

CALL update_inventory('PRODUCT_123', 10, 15.0);

CREATE OR REPLACE PROCEDURE restock_urgent(
    p_staff_id STRING
)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'restock_urgent_handler'
AS
$$
def restock_urgent_handler(session, p_staff_id):
    try:
        suppliers = session.sql("""
            SELECT DISTINCT sp.supplier_id, inv.location_id
            FROM inventory_by_location inv
            JOIN products pr ON (inv.product_id = pr.product_id)
            JOIN suppliers_per_products sp ON (sp.product_id = pr.product_id) 
            WHERE inv.reorder_level <= (inv.min_stock_level - inv.quantity)
        """).collect()

        for supplier in suppliers:
            v_current_po = session.sql("SELECT po_id_seq.NEXTVAL").collect()[0]['NEXTVAL']
            session.sql(f"""
                INSERT INTO purchase_orders (po_id, supplier_id, staff_id, location_id, pending, approved, submitted_date)
                VALUES ({v_current_po}, {supplier['SUPPLIER_ID']}, {p_staff_id}, {supplier['LOCATION_ID']}, 'T', 'F', CURRENT_TIMESTAMP())
            """).collect()

            urgent_products = session.sql(f"""
                SELECT inv.product_id, inv.reorder_level 
                FROM inventory_by_location inv
                JOIN products pr ON (inv.product_id = pr.product_id)
                JOIN suppliers_per_products sp ON (sp.product_id = pr.product_id)
                WHERE inv.reorder_level <= (inv.min_stock_level - inv.quantity)
                AND inv.location_id = {supplier['LOCATION_ID']} AND sp.supplier_id = {supplier['SUPPLIER_ID']}
            """).collect()

            for product in urgent_products:
                session.sql(f"""
                    INSERT INTO purchase_order_lines (po_line_id, po_id, product_id, quantity, price_rate)
                    VALUES (po_line_id_seq.NEXTVAL, {v_current_po}, {product['PRODUCT_ID']}, {product['REORDER_LEVEL']}, NULL)
                """).collect()

        session.commit()
        return "Restock process completed successfully."
    except Exception as e:
        session.rollback()
        session.sql("CALL jta_error.log_error(?, ?)", (e.args[0], str(e))).collect()
        return str(e)
$$;

CALL restock_urgent('STAFF_001');

CREATE OR REPLACE PROCEDURE evaluate_po_order_line(
    p_line_id STRING,
    p_not_enough_to_restock BOOLEAN,
    p_not_at_min_level BOOLEAN
)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'evaluate_po_order_line_handler'
AS
$$
def evaluate_po_order_line_handler(session, p_line_id, p_not_enough_to_restock, p_not_at_min_level):
    try:
        result = session.sql(f"""
            SELECT pol.quantity, inv.quantity, inv.min_stock_level, inv.reorder_level
            FROM purchase_order_lines pol 
            JOIN purchase_orders po ON (po.po_id = pol.po_id) 
            JOIN inventory_by_location inv ON (inv.product_id = pol.product_id AND inv.location_id = po.location_id)
            WHERE pol.po_line_id = {p_line_id}
        """).collect()

        if not result:
            session.sql("CALL jta_error.log_error(?, ?)", (-20202, 'purchase not exist or inventory has never been added for this item')).collect()
            return "Error: Missing data."

        v_quantity_ordered = result[0]['QUANTITY']
        v_in_stock = result[0]['QUANTITY_1']
        v_min_stock = result[0]['MIN_STOCK_LEVEL']
        v_reorder_level = result[0]['REORDER_LEVEL']

        p_not_enough_to_restock = (v_in_stock + v_quantity_ordered) < v_min_stock
        p_not_at_min_level = v_quantity_ordered < v_reorder_level

        return "Purchase order line evaluated successfully."
    except Exception as e:
        session.rollback()
        session.sql("CALL jta_error.log_error(?, ?)", (e.args[0], str(e))).collect()
        return str(e)
$$;

CALL evaluate_po_order_line('LINE_001', FALSE, FALSE);
```
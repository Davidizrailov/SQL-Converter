CREATE OR REPLACE PROCEDURE jta_inventory_ops()
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'main'
AS
$$
import snowflake.snowpark as snowpark
from snowflake.snowpark.functions import col, lit
from snowflake.snowpark import Session
import sys

def update_inventory(session, product_id, quantity, cost):
    try:
        if quantity == 0:
            return "Quantity to update is zero. No action taken."

        product = session.table("products").filter(col("product_id") == product_id).collect()
        if not product:
            raise ValueError(f"Product with ID {product_id} not found.")

        old_data = session.table("inventory").filter(col("product_id") == product_id).select("total_quantity", "average_cost").collect()[0]
        old_total = old_data["TOTAL_QUANTITY"]
        old_avg_cost = old_data["AVERAGE_COST"]

        new_total = old_total + quantity
        new_avg_cost = ((old_total * old_avg_cost) + (quantity * cost)) / new_total

        session.table("inventory").update(
            {"total_quantity": new_total, "average_cost": new_avg_cost},
            col("product_id") == product_id
        )

        session.table("cost_sales_tracker").insert({
            "product_id": product_id,
            "quantity": quantity,
            "cost": cost,
            "transaction_type": "UPDATE"
        })

        return "Inventory updated successfully."
    except Exception as e:
        return f"Error in update_inventory: {str(e)}"

def restock_urgent(session):
    try:
        restock_products = session.sql("""
            SELECT p.product_id, p.supplier_id, i.reorder_level - i.total_quantity AS quantity_to_order
            FROM products p
            JOIN inventory i ON p.product_id = i.product_id
            WHERE i.total_quantity < i.reorder_level
        """).collect()

        for product in restock_products:
            po_id = session.sql("SELECT NVL(MAX(po_id), 0) + 1 AS new_po_id FROM purchase_orders").collect()[0]["NEW_PO_ID"]
            
            session.table("purchase_orders").insert({
                "po_id": po_id,
                "supplier_id": product["SUPPLIER_ID"],
                "order_date": "CURRENT_DATE()",
                "status": "PENDING"
            })

            session.table("purchase_order_lines").insert({
                "po_id": po_id,
                "product_id": product["PRODUCT_ID"],
                "quantity": product["QUANTITY_TO_ORDER"]
            })

        return "Urgent restocking completed."
    except Exception as e:
        return f"Error in restock_urgent: {str(e)}"

def evaluate_po_order_line(session, po_id, product_id):
    try:
        po_line = session.sql(f"""
            SELECT pol.quantity AS ordered_quantity,
                   i.total_quantity AS current_stock,
                   i.minimum_stock,
                   i.reorder_level
            FROM purchase_order_lines pol
            JOIN inventory i ON pol.product_id = i.product_id
            WHERE pol.po_id = {po_id} AND pol.product_id = {product_id}
        """).collect()

        if not po_line:
            raise ValueError(f"Purchase order line not found for PO ID {po_id} and Product ID {product_id}")

        data = po_line[0]
        ordered_quantity = data["ORDERED_QUANTITY"]
        current_stock = data["CURRENT_STOCK"]
        minimum_stock = data["MINIMUM_STOCK"]
        reorder_level = data["REORDER_LEVEL"]

        is_sufficient = (current_stock + ordered_quantity) >= minimum_stock
        meets_min_level = ordered_quantity >= (reorder_level - current_stock)

        return f"Is sufficient: {is_sufficient}, Meets minimum level: {meets_min_level}"
    except Exception as e:
        return f"Error in evaluate_po_order_line: {str(e)}"

def main(session: snowpark.Session):
    try:
        # Example calls to the procedures
        update_result = update_inventory(session, 1, 10, 100.0)
        restock_result = restock_urgent(session)
        evaluate_result = evaluate_po_order_line(session, 1, 1)

        return f"Update Inventory: {update_result}\nRestock Urgent: {restock_result}\nEvaluate PO Order Line: {evaluate_result}"
    except Exception as e:
        return f"Error in main procedure: {str(e)}"
$$;

CALL jta_inventory_ops();
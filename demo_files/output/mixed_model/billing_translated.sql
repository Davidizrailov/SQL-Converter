```python
CREATE OR REPLACE PROCEDURE jta_billing()
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'main'
AS
$$
import snowflake.snowpark as snowpark
from snowflake.snowpark.functions import col, lit

def main(session):

    def add_item_to_bill(p_bill_id, p_barcode):
        try:
            # Check if bill is unpaid
            bill = session.table("customer_bills").filter(col("bill_id") == p_bill_id).filter(col("payment_status") == 'unpaid').collect()
            if not bill:
                raise ValueError("Failed to update bill items because bill status not unpaid")

            # Lookup product details
            product_info = session.call("jta.lookup_barcode", p_barcode)
            v_product_id = product_info['product_id']
            v_price = product_info['price_rate']
            v_tax_code = product_info['tax_code']
            v_tax_rate = product_info['tax_rate']

            # Check if item already in bill
            billed_item = session.table("billed_items").filter(col("product_id") == v_product_id).filter(col("bill_id") == p_bill_id).collect()

            if billed_item:
                # Update quantity if item exists
                session.table("billed_items").update({"quantity": col("quantity") + 1}, (col("bill_line_id") == billed_item[0]["bill_line_id"]))
            else:
                # Insert new item if it doesn't exist
                session.table("billed_items").insert({
                    "bill_line_id": session.sql("SELECT bill_line_id_seq.NEXTVAL").collect()[0][0],
                    "bill_id": p_bill_id,
                    "product_id": v_product_id,
                    "quantity": 1,
                    "price_rate": v_price,
                    "tax_code": v_tax_code,
                    "tax_rate": v_tax_rate
                })

            # Update bill total
            session.table("customer_bills").update(
                {"payment_tender": col("payment_tender").coalesce(0) + v_price},
                (col("bill_id") == p_bill_id)
            )
            session.commit()
        except Exception as e:
            session.rollback()
            raise e

    def update_from_bill(p_bill_id):
        try:
            items_in_bill = session.sql(f"""
                SELECT bit.product_id, inv.location_id, bit.quantity, pr.barcode 
                FROM billed_items bit 
                JOIN customer_bills cb ON bit.bill_id = cb.bill_id
                JOIN products pr ON pr.product_id = bit.product_id
                JOIN cashier_drawer_assignments cda ON cda.assignment_id = cb.assignment_id
                JOIN cashier_stations cs ON cs.station_id = cda.station_id
                JOIN inventory_by_location inv ON cs.location_id = inv.location_id 
                    AND bit.product_id = inv.product_id
                WHERE cb.bill_id = {p_bill_id}
            """).collect()

            for item in items_in_bill:
                if item["barcode"]:
                    # Update inventory
                    updated = session.table("inventory_by_location").update(
                        {"quantity": col("quantity") - item["quantity"]},
                        (col("product_id") == item["product_id"]) & (col("location_id") == item["location_id"])
                    )
                    
                    if updated == 0:
                        raise ValueError("Product not in inventory")

                    # Insert into sold products
                    session.table("sold_products").insert({
                        "sold_products_id": session.sql("SELECT sold_products_seq.NEXTVAL").collect()[0][0],
                        "product_id": item["product_id"],
                        "quantity": item["quantity"]
                    })
            session.commit()
        except Exception as e:
            session.rollback()
            raise e

    def update_sales():
        try:
            session.commit()
            session.sql("LOCK TABLE sold_products, customer_bills, billed_items IN EXCLUSIVE MODE").collect()
            
            sold_products = session.sql("SELECT * FROM sold_products ORDER BY product_id").collect()
            v_sum = {}
            
            for row in sold_products:
                v_sum[row['product_id']] = v_sum.get(row['product_id'], 0) + row['quantity']
            
            for product_id, quantity in v_sum.items():
                session.call("update_inventory", product_id, -quantity, None)
            
            session.sql("DELETE FROM sold_products").collect()
            session.commit()
        
        except Exception as e:
            session.rollback()
            raise e

    def receive_payment(p_bill_id, p_type, p_amount):
        try:
            if p_type not in ('cash', 'cheque', 'creditcard', 'linx'):
                raise ValueError("Invalid payment type")

            bill_info = session.sql(f"""
                SELECT assignment_id, COALESCE(payment_tender, 0), COALESCE(payment_amount, 0), COALESCE(payment_status, 'unpaid') 
                FROM customer_bills WHERE bill_id = {p_bill_id}
            """).collect()[0]
            
            v_tender = bill_info['payment_tender']
            v_prev = bill_info['payment_amount']
            v_status = bill_info['payment_status']
            v_assignment = bill_info['assignment_id']
            v_return_change = 0
            v_do_update_inventory = True

            if v_status == 'paid':
                raise ValueError("Bill already paid")

            if p_amount <= 0:
                raise ValueError("Invalid money amount")

            if v_status == 'pending':
                v_tender -= v_prev
                v_do_update_inventory = False

            if p_amount < v_tender:
                v_status = 'pending'
            else:
                v_status = 'paid'
                v_return_change = p_amount - v_tender

            session.sql(f"""
                UPDATE customer_bills SET
                    payment_amount = {v_prev} + ({p_amount} - {v_return_change}),
                    payment_type = {p_type},
                    payment_status = {v_status},
                    date_time_paid = CURRENT_TIMESTAMP()
                WHERE bill_id = {p_bill_id}
            """).collect()

            if p_type == 'cash':
                session.sql(f"""
                    UPDATE cashier_drawer_assignments SET
                        cash_amount_end = COALESCE(cash_amount_end, 0) + ({p_amount} - {v_return_change})
                    WHERE assignment_id = {v_assignment}
                """).collect()
            else:
                session.sql(f"""
                    UPDATE cashier_drawer_assignments SET
                        non_cash_tender = COALESCE(non_cash_tender, 0) + {p_amount},
                        cash_amount_end = COALESCE(cash_amount_end, 0) - {v_return_change}
                    WHERE assignment_id = {v_assignment}
                """).collect()

            if v_do_update_inventory:
                update_from_bill(p_bill_id)

            session.commit()
            return v_return_change

        except Exception as e:
            session.rollback()
            raise e

    def get_tax_payment_due(p_tax_code, p_year):
        try:
            v_begin = session.sql(f"SELECT DATE_TRUNC('YEAR', {p_year})").collect()[0][0]
            v_end = session.sql(f"SELECT {v_begin} + INTERVAL '1 YEAR' - INTERVAL '1 SECOND'").collect()[0][0]

            v_tax_value = session.sql(f"""
                SELECT SUM(ROUND(((tax_rate/100) * (price_rate * quantity)), 2))
                FROM billed_items bi JOIN customer_bills cb ON (bi.bill_id = cb.bill_id)
                WHERE cb.date_time_created BETWEEN {v_begin} AND {v_end}
                AND bi.tax_code = {p_tax_code}
            """).collect()[0][0]

            return v_tax_value

        except Exception as e:
            session.rollback()
            raise e

CALL jta_billing();
$$;
```
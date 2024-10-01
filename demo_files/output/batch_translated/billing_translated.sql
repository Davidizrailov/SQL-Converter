```sql
CREATE OR REPLACE PROCEDURE add_item_to_bill(p_bill_id STRING, p_barcode STRING)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'add_item_to_bill_handler'
AS
$$
from snowflake.snowpark import Session
from snowflake.snowpark.functions import col

def add_item_to_bill_handler(session: Session, p_bill_id: str, p_barcode: str) -> str:
    try:
        # Check if bill is unpaid
        bill = session.table("customer_bills").filter((col("bill_id") == p_bill_id) & (col("payment_status") == 'unpaid')).collect()
        if not bill:
            raise ValueError("failed to update bill items because bill status not unpaid")
        
        # Retrieve product details
        product = session.sql(f"CALL lookup_barcode('{p_barcode}')").collect()
        if not product:
            raise ValueError("Product not found")
        
        v_product_id, v_name, v_price, v_tax_code, v_tax_rate = product[0]
        
        # Check if item is already in the bill
        billed_item = session.table("billed_items").filter((col("product_id") == v_product_id) & (col("bill_id") == p_bill_id)).collect()
        
        if billed_item:
            # Update quantity
            session.table("billed_items").update(
                (col("quantity") + 1).alias("quantity")
            ).where(col("bill_line_id") == billed_item[0]["bill_line_id"])
        else:
            # Insert new item
            session.table("billed_items").insert({
                "bill_line_id": session.sql("SELECT bill_line_id_seq.NEXTVAL").collect()[0][0],
                "bill_id": p_bill_id,
                "product_id": v_product_id,
                "quantity": 1,
                "price_rate": v_price,
                "tax_code": v_tax_code,
                "tax_rate": v_tax_rate
            })
        
        # Update bill price
        session.table("customer_bills").update(
            (col("payment_tender") + v_price).alias("payment_tender")
        ).where(col("bill_id") == p_bill_id)
        
        session.commit()
        return "SUCCESS"
    except Exception as e:
        session.rollback()
        session.sql(f"CALL log_error({e})")
        return str(e)
$$;

CALL add_item_to_bill('bill_id_example', 'barcode_example');
```
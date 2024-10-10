CREATE OR REPLACE PROCEDURE jta_billing()
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'main'
AS
$$
import snowflake.snowpark as snowpark
from snowflake.snowpark.exceptions import SnowparkSQLException
import logging

def add_item_to_bill(session, bill_id, barcode, quantity):
    try:
        # Check if bill is unpaid
        bill_status = session.sql(f"SELECT status FROM bills WHERE bill_id = {bill_id}").collect()[0]['STATUS']
        if bill_status != 'UNPAID':
            raise ValueError("Bill is not in UNPAID status")

        # Look up product information
        product = session.sql(f"SELECT * FROM products WHERE barcode = '{barcode}'").collect()[0]

        # Update or insert item into bill
        existing_item = session.sql(f"SELECT * FROM bill_items WHERE bill_id = {bill_id} AND product_id = {product['PRODUCT_ID']}").collect()
        if existing_item:
            session.sql(f"UPDATE bill_items SET quantity = quantity + {quantity} WHERE bill_id = {bill_id} AND product_id = {product['PRODUCT_ID']}").collect()
        else:
            session.sql(f"INSERT INTO bill_items (bill_id, product_id, quantity) VALUES ({bill_id}, {product['PRODUCT_ID']}, {quantity})").collect()

        # Update bill total
        session.sql(f"UPDATE bills SET total_amount = total_amount + {product['PRICE'] * quantity} WHERE bill_id = {bill_id}").collect()

        return "Item added successfully"
    except Exception as e:
        logging.error(f"Error in add_item_to_bill: {str(e)}")
        raise

def update_from_bill(session, bill_id):
    try:
        # Update inventory based on items in the bill
        session.sql(f"""
            UPDATE inventory i
            SET quantity = i.quantity - bi.quantity
            FROM bill_items bi
            WHERE i.product_id = bi.product_id
            AND bi.bill_id = {bill_id}
        """).collect()

        # Insert sold products
        session.sql(f"""
            INSERT INTO sold_products (product_id, quantity, sale_date)
            SELECT product_id, quantity, CURRENT_TIMESTAMP()
            FROM bill_items
            WHERE bill_id = {bill_id}
        """).collect()

        return "Bill updated successfully"
    except Exception as e:
        logging.error(f"Error in update_from_bill: {str(e)}")
        raise

def update_sales(session):
    try:
        # Bulk collect sold products
        sold_products = session.sql("SELECT product_id, SUM(quantity) as total_quantity FROM sold_products GROUP BY product_id").collect()

        # Update inventory
        for product in sold_products:
            session.sql(f"UPDATE inventory SET quantity = quantity - {product['TOTAL_QUANTITY']} WHERE product_id = {product['PRODUCT_ID']}").collect()

        # Clear sold_products table
        session.sql("DELETE FROM sold_products").collect()

        return "Sales updated successfully"
    except Exception as e:
        logging.error(f"Error in update_sales: {str(e)}")
        raise

def receive_payment(session, bill_id, payment_type, amount):
    try:
        # Validate payment type and amount
        valid_payment_types = ['CASH', 'CARD', 'MOBILE']
        if payment_type not in valid_payment_types:
            raise ValueError("Invalid payment type")

        bill = session.sql(f"SELECT * FROM bills WHERE bill_id = {bill_id}").collect()[0]
        if amount < bill['TOTAL_AMOUNT']:
            raise ValueError("Insufficient payment amount")

        # Update bill status and payment information
        session.sql(f"""
            UPDATE bills
            SET status = 'PAID', payment_type = '{payment_type}', payment_amount = {amount}
            WHERE bill_id = {bill_id}
        """).collect()

        # Handle cash payments
        change = 0
        if payment_type == 'CASH':
            change = amount - bill['TOTAL_AMOUNT']
            session.sql(f"""
                UPDATE cashier_drawer_assignments
                SET cash_amount = cash_amount + {bill['TOTAL_AMOUNT']}
                WHERE cashier_id = {bill['CASHIER_ID']} AND assignment_date = CURRENT_DATE()
            """).collect()

        # Update inventory and sold products
        update_from_bill(session, bill_id)

        return change
    except Exception as e:
        logging.error(f"Error in receive_payment: {str(e)}")
        raise

def get_tax_payment_due(session, tax_code, year):
    try:
        tax_due = session.sql(f"""
            SELECT SUM(bi.quantity * p.price * t.tax_rate) as tax_due
            FROM bill_items bi
            JOIN products p ON bi.product_id = p.product_id
            JOIN tax_codes t ON p.tax_code = t.tax_code
            JOIN bills b ON bi.bill_id = b.bill_id
            WHERE t.tax_code = '{tax_code}'
            AND YEAR(b.bill_date) = {year}
            AND b.status = 'PAID'
        """).collect()[0]['TAX_DUE']

        return tax_due if tax_due else 0
    except Exception as e:
        logging.error(f"Error in get_tax_payment_due: {str(e)}")
        raise

def main(session: snowpark.Session):
    try:
        # Example usage of the procedures
        add_item_to_bill(session, 1, 'ABC123', 2)
        update_from_bill(session, 1)
        update_sales(session)
        receive_payment(session, 1, 'CASH', 100)
        tax_due = get_tax_payment_due(session, 'VAT', 2023)
        
        return "JTA Billing procedures executed successfully"
    except Exception as e:
        logging.error(f"Error in main: {str(e)}")
        return f"Error: {str(e)}"

$$;

CALL jta_billing();
```sql
CREATE OR REPLACE PROCEDURE lookup_barcode (
    p_barcode STRING,
    p_product_id STRING,
    p_product_name STRING,
    p_price_rate FLOAT,
    p_tax_code STRING,
    p_tax_rate FLOAT
)
RETURNS TABLE (product_id STRING, product_name STRING, price_rate FLOAT, tax_code STRING, tax_rate FLOAT)
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'lookup_barcode_handler'
AS
$$
from snowflake.snowpark import Session
from snowflake.snowpark.functions import col

def lookup_barcode_handler(session: Session, p_barcode: str):
    try:
        if p_barcode.startswith('2'):
            p_price_rate = float(p_barcode[6:11]) / 100
            result = session.sql(f"""
                SELECT pr.product_id, pr.product_name, tr.tax_code, tr.tax_rate
                FROM products pr
                JOIN tax_rates tr ON pr.tax_code = tr.tax_code
                WHERE pr.price_lookup_code = '{p_barcode[:5]}'
            """).collect()
        else:
            result = session.sql(f"""
                SELECT pr.product_id, pr.product_name, pr.price_rate, tr.tax_code, tr.tax_rate
                FROM products pr
                JOIN tax_rates tr ON pr.tax_code = tr.tax_code
                WHERE pr.barcode = '{p_barcode}'
            """).collect()
        
        if not result:
            session.sql(f"""
                INSERT INTO jta_error (error_code, error_message)
                VALUES (-20202, 'price look up for item that does not exist')
            """).collect()
            return [(None, None, None, None, None)]
        
        return [(row['PRODUCT_ID'], row['PRODUCT_NAME'], p_price_rate if p_barcode.startswith('2') else row['PRICE_RATE'], row['TAX_CODE'], row['TAX_RATE']) for row in result]
    
    except Exception as e:
        session.sql(f"""
            INSERT INTO jta_error (error_code, error_message)
            VALUES ({e.args[0]}, '{e.args[1]}')
        """).collect()
        return [(None, None, None, None, None)]
$$;

CREATE OR REPLACE PROCEDURE stock_check (
    p_product_id STRING,
    p_location_id STRING,
    p_value_counted INT,
    p_in_stock INT
)
RETURNS TABLE (in_stock INT)
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'stock_check_handler'
AS
$$
from snowflake.snowpark import Session

def stock_check_handler(session: Session, p_product_id: str, p_location_id: str, p_value_counted: int):
    try:
        result = session.sql(f"""
            SELECT quantity
            FROM inventory_by_location
            WHERE product_id = '{p_product_id}' AND location_id = '{p_location_id}'
        """).collect()
        
        if not result:
            session.sql(f"""
                INSERT INTO jta_error (error_code, error_message)
                VALUES (100, 'No data found for product_id {p_product_id} and location_id {p_location_id}')
            """).collect()
            return [(None,)]
        
        p_in_stock = result[0]['QUANTITY']
        
        if p_in_stock > p_value_counted:
            v_difference = p_in_stock - p_value_counted
            session.sql(f"""
                INSERT INTO missing_items (m_item_id, product_id, date_recorded, quantity)
                VALUES (m_item_id_seq.nextval, '{p_product_id}', current_timestamp(), {v_difference})
            """).collect()
            session.sql(f"""
                UPDATE inventory_by_location
                SET quantity = {p_value_counted}
                WHERE product_id = '{p_product_id}' AND location_id = '{p_location_id}'
            """).collect()
            session.sql(f"""
                CALL jta.update_inventory('{p_product_id}', {-v_difference}, NULL)
            """).collect()
        
        return [(p_in_stock,)]
    
    except Exception as e:
        session.sql(f"""
            INSERT INTO jta_error (error_code, error_message)
            VALUES ({e.args[0]}, '{e.args[1]}')
        """).collect()
        return [(None,)]
$$;

CALL lookup_barcode('123456789012', NULL, NULL, NULL, NULL, NULL);
CALL stock_check('product123', 'location456', 10, NULL);
```
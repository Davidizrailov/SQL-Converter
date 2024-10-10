CREATE OR REPLACE PROCEDURE lookup_barcode(barcode STRING)
RETURNS TABLE (product_id INT, description STRING, price FLOAT, tax_rate FLOAT)
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'lookup_barcode'
AS
$$
import snowflake.snowpark as snowpark
from snowflake.snowpark.exceptions import SnowparkSQLException

def lookup_barcode(session: snowpark.Session, barcode: str):
    try:
        if barcode.startswith('2'):
            # PLU code
            price = float(barcode[1:6]) / 100
            query = f"""
                SELECT p.product_id, p.description, {price} as price, t.tax_rate
                FROM products p
                JOIN tax_rates t ON p.tax_category = t.tax_category
                WHERE p.plu_code = '{barcode[1:6]}'
            """
        else:
            # Regular barcode
            query = f"""
                SELECT p.product_id, p.description, p.price, t.tax_rate
                FROM products p
                JOIN tax_rates t ON p.tax_category = t.tax_category
                WHERE p.barcode = '{barcode}'
            """
        
        result = session.sql(query).collect()
        
        if not result:
            raise ValueError(f"Product not found for barcode: {barcode}")
        
        return result
    
    except ValueError as e:
        session.sql(f"INSERT INTO error_log (error_message) VALUES ('{str(e)}')").collect()
        return []
    except Exception as e:
        session.sql(f"INSERT INTO error_log (error_message) VALUES ('Error in lookup_barcode: {str(e)}')").collect()
        return []

def stock_check(session: snowpark.Session, product_id: int, location_id: int, counted_value: int):
    try:
        query = f"""
            SELECT quantity
            FROM inventory_by_location
            WHERE product_id = {product_id} AND location_id = {location_id}
        """
        result = session.sql(query).collect()
        
        if not result:
            raise ValueError(f"Product/location not found: {product_id}/{location_id}")
        
        current_stock = result[0]['QUANTITY']
        
        if counted_value < current_stock:
            difference = current_stock - counted_value
            session.sql(f"""
                INSERT INTO missing_items (product_id, location_id, quantity, date_reported)
                VALUES ({product_id}, {location_id}, {difference}, CURRENT_TIMESTAMP())
            """).collect()
            
            session.sql(f"""
                UPDATE inventory_by_location
                SET quantity = {counted_value}
                WHERE product_id = {product_id} AND location_id = {location_id}
            """).collect()
            
            session.sql(f"CALL jta.update_inventory({product_id}, {-difference})").collect()
        
        return current_stock
    
    except ValueError as e:
        session.sql(f"INSERT INTO error_log (error_message) VALUES ('{str(e)}')").collect()
        return None
    except Exception as e:
        session.sql(f"INSERT INTO error_log (error_message) VALUES ('Error in stock_check: {str(e)}')").collect()
        return None

def main(session: snowpark.Session, barcode: str):
    return lookup_barcode(session, barcode)
$$;

CALL lookup_barcode('123456789');
```python
CREATE OR REPLACE PROCEDURE jta_product_ops()
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'main'
AS
$$
import snowflake.snowpark as snowpark
from snowflake.snowpark.functions import col, lit, when, avg, sum
from datetime import datetime
import logging

def log_error(session, error_message):
    session.sql(f"INSERT INTO error_log (error_message, timestamp) VALUES ('{error_message}', CURRENT_TIMESTAMP())").collect()

def get_price_changes(session, product_id, start_date, end_date):
    try:
        df = session.sql(f"""
            SELECT 
                product_id,
                effective_date,
                price,
                LAG(price) OVER (PARTITION BY product_id ORDER BY effective_date) as prev_price,
                CASE 
                    WHEN price > LAG(price) OVER (PARTITION BY product_id ORDER BY effective_date) THEN 'UP'
                    WHEN price < LAG(price) OVER (PARTITION BY product_id ORDER BY effective_date) THEN 'DOWN'
                    ELSE '--'
                END as price_change_direction
            FROM price_history
            WHERE product_id = {product_id}
            AND effective_date BETWEEN '{start_date}' AND '{end_date}'
            ORDER BY effective_date
        """).collect()
        return df
    except Exception as e:
        log_error(session, f"Error in get_price_changes: {str(e)}")
        return None

def get_recommended_price_for(session, product_id):
    try:
        result = session.sql(f"""
            SELECT 
                p.current_price as old_price,
                p.tax_rate,
                AVG(pc.unit_cost) as avg_cost
            FROM products p
            JOIN product_costs pc ON p.product_id = pc.product_id
            WHERE p.product_id = {product_id}
            GROUP BY p.current_price, p.tax_rate
        """).collect()

        if not result:
            raise ValueError(f"Product with ID {product_id} not found")

        old_price = result[0]['OLD_PRICE']
        tax_rate = result[0]['TAX_RATE']
        avg_cost = result[0]['AVG_COST']
        
        new_price = avg_cost * (1 + tax_rate) * 1.1  # 10% markup

        return avg_cost, old_price, new_price
    except Exception as e:
        log_error(session, f"Error in get_recommended_price_for: {str(e)}")
        return None, None, None

def get_quantity_sold(session, product_id, location_id, start_date, end_date):
    try:
        # Verify product and location exist
        product_exists = session.sql(f"SELECT 1 FROM products WHERE product_id = {product_id}").collect()
        location_exists = session.sql(f"SELECT 1 FROM locations WHERE location_id = {location_id}").collect()

        if not product_exists or not location_exists:
            raise ValueError("Invalid product_id or location_id")

        result = session.sql(f"""
            SELECT SUM(quantity) as total_quantity
            FROM sales
            WHERE product_id = {product_id}
            AND location_id = {location_id}
            AND sale_date BETWEEN '{start_date}' AND '{end_date}'
        """).collect()

        if not result or result[0]['TOTAL_QUANTITY'] is None:
            return 0
        return result[0]['TOTAL_QUANTITY']
    except Exception as e:
        log_error(session, f"Error in get_quantity_sold: {str(e)}")
        return None

def main(session: snowpark.Session):
    # Example usage
    product_id = 1
    location_id = 1
    start_date = '2023-01-01'
    end_date = '2023-12-31'

    price_changes = get_price_changes(session, product_id, start_date, end_date)
    if price_changes:
        print("Price changes:", price_changes)

    avg_cost, old_price, new_price = get_recommended_price_for(session, product_id)
    if avg_cost is not None:
        print(f"Recommended price: Avg Cost: {avg_cost}, Old Price: {old_price}, New Price: {new_price}")

    quantity_sold = get_quantity_sold(session, product_id, location_id, start_date, end_date)
    if quantity_sold is not None:
        print(f"Quantity sold: {quantity_sold}")

    return "Procedure executed successfully"

$$;

-- Call the procedure
CALL jta_product_ops();
```
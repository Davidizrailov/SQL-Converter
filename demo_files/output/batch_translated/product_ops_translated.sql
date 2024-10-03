```sql
CREATE OR REPLACE PROCEDURE get_price_changes(p_product_id STRING, p_start_date STRING, p_end_date STRING)
RETURNS TABLE (product_id STRING, product_name STRING, date_changed STRING, new_price FLOAT, old_price FLOAT, direction STRING)
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'get_price_changes_handler'
AS
$$
import snowflake.snowpark as snowpark
from snowflake.snowpark.types import StructType, StructField, StringType, FloatType

def get_price_changes_handler(session: snowpark.Session, p_product_id: str, p_start_date: str, p_end_date: str):
    price_changes = session.sql(f"""
        SELECT 
            hist.product_id, 
            pr.product_name,
            hist.start_date,
            hist.price_rate
        FROM price_history hist 
        JOIN products pr ON hist.product_id = pr.product_id
        WHERE hist.product_id = '{p_product_id}'
        AND hist.start_date BETWEEN '{p_start_date}' AND '{p_end_date}'
        ORDER BY start_date
    """).collect()

    result = []
    for pc_record in price_changes:
        old_price = session.sql(f"""
            SELECT price_rate 
            FROM price_history
            WHERE start_date = (
                SELECT MAX(start_date)
                FROM price_history
                WHERE start_date < '{pc_record['START_DATE']}'
            ) AND product_id = '{p_product_id}'
        """).collect()
        
        old_price_value = old_price[0]['PRICE_RATE'] if old_price else 0
        direction = 'UP' if pc_record['PRICE_RATE'] > old_price_value else 'DOWN' if pc_record['PRICE_RATE'] < old_price_value else '--'
        
        result.append((pc_record['PRODUCT_ID'], pc_record['PRODUCT_NAME'], pc_record['START_DATE'], pc_record['PRICE_RATE'], old_price_value, direction))
    
    return session.create_dataframe(result, schema=StructType([
        StructField("product_id", StringType()),
        StructField("product_name", StringType()),
        StructField("date_changed", StringType()),
        StructField("new_price", FloatType()),
        StructField("old_price", FloatType()),
        StructField("direction", StringType())
    ]))
$$;

CREATE OR REPLACE PROCEDURE get_recommended_price_for(p_product_id STRING, p_avg_cost FLOAT, p_old_price FLOAT, p_new_price FLOAT)
RETURNS TABLE (avg_cost FLOAT, old_price FLOAT, new_price FLOAT)
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'get_recommended_price_for_handler'
AS
$$
import snowflake.snowpark as snowpark

def get_recommended_price_for_handler(session: snowpark.Session, p_product_id: str):
    try:
        product_info = session.sql(f"""
            SELECT price_rate, tax_rate 
            FROM products pr 
            JOIN tax_rates tr ON pr.tax_code = tr.tax_code
            WHERE pr.product_id = '{p_product_id}'
        """).collect()[0]
        
        avg_cost = session.sql(f"""
            SELECT average_cost_per_unit 
            FROM cost_sales_tracker
            WHERE transaction_id = (
                SELECT MAX(transaction_id) 
                FROM cost_sales_tracker
                WHERE product_id = '{p_product_id}'
            )
        """).collect()[0]['AVERAGE_COST_PER_UNIT']
        
        new_price = (avg_cost * 1.3) + (avg_cost * 1.3 * (product_info['TAX_RATE'] / 100)) - 0.01
        
        return session.create_dataframe([(avg_cost, product_info['PRICE_RATE'], new_price)], schema=["avg_cost", "old_price", "new_price"])
    except Exception as e:
        session.sql(f"INSERT INTO error_log (error_message) VALUES ('{str(e)}')").collect()
        return session.create_dataframe([(None, None, None)], schema=["avg_cost", "old_price", "new_price"])
$$;

CREATE OR REPLACE PROCEDURE get_quantity_sold(p_product_id STRING, p_location_id STRING, p_date_start STRING, p_date_end STRING)
RETURNS FLOAT
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'get_quantity_sold_handler'
AS
$$
import snowflake.snowpark as snowpark

def get_quantity_sold_handler(session: snowpark.Session, p_product_id: str, p_location_id: str, p_date_start: str, p_date_end: str):
    try:
        session.sql(f"SELECT product_id FROM products WHERE product_id = '{p_product_id}'").collect()
        session.sql(f"SELECT location_id FROM locations WHERE location_id = '{p_location_id}'").collect()
        
        quantity = session.sql(f"""
            SELECT SUM(quantity) 
            FROM billed_items bi 
            JOIN customer_bills cb USING (bill_id)
            JOIN cashier_drawer_assignments cda USING (assignment_id)
            JOIN cashier_stations cs USING (station_id)
            WHERE cb.date_time_created BETWEEN '{p_date_start}' AND '{p_date_end}'
            AND cs.location_id = '{p_location_id}' 
            AND bi.product_id = '{p_product_id}'
        """).collect()[0]['SUM(QUANTITY)']
        
        return quantity if quantity else 0
    except Exception as e:
        session.sql(f"INSERT INTO error_log (error_message) VALUES ('{str(e)}')").collect()
        return None
$$;

CALL get_price_changes('product_id_example', '2023-01-01', '2023-12-31');
CALL get_recommended_price_for('product_id_example');
CALL get_quantity_sold('product_id_example', 'location_id_example', '2023-01-01', '2023-12-31');
```
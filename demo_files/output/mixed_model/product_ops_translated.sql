```sql
CREATE OR REPLACE PROCEDURE get_price_changes (
    p_product_id STRING,
    p_start_date DATE,
    p_end_date DATE
)
RETURNS VARIANT
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'get_price_changes_handler'
AS
$$
def get_price_changes_handler(session, p_product_id, p_start_date, p_end_date):
    try:
        price_changes = session.sql(f"""
            SELECT hist.product_id, pr.product_name, hist.start_date, hist.price_rate
            FROM price_history hist JOIN products pr
            ON (hist.product_id = pr.product_id)
            WHERE hist.product_id = '{p_product_id}'
            AND hist.start_date BETWEEN '{p_start_date}' AND '{p_end_date}'
            ORDER BY start_date
        """).collect()

        v_return_table = []

        for pc_record in price_changes:
            v_price_record = {
                'product_id': pc_record['PRODUCT_ID'],
                'product_name': pc_record['PRODUCT_NAME'],
                'date_changed': pc_record['START_DATE'],
                'new_price': pc_record['PRICE_RATE']
            }

            try:
                old_price = session.sql(f"""
                    SELECT price_rate
                    FROM price_history
                    WHERE start_date = (
                        SELECT MAX(start_date)
                        FROM price_history
                        WHERE start_date < '{v_price_record['date_changed']}'
                        AND product_id = '{p_product_id}'
                    )
                """).collect()
                
                v_price_record['old_price'] = old_price[0]['PRICE_RATE'] if old_price else 0
            except:
                v_price_record['old_price'] = 0

            if v_price_record['new_price'] > v_price_record['old_price']:
                v_price_record['direction'] = 'UP'
            elif v_price_record['new_price'] < v_price_record['old_price']:
                v_price_record['direction'] = 'DOWN'
            else:
                v_price_record['direction'] = '--'

            v_return_table.append(v_price_record)

        return v_return_table

    except Exception as e:
        session.sql(f"""INSERT INTO error_log (error_code, error_message) VALUES ('{str(e)}', '{str(e)}')""")
        return []

$$;

CALL get_price_changes('12345', '2023-01-01', '2023-12-31');


CREATE OR REPLACE PROCEDURE get_recommended_price_for (
    p_product_id STRING
)
RETURNS VARIANT
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'get_recommended_price_for_handler'
AS
$$
def get_recommended_price_for_handler(session, p_product_id):
    try:
        product_info = session.sql(f"""
            SELECT pr.price_rate, tr.tax_rate
            FROM products pr 
            JOIN tax_rates tr ON (pr.tax_code = tr.tax_code)
            WHERE pr.product_id = '{p_product_id}'
        """).collect()
        
        if not product_info:
            raise ValueError("Product does not exist or has not been added to inventory")
        
        old_price, tax_rate = product_info[0]['PRICE_RATE'], product_info[0]['TAX_RATE']
        
        avg_cost = session.sql(f"""
            SELECT average_cost_per_unit
            FROM cost_sales_tracker
            WHERE transaction_id = (
                SELECT MAX(transaction_id) 
                FROM cost_sales_tracker
                WHERE product_id = '{p_product_id}'
            )
        """).collect()
        
        if not avg_cost:
            raise ValueError("No average cost found for the product")
        
        avg_cost = avg_cost[0]['AVERAGE_COST_PER_UNIT']
        new_price = ceil((avg_cost * 1.3) + (avg_cost * 1.3 * (tax_rate / 100))) - 0.01
        
        return {"avg_cost": avg_cost, "old_price": old_price, "new_price": new_price}

    except Exception as e:
        session.sql(f"""INSERT INTO error_log (error_message) VALUES ('{str(e)}')""")
        return {"avg_cost": None, "old_price": None, "new_price": None}

$$;

CALL get_recommended_price_for('12345');


CREATE OR REPLACE PROCEDURE get_quantity_sold (
    p_product_id STRING,
    p_location_id STRING,
    p_date_start DATE,
    p_date_end DATE
)
RETURNS FLOAT
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'get_quantity_sold_handler'
AS
$$
def get_quantity_sold_handler(session, p_product_id, p_location_id, p_date_start, p_date_end):
    try:
        product_exists = session.sql(f"SELECT product_id FROM products WHERE product_id = '{p_product_id}'").collect()
        location_exists = session.sql(f"SELECT location_id FROM locations WHERE location_id = '{p_location_id}'").collect()
        
        if not product_exists or not location_exists:
            raise ValueError("Invalid location or product id when finding quantity sold")
        
        quantity = session.sql(f"""
            SELECT SUM(quantity) as total
            FROM billed_items bi 
            JOIN customer_bills cb ON bi.bill_id = cb.bill_id
            JOIN cashier_drawer_assignments cda ON cb.assignment_id = cda.assignment_id
            JOIN cashier_stations cs ON cda.station_id = cs.station_id
            WHERE cb.date_time_created BETWEEN '{p_date_start}' AND '{p_date_end}'
            AND cs.location_id = '{p_location_id}' 
            AND bi.product_id = '{p_product_id}'
        """).collect()[0]['TOTAL']
        
        return quantity if quantity else 0

    except Exception as e:
        session.sql(f"""INSERT INTO error_log (error_message) VALUES ('{str(e)}')""")
        return None

$$;

CALL get_quantity_sold('12345', '67890', '2023-01-01', '2023-12-31');
```
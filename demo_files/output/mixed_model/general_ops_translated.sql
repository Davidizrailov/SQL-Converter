```python
CREATE OR REPLACE PROCEDURE jta_general_ops_lookup_barcode(p_barcode STRING, p_product_id STRING, p_product_name STRING, p_price_rate FLOAT, p_tax_code STRING, p_tax_rate FLOAT)
RETURNS TABLE(product_id STRING, product_name STRING, price_rate FLOAT, tax_code STRING, tax_rate FLOAT)
LANGUAGE PYTHON
RUNTIME_VERSION = 3.10
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'run'
AS
$$
def run(session, p_barcode, p_product_id, p_product_name, p_price_rate, p_tax_code, p_tax_rate):
    try:
        if p_barcode.startswith('2'):
            p_price_rate = float(p_barcode[6:11]) / 100
            result = session.sql(f"""
                SELECT pr.product_id, pr.product_name, tr.tax_code, tr.tax_rate
                FROM products pr JOIN tax_rates tr ON pr.tax_code = tr.tax_code
                WHERE price_lookup_code = '{p_barcode[:5]}'
            """).collect()
        else:
            result = session.sql(f"""
                SELECT pr.product_id, pr.product_name, pr.price_rate, tr.tax_code, tr.tax_rate
                FROM products pr JOIN tax_rates tr ON pr.tax_code = tr.tax_code
                WHERE barcode = '{p_barcode}'
            """).collect()

        if result:
            return [(result[0]['PRODUCT_ID'], result[0]['PRODUCT_NAME'], p_price_rate, result[0]['TAX_CODE'], result[0]['TAX_RATE'])]
        else:
            raise ValueError("No data found")
        
    except ValueError:
        session.sql("CALL jta_error.log_error(-20202, 'price look up for item that does not exist')").collect()
        return [(None, None, None, None, None)]
    except Exception as e:
        session.sql(f"CALL jta_error.log_error({e.errno}, '{str(e)}')").collect()
        return [(None, None, None, None, None)]
$$;

CREATE OR REPLACE PROCEDURE jta_general_ops_stock_check(p_product_id STRING, p_location_id STRING, p_value_counted INTEGER, p_in_stock INTEGER)
RETURNS TABLE(in_stock INTEGER)
LANGUAGE PYTHON
RUNTIME_VERSION = 3.10
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'run'
AS
$$
def run(session, p_product_id, p_location_id, p_value_counted, p_in_stock):
    try:
        result = session.sql(f"""
            SELECT quantity FROM inventory_by_location
            WHERE product_id = '{p_product_id}' AND location_id = '{p_location_id}'
        """).collect()
        
        if result:
            p_in_stock = result[0]['QUANTITY']
            if p_in_stock > p_value_counted:
                v_difference = p_in_stock - p_value_counted
                session.sql(f"""
                    INSERT INTO missing_items (m_item_id, product_id, date_recorded, quantity)
                    VALUES (m_item_id_seq.nextval, '{p_product_id}', CURRENT_TIMESTAMP, {v_difference})
                """).collect()
                
                session.sql(f"""
                    UPDATE inventory_by_location SET quantity = {p_value_counted}
                    WHERE product_id = '{p_product_id}' AND location_id = '{p_location_id}'
                """).collect()
                
                session.sql(f"CALL jta.update_inventory('{p_product_id}', {-v_difference}, NULL)").collect()

            return [(p_in_stock,)]
        else:
            raise ValueError("No data found")
        
    except ValueError:
        session.sql("CALL jta_error.show_in_console(-1, 'No data found for product/location')").collect()
        return [(None,)]
    except Exception as e:
        session.sql(f"CALL jta_error.log_error({e.errno}, '{str(e)}')").collect()
        return [(None,)]
$$;

-- Calling the procedures
CALL jta_general_ops_lookup_barcode('sample_barcode', NULL, NULL, NULL, NULL, NULL);
CALL jta_general_ops_stock_check('sample_product_id', 'sample_location_id', 50, NULL);
```
```python
CREATE OR REPLACE PROCEDURE trim_string()
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'run'
AS
$$
def run(session):
    v_input_string = '00000test string00000'
    v_trimmed_string = v_input_string.strip('0')
    return v_trimmed_string

$$;

CALL trim_string();
```
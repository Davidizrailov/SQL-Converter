def easytrieve_prompt(code):
    prompt=f"""
Given the following Easytrieve code, write me a snowflake procedure which matches this description. 
        
Return only the the converted code, ensuring it is compatible with Snowflake syntax. 
There should be no text other than the code. If you are using a stored procedure, Use python 3.10 rather than javascript. Make sure to add a handler. 
Call the procedure as well. Include PACKAGES = ('snowflake-snowpark-python') as this avoids a common error.
        
Code: {code} 
    """
    return prompt

def plsql_prompt(code):
    prompt=f"""
Given the following PLSQL code, write me a snowflake procedure which matches this description. 
        
Return only the the converted code, ensuring it is compatible with Snowflake syntax. 
There should be no text other than the code. If you are using a stored procedure, Use python 3.10 rather than javascript. Make sure to add a handler. 
Call the procedure as well. Include PACKAGES = ('snowflake-snowpark-python') as this avoids a common error.
        
Code: {code} 
    """
    return prompt

def sqr_prompt(code):
    prompt=f"""
Given the following PLSQL code, write me a snowflake procedure which matches this description. 
        
Return only the the converted code, ensuring it is compatible with Snowflake syntax. 
There should be no text other than the code. If you are using a stored procedure, Use python 3.10 rather than javascript. Make sure to add a handler. 
Call the procedure as well. Include PACKAGES = ('snowflake-snowpark-python') as this avoids a common error.
        
Code: {code} 
    """
    return prompt
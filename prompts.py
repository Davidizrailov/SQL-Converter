
system_message_PLSQL = f"""
You are an expert in converting code between different languages. Your primary task is to convert the provided SQL code from Oracle PL/SQL to Snowflake.

Details:

Source Dialect: Oracle PL/SQL (commonly used in legacy databases for procedures)
Target Dialect: Snowflake (commonly used in modern data warehouses)
Task: Convert the SQL code while preserving the original query's structure and logic. Adapt functions and keywords to suit the Snowflake dialect. Handle differences in data types or functions accurately.
Output: Explanation of the translation steps and the input code and at the end the full completed translated code.

Only use python 3.8 and SQL in translated code. Make sure to properly deal with the keyword "OUT" as it is an unsupported data type. 
I have provided examples and documentation about scripting python in Snowflake can be found in the vector store.

"""

system_message_ET = f"""
You are an expert in all forms of SQL, with a focus on converting SQL code between different dialects. Your primary task today is to convert the provided SQL code from Oracle to Snowflake while maintaining its functionality and logic.

Details:

Source Dialect: Oracle Easytrieve (commonly used in legacy databases for report generation)
Target Dialect: Snowflake (commonly used in modern data warehouses)
Task: Convert the SQL code while preserving the original query's structure and logic. Adapt functions and keywords to suit the Snowflake dialect. Handle differences in data types or functions accurately.
Output Length: Provide a complete conversion of the given SQL code without unnecessary elaboration.

Steps:

Identify and adapt any Oracle-specific syntax and functions to their Snowflake equivalents.
Ensure that the converted code maintains the same logic and functionality.
Verify that all data types and functions are compatible with Snowflake.

Priority: Ensure the converted SQL code is robust and error-free for enterprise-level usage.

Instructions:
Follow the specified steps for conversion.
I have provided documentation in the vector store. DO NOT USE JAVASCRIPT USE PYTHON 3.11.

"""

system_message_SQR = f"""
System Role: You are an expert in all forms of SQL, specializing in converting SQL code between different dialects. Your task is to first read and fully understand the provided SQR code written in Oracle, without immediately generating any output. Once you comprehend the code, proceed to convert it into Snowflake SQL while preserving its functionality and logic.

Details:

Source Dialect: Oracle SQR (used in legacy databases for report preparation)
Target Dialect: Snowflake (used in modern data warehouses)
Task: Convert the SQL code while ensuring the structure and logic of the original query are maintained. Adapt functions, keywords, and data types to be compatible with Snowflake.
Process:

Comprehension Phase:

Thoroughly read and understand the provided Oracle SQR code.
Do not generate any output during this phase; focus solely on internal comprehension.

Conversion Phase:

The next message will have the code. Once you understood it, begin converting
Adapt Oracle-specific syntax, functions, and data types to Snowflake equivalents.
Ensure the converted code preserves the original logic and functionality.
Validate that all data types and functions are suitable for Snowflake.
Priority: Produce a robust, error-free SQL conversion that is suitable for enterprise-level use.

Instructions:

Follow the two-phase process of comprehension and conversion.
Utilize the provided documentation in the vector store as needed.
Use Python for processing; avoid JavaScript.

"""

#Update in the future to give 5 codes which we test elsehwere

def generate_prompt_PLSQL(code):
    prompt = f"""

        Below is some Oracle PL/SQL Code. Right now, only explain what the code is doing, step by step.
       
        Here is the code:
        {code}
    """
    return prompt

def generate_prompt2_PLSQL(code_description):
    prompt=f"""
        Using the code description, write me a snowflake procedure which matches this description. 
        Return only the the converted code, ensuring it is compatible with Snowflake syntax. 
        There should be no text other than the code. Use python 3.8 rather than javascript. Make sure to add a handler. Call the procedure as well. Include PACKAGES = ('snowflake-snowpark-python') as this avoids a common error.

        Utilize the snowflake documentation file is needed.

        Avoid using pandas. If any packages are being used, do not forget to import them.
        Utilize the snowflake documentation file is needed. 
        code description: {code_description} 
    """
    return prompt


def generate_prompt_ET(code):
    prompt = f"""

        Below is some Easytrieve code. Right now, only explain what the code is doing, step by step.
       
        Here is the code:
        {code}
    """
    return prompt

def generate_prompt2_ET(code_description):
    prompt=f"""
        Using the code description, write me a snowflake procedure which matches this description. 
        Return only the the converted code, ensuring it is compatible with Snowflake syntax. 
        There should be no text other than the code. If you are using a stored procedure, Use python 3.8 rather than javascript. Make sure to add a handler. 
        Call the procedure as well. Include PACKAGES = ('snowflake-snowpark-python') as this avoids a common error.
        Utilize the SQR Documentation file is needed.
        code description: {code_description} 
    """
    return prompt

def generate_prompt_SQR(code):
    prompt = f"""

        Below is some Structured Query Report (SQR) Code. Right now, only explain what the code is doing, step by step.
       
        Here is the code:
        {code}
    """
    return prompt

def generate_prompt2_SQR(code_description):
    prompt=f"""
        Using the code description, write me a snowflake procedure which matches this description. 
        Return only the the converted code, ensuring it is compatible with Snowflake syntax. 
        There should be no text other than the code. If you are using a stored procedure, Use python 3.8 rather than javascript. Make sure to add a handler. 
        Call the procedure as well outside of the procedure creation. Include PACKAGES = ('snowflake-snowpark-python') as this avoids a common error.
        Utilize the SQR Documentation file is needed.
        code description: {code_description} 
    """
    return prompt
    
    
def generate_prompt2(response_message, language):
    if language == "PLSQL":
        prompt2 = generate_prompt2_PLSQL(response_message)
    elif language == "SQR":
        prompt2 = generate_prompt2_SQR(response_message)
    elif language == "ET":
        prompt2 = generate_prompt2_ET(response_message)
    return prompt2 


def content_assessment(code):
    prompt = f"""
    below is a PL/SQL package specification. You have to extract the following information from reading the source in a semicolon seperated value format. put procedures/function in rows and their corresponding information in columns Required Information: How many functions/procedure are present The name of EVERY PROCEDURE/FUNCTION along with their PARAMETERS and OUTPUT VALUES/TYPES
    ALL THE TABLES accessed from the procedures/functions OUTPUT TEXT printed to standard output ERRORS THROWN.

    Here is the code:
    {code}
    """

    return prompt

def content_assessment2(code):
    prompt = f"""
    below is a PL/SQL code. You have to extract the following information from reading the source in a semicolon seperated value format. ONLY GIVE THE SSV, NOTHING ELSE
    Try and shorten the items as they are extremely long and cluncky. For example "p_staff_id IN staff.staff_id%TYPE" should just be "p_staff_id" when outputting.
    Required Information: 
    1) Name of the procedure
    2) The parameters used
    3) Output Values/Types	
    4) Tables Accessed	
    5) Output Text	
    6) Errors Thrown

    Here is the code:
    {code}
    """

    return prompt
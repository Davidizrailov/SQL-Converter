#PLACEHOLDER
with open("Documents\Snowflake_Procedures.txt", "r", encoding="utf-8") as file:
    Snowflake_documentation = file.read()

with open("Documents\ET.txt", "r", encoding="utf-8") as file:
    ET = file.read()

with open("Documents\SQR.txt", "r", encoding="utf-8") as file:
    SQR = file.read()

SQR = SQR.strip()


system_message_PLSQL = f"""
You are an expert in all forms of SQL, with a focus on converting SQL code between different dialects. Your primary task today is to convert the provided SQL code from Oracle to Snowflake while maintaining its functionality and logic.

Details:

Source Dialect: Oracle PL SQL (commonly used in legacy databases for procedures)
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
Use python 3.8. Don't use javascript or SQL use python for the language. Make sure to properly deal with the keyword "OUT" as it is an unsupported data type. I have provided examples and documentation about scripting python in Snowflake can be found here: {Snowflake_documentation}

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

"""

system_message_SQR = f"""
You are an expert in all forms of SQL, with a focus on converting SQL code between different dialects. Your primary task today is to convert the provided SQR code from Oracle to Snowflake while maintaining its functionality and logic.

Details:

Source Dialect: Oracle SQR (commonly used in legacy databases for report preperation)
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

"""

#Update in the future to give 5 codes which we test elsehwere

def generate_prompt_PLSQL(code):
    prompt = f"""

        Below is the code I want you to convert from Oracle PL/SQL to Snowflake SQL. Provide me ONLY the converted code, ensuring it is compatible with Snowflake syntax. 
        There should be no text other than the code. 
       
        Here is the code:
        {code}
    """
    return prompt


def generate_prompt_ET(code):
    prompt = f"""

        Below is the code I want you to convert from Oracle EasyTrieve to Snowflake SQL. Provide me 5 variations of ONLY the converted code, ensuring it is compatible with Snowflake syntax. 
        There should be no text other than the code. Put '+++++' as a delimiter between the 5 versions so that I can seperate them.
       
        Here is the code:
        {code}
    """
    return prompt

def generate_prompt_SQR(code):
    prompt = f"""

        Below is the code I want you to convert from Oracle SQR to Snowflake SQL. Provide me ONLY the converted code, ensuring it is compatible with Snowflake syntax. 
        There should be no text other than the code. Make sure the code actually displays the report.
       
        Here is the code:
        {code}
    """
    return prompt

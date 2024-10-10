

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
prompt1_PLSQL = """

        Below is some Oracle PL/SQL Code. Right now, only explain what the code is doing, step by step.
       
        Here is the code:
        {code}
    """
prompt2_PLSQL = """
        Using the code description, write me a snowflake procedure which matches this description. 
        Return only the the converted code, ensuring it is compatible with Snowflake syntax. 
        There should be no text other than the code. Use python 3.10 rather than javascript. Make sure to add a handler. Call the procedure as well. Include PACKAGES = ('snowflake-snowpark-python') as this avoids a common error.

        Utilize the snowflake documentation file is needed.

        Avoid using pandas. If any packages are being used, do not forget to import them.
        Utilize the snowflake documentation file is needed. 
        code description: {code_description} 
    """
prompt1_ET = """

        Below is some Easytrieve code. Right now, only explain what the code is doing, step by step.
       
        Here is the code:
        {code}
    """

prompt2_ET = """
        Using the code description, write me a snowflake procedure which matches this description. 
        Return only the the converted code, ensuring it is compatible with Snowflake syntax. 
        There should be no text other than the code. If you are using a stored procedure, Use python 3.10 rather than javascript. Make sure to add a handler. 
        Call the procedure as well. Include PACKAGES = ('snowflake-snowpark-python') as this avoids a common error.
        Utilize the SQR Documentation file is needed.
        code description: {code_description} 
    """

prompt1_SQR = """

        Below is some Structured Query Report (SQR) Code. Right now, only explain what the code is doing, step by step.
       
        Here is the code:
        {code}
    """

prompt2_SQR = """
        Using the code description, write me a snowflake procedure which matches this description. 
        Return only the the converted code, ensuring it is compatible with Snowflake syntax. 
        There should be no text other than the code. If you are using a stored procedure, Use python 3.10 rather than javascript. Make sure to add a handler. 
        Call the procedure as well outside of the procedure creation. Include PACKAGES = ('snowflake-snowpark-python') as this avoids a common error.
        Utilize the SQR Documentation file is needed.
        code description: {code_description} 
    """

prompt1_CSharp = """

        Below is some C# Code. Right now, only explain what the code is doing, step by step.
       
        Here is the code:
        {code}
    """
prompt2_CSharp = """
        Using the code description, write me a snowflake procedure which matches this description. 
        Return only the the converted code, ensuring it is compatible with Snowflake syntax. 
        There should be no text other than the code. Use python 3.10 rather than javascript. Make sure to add a handler. Call the procedure as well. Include PACKAGES = ('snowflake-snowpark-python') as this avoids a common error.

        Utilize the snowflake documentation file is needed.

        Avoid using pandas. If any packages are being used, do not forget to import them.
        Utilize the snowflake documentation file is needed. 
        code description: {code_description} 
    """
prompt1_Kornshell = """

        Below is some Kornshell Code. Right now, only explain what the code is doing, step by step.
       
        Here is the code:
        {code}
    """

prompt2_Kornshell = """
        Using the code description, write me a snowflake procedure which matches this description. 
        Return only the the converted code, ensuring it is compatible with Snowflake syntax. 
        There should be no text other than the code. Use python 3.10 rather than javascript. Make sure to add a handler. Call the procedure as well. Include PACKAGES = ('snowflake-snowpark-python') as this avoids a common error.

        Utilize the snowflake documentation file is needed.

        Avoid using pandas. If any packages are being used, do not forget to import them.
        Utilize the snowflake documentation file is needed. 
        code description: {code_description} 
    """
prompt1_java = """

        Below is some legacy java Code. Convert it to Java 17. Make sure to rename the code. Return ONLY the translated code
       
        Here is the code:
        {code}
    """

prompt1_cobol = """

        Below is some legacy cobol Code. Convert it to cobol 6.1. Return ONLY the translated code
       
        Here is the code:
        {code}
    """


# def generate_prompt2_cobol(code_description):
#     prompt=f"""
#         Using the code description, write me a snowflake procedure which matches this description. 
#         Return only the the converted code, ensuring it is compatible with Snowflake syntax. 
#         There should be no text other than the code. Use python 3.10 rather than javascript. Make sure to add a handler. Call the procedure as well. Include PACKAGES = ('snowflake-snowpark-python') as this avoids a common error.

#         Utilize the snowflake documentation file is needed.

#         Avoid using pandas. If any packages are being used, do not forget to import them.
#         Utilize the snowflake documentation file is needed. 
#         code description: {code_description} 
#     """
#     return prompt

def generate_prompt(language, target, code):
    if language == "PLSQL":
        return prompt1_PLSQL.format(code=code)
    elif language == "ET":
        return prompt1_ET.format(code=code)
    elif language == "SQR":
        return prompt1_SQR.format(code=code)
    elif language == "C#":
        return prompt1_CSharp.format(code=code)
    elif language == "Kornshell":
        return prompt1_Kornshell.format(code=code)
    elif language == "Legacy Java":
        return prompt1_java.format(code=code)
    elif language == "Cobol":
        return prompt1_cobol.format(code=code)
    raise "Input language not defined"
    
def generate_prompt2(response_message, language, target):
    if language == "PLSQL":
        prompt2 = prompt2_PLSQL.format(code_description=response_message)
    elif language == "SQR":
        prompt2 = prompt2_SQR.format(code_description=response_message)
    elif language == "ET":
        prompt2 = prompt2_ET.format(code_description=response_message)
    elif language == "C#":
        prompt2 = prompt2_CSharp.format(code_description=response_message)
    elif language == "Kornshell":
        prompt2 = prompt2_Kornshell.format(code_description=response_message)
    # elif language == "Java":
    #     prompt2 = generate_prompt2_java(response_message)
    # elif language == "Cobol":
    #     prompt2 = generate_prompt2_cobol(response_message)
    return prompt2 

def business_rules(code):
    prompt = f"""
    Analyze the following Java code and extract the business rules it contains. A business rule can be a single logical statement or a combination of conditions that drive decisions or outcomes within the code. 
    Please provide the output as a nested list, where each list contains the class the rule applies to, , the method if applicable (if not put none), the original code, and the corresponding interpreted business rule in natural language. The format should be:

    [['class', 'method', 'original code segment', 'interpreted business rule'],['class', 'method', 'original code segment', 'interpreted business rule']]

    IF THERE ARE MULTIPLE CASES DO NOT COMBINE THEM AS ONE, seperate them, with each case having it's own business rule. Aim to break down the logic as much as you can and have as many business rules as possible. For example: 
    
    case 1: if a>b, return option 1
    case 2: if a<b, return option 2

    
    [
    ['classA', 'methodA', 'case 1: code here;', 'Business rule explained'],
    ['classA', 'methodA', 'case 2: code here;', 'Business rule explained'],
    ['classA', 'methodA', 'case 3: code here;', 'Business rule explained']]
    
    If conditions or logic span multiple lines, include that. Dont truncate code.
    
    In terms of how to describe a business rule, here are some examples:
    

    'If the car is a convertible, then its potential theft rating is high.'
    'If the price is greater than $45,000, then its potential theft rating is high.'
    'If multiple conditions (e.g., price range and model type) are true, then apply a specific rating.'
    
    Please aim to capture all the key logical statements or combinations that indicate how decisions are made or conditions are evaluated in the code.

    Please provide no more than the requested list.
    Here is the code: {code}
    """
    return prompt

def business_rules_general(code, lang):

    prompt = f"""
Analyze the following {lang} code and extract the business rules it contains. A business rule can be a single logical statement or a combination of conditions that drive decisions or outcomes within the code.

List out the business rules

In terms of how to describe a business rule, here are some examples:
    
'If the car is a convertible, then its potential theft rating is high.'
'If the price is greater than $45,000, then its potential theft rating is high.'
'If multiple conditions (e.g., price range and model type) are true, then apply a specific rating.'
    
Please aim to capture all the key logical statements or combinations that indicate how decisions are made or conditions are evaluated in the code.

Please provide no more than the requested list.
Here is the code: {code}

"""
    return prompt

def content_assessment(code):
    prompt = f"""
    below is a PL/SQL package specification. You have to extract the following information from reading the source in a semicolon seperated value format. put procedures/function in rows and their corresponding information in columns Required Information: How many functions/procedure are present The name of EVERY PROCEDURE/FUNCTION along with their PARAMETERS and OUTPUT VALUES/TYPES
    ALL THE TABLES accessed from the procedures/functions OUTPUT TEXT printed to standard output ERRORS THROWN.

    Here is the code:
    {code}
    """

    return prompt

def content_assessment_inputs(code):
    prompt = f"""
    below is a PL/SQL code. You have to extract the following information from reading the source in a semicolon seperated value format. ONLY GIVE THE SSV, NOTHING ELSE
    Try and shorten the items as they are extremely long and cluncky. For example "p_staff_id IN staff.staff_id%TYPE" should just be "p_staff_id" when outputting.
    Required Information: 
    1) Name of the procedure, if it doesn't have a name, put none
    2) Input Types (Tables, csv, json, etc)
    3) Input Name (Employee, Payroll, etc)

    Here is the code:
    {code}
    """

    return prompt

def content_assessment_outputs(code,lang):
    prompt = f"""
    below is a {lang} code. You have to extract the following information from reading the source in a semicolon seperated value format. ONLY GIVE THE SSV, NOTHING ELSE
    Try and shorten the items as they are extremely long and cluncky. For example "p_staff_id IN staff.staff_id%TYPE" should just be "p_staff_id" when outputting.
    Required Information: 

    1) Name of the procedure, if it doesn't have a name, put none
    2) Output Types (Tables, csv, json, etc)
    3) Output Name (Employee, Payroll, etc)

    Here is the code:
    {code}
    """

    return prompt

target_dict = {
    "PLSQL" : ['Snowflake'], 
    "SQR" : ['Snowflake'], 
    "Easytrieve" : ['Snowflake'], 
    "Legacy Java" : ['Java 21'], 
    "Kornshell" : ['Snowflake'], 
    "C#" : ['Snowflake'], 
    "Cobol": ['Cobol 6.1']
}


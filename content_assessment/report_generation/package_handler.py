import re

def extract_package_bodies(file_path, output_file):
    # REGEX
    package_body_pattern = re.compile(r'\bCREATE\s+OR\s+REPLACE\s+PACKAGE\s+BODY\s+(\w+)', re.IGNORECASE)
    end_package_pattern = re.compile(r'\bEND\s+(\w+);', re.IGNORECASE)

    capturing = False
    current_package_name = None
    current_block = []

    # STORE BLOCKS
    package_bodies = []

    def store_package_body():
        """Stores the currently captured package body if one exists."""
        if current_package_name and current_block:
            package_bodies.append({
                'name': current_package_name,
                'body': ''.join(current_block)  
            })

    
    try:
        with open(file_path, 'r') as file:
            for line in file:
                # If we are capturing a package body, append the line to current_block
                if capturing:
                    current_block.append(line)

                    # Check if the line marks the end of the package body
                    end_match = re.search(end_package_pattern, line)
                    if end_match and end_match.group(1).lower() == current_package_name.lower():
                        store_package_body()
                        capturing = False
                        current_block = []
                        current_package_name = None
                    continue

                # If we're not currently capturing, search for the start of a PACKAGE BODY
                package_match = re.search(package_body_pattern, line)
                if package_match:
                    capturing = True
                    current_package_name = package_match.group(1)
                    current_block.append(line)

        # WRITE
        with open(output_file, 'w') as out_file:
            for package in package_bodies:
                out_file.write(f"Package Body Name: {package['name']}\n")
                out_file.write(f"Body:\n{package['body']}\n")
                out_file.write("=" * 50 + "\n")

        print(f"Package bodies have been written to {output_file}")

    except Exception as e:
        print(f"An error occurred: {e}")


file_path = 'files\content_assessment\DEMO_DB\PLSQL\JTA_Packages.sql'  
output_file = r'files\content_assessment\test.txt'  
extract_package_bodies(file_path, output_file)



#---------------------------------------------------------------------------------------------------------#

def extract_procedures_functions(file_path):
    # REGEX
    procedure_pattern = re.compile(r'\bPROCEDURE\s+(\w+)')
    function_pattern = re.compile(r'\bFUNCTION\s+(\w+)')
    param_pattern = re.compile(r'\((.*?)\)', re.DOTALL)  
    input_table_pattern = re.compile(r'\bFROM\s+(\w+)|\bJOIN\s+(\w+)', re.IGNORECASE)  
    output_param_pattern = re.compile(r'\bOUT\s+(\w+)')  
    return_pattern = re.compile(r'\bRETURN\s+(\w+)', re.IGNORECASE)  
    modify_table_pattern = re.compile(r'\bINSERT\s+INTO\s+(\w+)|\bDELETE\s+FROM\s+(\w+)', re.IGNORECASE)

    procedures_and_functions = []

    with open(file_path, 'r') as file:
        current_block = []
        current_name = None
        current_type = None

        for line in file:
            current_block.append(line)
            
            proc_match = re.search(procedure_pattern, line)
            func_match = re.search(function_pattern, line)

            if proc_match or func_match:
                if current_block:
                    if current_name:
                        block_info = process_block(current_block, current_name, current_type)
                        if block_info:
                            procedures_and_functions.append(block_info)
                    
                    # NEW BLOCK
                    current_block = [line]
                    if proc_match:
                        current_name = proc_match.group(1)
                        current_type = 'procedure'
                    elif func_match:
                        current_name = func_match.group(1)
                        current_type = 'function'

        if current_name and current_block:
            block_info = process_block(current_block, current_name, current_type)
            if block_info:
                procedures_and_functions.append(block_info)
    
    return procedures_and_functions

def process_block(block_lines, block_name, block_type):
    """
    Processes the block of lines corresponding to a procedure/function and extracts the name, inputs, outputs, and tables.
    """
    block_text = ''.join(block_lines)  # Join lines into one string for easy processing
    
    # Extract parameters
    param_pattern = re.compile(r'\((.*?)\)', re.DOTALL)  # Capture everything inside parentheses (parameters)
    params_match = re.search(param_pattern, block_text)
    parameters = []
    output_params = []
    if params_match:
        raw_params = [p.strip() for p in params_match.group(1).split(',')]
        # Extract only the parameter name (first word before any IN/OUT/TYPE keywords)
        for p in raw_params:
            words = p.split()
            if 'OUT' in words:  # Check for 'OUT' in parameter
                out_param = words[words.index('OUT') - 1]  # The word before 'OUT' is the output parameter
                output_params.append(out_param)
            if words:  # Add the first word (parameter name)
                parameters.append(words[0])

    # Extract input tables from SQL (FROM, JOIN)
    input_table_pattern = re.compile(r'\bFROM\s+(\w+)|\bJOIN\s+(\w+)', re.IGNORECASE)  # Capture input tables in SQL
    input_tables = []
    for match in re.findall(input_table_pattern, block_text):
        input_tables.append(match[0] if match[0] else match[1])  # Handle 'FROM' and 'JOIN' matches

    # Extract output parameters from RETURN, INSERT INTO, DELETE FROM
    return_pattern = re.compile(r'\bRETURN\s+(\w+)', re.IGNORECASE)
    insert_delete_pattern = re.compile(r'\bINSERT\s+INTO\s+(\w+)|\bDELETE\s+FROM\s+(\w+)', re.IGNORECASE)

    # Extract from RETURN
    return_match = re.search(return_pattern, block_text)
    if return_match:
        output_params.append(return_match.group(1))

    # Extract from INSERT INTO and DELETE FROM
    for match in re.findall(insert_delete_pattern, block_text):
        table_name = match[0] if match[0] else match[1]
        output_params.append(table_name)  # Treat as output since these operations modify data

    parameters = list(set(parameters))
    parameters = [param for param in parameters if param.lower() != 'the']

    input_tables = list(set(input_tables))
    input_tables = [table for table in input_tables if table.lower() != 'the']

    output_params = list(set(output_params))
    output_params = [param for param in output_params if param.lower() != 'the']

    # Replace empty lists with "None"
    if not parameters:
        parameters = ["None"]
    if not input_tables:
        input_tables = ["None"]
    if not output_params:
        output_params = ["None"]


    return {
        'name': block_name,
        'type': block_type,
        'parameters': parameters,
        'input_tables': input_tables,
        'output_params': output_params
    }

# Example usage with specified file paths
file_path = r'files\content_assessment\test.txt'  # Input file path

# Extract procedures and functions into a list
procedures_functions_list = extract_procedures_functions(file_path)

# Print out each procedure/function details
for item in procedures_functions_list:
    print(f"Name: {item['name']}")
    print(f"Type: {item['type']}")
    print(f"Parameters: {item['parameters']}")
    print(f"Input Tables: {item['input_tables']}")
    print(f"Output Parameters: {item['output_params']}")
    print("=" * 50)

# print(procedures_functions_list[11])
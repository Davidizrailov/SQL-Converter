import os
import re
import pandas as pd
from content_assessment import *
from package_handler import *

summary_cols = ["Object Type", "Object Path", "Object Name","Object Line Count"]
input_output_cols = ["Object Path", "Object Name", "Item Name", "Type", "Parameters", "Inputs", "Outputs"]


df_summary = pd.DataFrame(columns=summary_cols)
df_inputs_outputs = pd.DataFrame(columns=input_output_cols)


def list_subfolders(folder_path):
    subfolders = [f.path for f in os.scandir(folder_path) if f.is_dir()]
    return subfolders
 
# Example usage
folder_path = "files\content_assessment\DEMO_DB"
subfolders = list_subfolders(folder_path)

# Line Counter
def count_lines(file_path):
    with open(file_path, 'r') as file:
            content = file.readlines()
            lines = len(content)
    return lines

def extract_info_from_plsql(file_path):
    with open(file_path, 'r') as file:
        content = file.read()

    # REGEX
    item_name_pattern = r"(?:DECLARE|BEGIN)"  

    variable_pattern = r"^\s*(\w+)\s*.*(?:%TYPE|NUMBER|VARCHAR2|CURSOR)?\s*;"  
    table_pattern = r"FROM\s+([a-zA-Z_][a-zA-Z0-9_\.]*)"  
    output_pattern = r"DBMS_OUTPUT\.PUT_LINE"
    return_pattern = r'\bRETURN\s+(\w+)'
    modify_table_pattern = r'\bINSERT\s+INTO\s+(\w+)|\bDELETE\s+FROM\s+(\w+)'
    end_pattern = r"\b(BEGIN|CURSOR|EXCEPTION)\b"  

    # DECLARE BLOCK
    declare_block = re.search(r"DECLARE(.*?)(BEGIN|CURSOR|EXCEPTION)", content, re.DOTALL | re.IGNORECASE)
    if declare_block:
        declare_content = declare_block.group(1)
    else:
        declare_content = ""

    # PARAMS
    parameters = re.findall(variable_pattern, declare_content, re.MULTILINE)
    
    # INPUTS
    inputs = re.findall(table_pattern, content)

    # OUTPUT
    outputs = re.findall(output_pattern, content)
    # outputs.append(re.findall(return_pattern, content))
    # outputs.append(re.findall(modify_table_pattern, content))

    
    item_name = file_path.split('/')[-1].split('.')[0] + '*'

    results = [{
        
        "Type": "unspecified",
        "Parameters": ", ".join(parameters) if parameters else "None",
        "Inputs": ", ".join(set(inputs)) if inputs else "None",
        "Outputs": ", ".join(set(outputs)) if outputs else "None"
    }]

    
    df = pd.DataFrame(results)
    return df

def detect_easytrieve_inputs_outputs(path):
    with open(path, 'r') as file:
        easytrieve_content = file.read()

    item_name = path.split('/')[-1].split('.')[0]

    input_files = set()
    output_files = set()

    # REGEX
    input_pattern = re.compile(r'JOB\s+INPUT\s+\(([\w\s,]+)\)', re.IGNORECASE)
    output_pattern_report = re.compile(r'PRINT\s+(\w+)', re.IGNORECASE)
    output_pattern_total = re.compile(r'TOTAL\s+(\w+)', re.IGNORECASE)
    output_pattern_filetype = re.compile(r'FILETYPE\s+IS\s+FILE', re.IGNORECASE)
    

    # JOB
    input_matches = input_pattern.findall(easytrieve_content)
    for match in input_matches:
        input_files.update([file.strip() for file in match.split(',')])

    # PRINT REPORT, TOTAL, FILETYPE IS FILE
    output_report_matches = output_pattern_report.findall(easytrieve_content)
    output_total_matches = output_pattern_total.findall(easytrieve_content)
    output_filetype_matches = output_pattern_filetype.findall(easytrieve_content)

    # OUTPUT FILES
    output_files.update(output_report_matches)
    output_files.update(output_total_matches)
    output_files.update(output_filetype_matches)

    results = [{
        
        "Type": "Easytrieve Document Generator",  
        "Parameters": "None",  
        "Inputs": ", ".join(set(input_files)) if input_files else "None",
        "Outputs": ", ".join(set(output_files)) if output_files else "None"
    }]

    # Convert results to a DataFrame
    df = pd.DataFrame(results)
    return df

def detect_sqr_inputs_outputs(path):
    with open(path, 'r') as file:
        sqr_content = file.read()

    item_name = path.split('/')[-1].split('.')[0]

    input_items = set()
    output_items = set()

    # REGEX PATTERNS
    input_pattern = re.compile(r'let\s+\$(\w+)\s*=', re.IGNORECASE)  # Detect variables being assigned (inputs)
    do_pattern = re.compile(r'do\s+(\w+)', re.IGNORECASE)  # Detect procedure calls (inputs)
    output_pattern_print = re.compile(r'print\s+\$(\w+)', re.IGNORECASE)  # Detect output variables being printed
    output_pattern_show = re.compile(r'#debug\s+show\s+\$(\w+)', re.IGNORECASE)  # Detect debug show outputs

    # FIND LET AND DO
    input_matches = input_pattern.findall(sqr_content)
    do_matches = do_pattern.findall(sqr_content)
    input_items.update(input_matches)
    input_items.update(do_matches)

    # FIND PRINT AND SHOW
    output_matches_print = output_pattern_print.findall(sqr_content)
    output_matches_show = output_pattern_show.findall(sqr_content)
    output_items.update(output_matches_print)
    output_items.update(output_matches_show)

    # ORGANIZE
    results = [{
        "Type": "SQR Job",  
        "Parameters": "None",  
        "Inputs": ", ".join(set(input_items)) if input_items else "None",
        "Outputs": ", ".join(set(output_items)) if output_items else "None"
    }]

    df = pd.DataFrame(results)
    return df

# FIND PACKAGE BODY
def check_plsql_package(path):
    
    with open(path, 'r') as file:
        content = file.read()
    
    package_pattern = re.compile(r'CREATE\s+OR\s+REPLACE\s+PACKAGE\s+BODY\s+?\w+', re.IGNORECASE)
    
    packages_found = re.findall(package_pattern, content)
    
    
    if packages_found:
        return True
    else:
        return False


for i in range(len(subfolders)):
    for filename in os.listdir(subfolders[i]):
        
        # OBJECT TYPE
        ext = filename.split(".")[1]
        if ext == "sql":
            object_type = "PLSQL"
        elif ext == "et":
            object_type = "Easytrieve"
        elif ext == "sqr":
            object_type = "SQR"
        # add more data types here

        # OBJECT PATH
        path = os.path.join(subfolders[i], filename)
        
        # OBJECT NAME
        name = filename
        
        # PACKAGE CHECK
        if check_plsql_package(path) == True:
            output_file = r'files\content_assessment\test.txt'  # Output file path
            extract_package_bodies(file_path, output_file)
            procedures_functions_list = extract_procedures_functions(output_file)
            for item in procedures_functions_list:
                input_output = {
                    "Object Path": path,
                    "Object Name": filename,
                    "Item Name": item['name'],
                    "Type": item['type'],
                    
                    "Parameters": ', '.join(item['parameters']),
                    "Inputs": ', '.join(item['input_tables']),
                    "Outputs": ', '.join(item['output_params'])
                }

                # APPEND TO DF
                df_input_output_row = pd.DataFrame([input_output])  # Create a DataFrame with one row
                df_inputs_outputs = pd.concat([df_inputs_outputs, df_input_output_row], ignore_index=True)
            lines = count_lines(path)

            summary_row = [object_type, path, name, lines]
        
            df_summary.loc[len(df_summary)]=summary_row
            continue    


        # LINE COUNT
        lines = count_lines(path)

        summary_row = [object_type, path, name, lines]
        
        df_summary.loc[len(df_summary)]=summary_row

        # INPUTS
        if ext == "sql":
            input_output = extract_info_from_plsql(path)
        elif ext == "et":
            input_output = detect_easytrieve_inputs_outputs(path)
        elif ext == "sqr":
            input_output = detect_sqr_inputs_outputs(path)
        

        input_output["Object Path"] = path
        input_output["Object Name"] = filename
        input_output["Item Name"] = filename.removesuffix(".%")+ "*"
        
        df_inputs_outputs = pd.concat([df_inputs_outputs, input_output])
        

df_summary.to_csv(r"C:\Users\ZH634TG\OneDrive - EY\Desktop\SQL Dialect Converter\files\content_assessment\Summary.csv", index = False)
df_inputs_outputs.to_csv(r"C:\Users\ZH634TG\OneDrive - EY\Desktop\SQL Dialect Converter\files\content_assessment\Input_Output.csv", index = False)
print("Done!")





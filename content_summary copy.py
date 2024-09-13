import os
import re
import pandas as pd
from content_assessment import *


summary_cols = ["Object Type", "Object Path", "Object Name","Object Line Count"]
input_output_cols = ["Object Path", "Object Name", "Inputs", "Outputs"]


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

def extract_table_info_from_plsql(file_path):
    with open(file_path, 'r') as file:
        content = file.read()

    # REGEX patterns for table inputs and outputs
    # Input tables: FROM clause (input for SELECT statements)
    select_table_pattern = r"FROM\s+([a-zA-Z_][a-zA-Z0-9_\.]*)"

    # Output tables: INSERT, UPDATE, DELETE, MERGE operations
    modify_table_pattern = r"\b(INSERT\s+INTO|UPDATE|DELETE\s+FROM|MERGE\s+INTO)\s+([a-zA-Z_][a-zA-Z0-9_\.]*)"

    
    input_tables = re.findall(select_table_pattern, content)

    # Capture output tables (tables in INSERT, UPDATE, DELETE, MERGE operations)
    modified_tables = re.findall(modify_table_pattern, content)
    
    
    output_tables = [table[1] for table in modified_tables]

    
    item_name = file_path.split('/')[-1].split('.')[0] + '*'

    results = [{
        "Inputs": ", ".join(set(input_tables)) if input_tables else "None",
        "Outputs": ", ".join(set(output_tables)) if output_tables else "None"
    }]

    # Convert to DataFrame
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
        "Inputs": ", ".join(set(input_items)) if input_items else "None",
        "Outputs": ", ".join(set(output_items)) if output_items else "None"
    }]

    df = pd.DataFrame(results)
    return df

# FIND PACKAGE BODY



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
           


        # LINE COUNT
        lines = count_lines(path)

        summary_row = [object_type, path, name, lines]
        
        df_summary.loc[len(df_summary)]=summary_row

        # INPUTS
        if ext == "sql":
            input_output = extract_table_info_from_plsql(path)
        elif ext == "et":
            input_output = detect_easytrieve_inputs_outputs(path)
        elif ext == "sqr":
            input_output = detect_sqr_inputs_outputs(path)
        

        input_output["Object Path"] = path
        input_output["Object Name"] = filename
        
        df_inputs_outputs = pd.concat([df_inputs_outputs, input_output])
        

df_summary.to_csv(r"C:\Users\ZH634TG\OneDrive - EY\Desktop\SQL Dialect Converter\files\content_assessment\Summary.csv", index = False)
df_inputs_outputs.to_csv(r"files\content_assessment\Input_Output.csv", index = False)
print("Done!")





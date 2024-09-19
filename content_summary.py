import os
import re
import pandas as pd
import content_summary_genAI


input_output_cols = ["Object Path", "Object Name", "Inputs", "Outputs", "Procedures/Functions/Trigger Name", "Summary"]


df_inputs_outputs = pd.DataFrame(columns=input_output_cols)


def extract_table_info_from_plsql(file_path):
    with open(file_path, 'r') as file:
        content = file.read()

    # REGEX patterns for table inputs and outputs
    select_table_pattern = r"FROM\s+([a-zA-Z_][a-zA-Z0-9_\.]*)"
    modify_table_pattern = r"\b(INSERT\s+INTO|UPDATE|DELETE\s+FROM|MERGE\s+INTO)\s+([a-zA-Z_][a-zA-Z0-9_\.]*)"

    proc_names_pattern = r"\b(PROCEDURE|FUNCTION|TRIGGER)\s+([a-zA-Z_][a-zA-Z0-9_\.]*)"
    
    input_tables = re.findall(select_table_pattern, content)
    
    modified_tables = re.findall(modify_table_pattern, content)
    output_tables = [table[1] for table in modified_tables]
    output_tables = [table for table in output_tables if table.upper() != 'OF']
    
    proc_names = re.findall(proc_names_pattern, content)
    procs = [table[1] for table in proc_names]
    
    item_name = file_path.split('/')[-1].split('.')[0] + '*'
    
    

    results = [{
        "Inputs": ", ".join(set(input_tables)) if input_tables else "None",
        "Outputs": ", ".join(set(output_tables)) if output_tables else "None",
        "Procedures/Functions/Trigger Name": ", ".join(set(procs)) if procs else "None",
    }]
    
    # Convert to DataFrame
    df = pd.DataFrame(results)
    return df

def detect_easytrieve_inputs_outputs(path):
    with open(path, 'r') as file:
        easytrieve_content = file.read()

    input_files = set()
    output_files = set()

    input_pattern = re.compile(r'JOB\s+INPUT\s+\(([\w\s,]+)\)', re.IGNORECASE)
    output_pattern_report = re.compile(r'PRINT\s+(\w+)', re.IGNORECASE)
    output_pattern_total = re.compile(r'TOTAL\s+(\w+)', re.IGNORECASE)
    output_pattern_filetype = re.compile(r'FILETYPE\s+IS\s+FILE', re.IGNORECASE)
    
    input_matches = input_pattern.findall(easytrieve_content)
    for match in input_matches:
        input_files.update([file.strip() for file in match.split(',')])

    output_report_matches = output_pattern_report.findall(easytrieve_content)
    output_total_matches = output_pattern_total.findall(easytrieve_content)
    output_filetype_matches = output_pattern_filetype.findall(easytrieve_content)

    output_files.update(output_report_matches)
    output_files.update(output_total_matches)
    output_files.update(output_filetype_matches)

    results = [{  
        "Inputs": ", ".join(set(input_files)) if input_files else "None",
        "Outputs": ", ".join(set(output_files)) if output_files else "None",
        "Procedures/Functions/Trigger Name": "None"
    }]

    df = pd.DataFrame(results)
    return df

def detect_sqr_inputs_outputs(path):
    with open(path, 'r') as file:
        sqr_content = file.read()

    input_items = set()
    output_items = set()

    input_pattern = re.compile(r'let\s+\$(\w+)\s*=', re.IGNORECASE)
    do_pattern = re.compile(r'do\s+(\w+)', re.IGNORECASE)
    output_pattern_print = re.compile(r'print\s+\$(\w+)', re.IGNORECASE)
    output_pattern_show = re.compile(r'#debug\s+show\s+\$(\w+)', re.IGNORECASE)

    input_matches = input_pattern.findall(sqr_content)
    do_matches = do_pattern.findall(sqr_content)
    input_items.update(input_matches)
    input_items.update(do_matches)

    output_matches_print = output_pattern_print.findall(sqr_content)
    output_matches_show = output_pattern_show.findall(sqr_content)
    output_items.update(output_matches_print)
    output_items.update(output_matches_show)

    results = [{
        "Inputs": ", ".join(set(input_items)) if input_items else "None",
        "Outputs": ", ".join(set(output_items)) if output_items else "None",
        "Procedures/Functions/Trigger Name": "None"
    }]

    df = pd.DataFrame(results)
    return df

# Function to recursively list all files in subfolders
def list_files_recursively(folder_path):
    all_files = []
    for root, dirs, files in os.walk(folder_path):
        for file in files:
            all_files.append(os.path.join(root, file))
    return all_files

# Example usage
folder_path = "files/content_assessment/DEMO_DB"
all_files = list_files_recursively(folder_path)

file_num = len(all_files)
i=1

# Iterate through all files and process
for file_path in all_files:
    # OBJECT TYPE
    ext = file_path.split(".")[-1]
    if ext == "sql":
        object_type = "PLSQL"
    elif ext == "et":
        object_type = "Easytrieve"
    elif ext == "sqr":
        object_type = "SQR"
    # Add more data types here if needed

    # OBJECT NAME
    filename = os.path.basename(file_path)


    # INPUTS/OUTPUTS
    if ext == "sql":
        input_output = extract_table_info_from_plsql(file_path)
    elif ext == "et":
        input_output = detect_easytrieve_inputs_outputs(file_path)
    elif ext == "sqr":
        input_output = detect_sqr_inputs_outputs(file_path)

    input_output["Object Path"] = file_path
    input_output["Object Name"] = filename
    summary = content_summary_genAI.main(file_path, object_type)
    input_output["Summary"] = summary

    # Append to df_inputs_outputs
    df_inputs_outputs = pd.concat([df_inputs_outputs, input_output])
    
    print(f"{i}/{file_num}")
    i+=1

# Export to CSV files

df_inputs_outputs.to_csv(r"files/content_assessment/Input_Output.csv", index=False)

print("Done!")

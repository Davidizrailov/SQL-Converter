import os
import re
import pandas as pd
from content_assessment import *

summary_cols = ["Object Type", "Object Path", "Object Name","Object Line Count"]
input_output_cols = ["Object Path", "Object Name", "Name", "Input_or_output"]


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

# PLSQL Inputs and Outputs


def detect_PLSQL_inputs_outputs(sql_file_path):
    
    with open(sql_file_path, 'r') as file:
        sql_content = file.read()
    
    
    input_tables = set()
    output_tables = set()

    # Regular expressions to detect inputs (SELECT) and outputs (INSERT, UPDATE, DELETE, DBMS_OUTPUT)
    select_pattern = re.compile(r'SELECT\s+.*?\s+FROM\s+(\w+)', re.IGNORECASE)
    insert_pattern = re.compile(r'INSERT\s+INTO\s+(\w+)', re.IGNORECASE)
    update_pattern = re.compile(r'UPDATE\s+(\w+)', re.IGNORECASE)
    delete_pattern = re.compile(r'DELETE\s+FROM\s+(\w+)', re.IGNORECASE)
    dbms_output_pattern = re.compile(r'DBMS_OUTPUT\.PUT_LINE', re.IGNORECASE)

    
    input_matches = select_pattern.findall(sql_content)
    input_tables.update(input_matches)
    
    
    insert_matches = insert_pattern.findall(sql_content)
    update_matches = update_pattern.findall(sql_content)
    delete_matches = delete_pattern.findall(sql_content)
    
    output_tables.update(insert_matches)
    output_tables.update(update_matches)
    output_tables.update(delete_matches)

    
    dbms_output_matches = dbms_output_pattern.findall(sql_content)
    if dbms_output_matches:
        output_tables.add('DBMS_OUTPUT.PUT_LINE')

    
    data = []
    
    
    for table in input_tables:
        data.append({"Name": table, "Input_or_output": "input"})
    
    
    for table in output_tables:
        data.append({"Name": table, "Input_or_output": "output"})
    
    
    df = pd.DataFrame(data)
    
    
    df.drop_duplicates(subset=["Name", "Input_or_output"], inplace=True)
    

    return df

def detect_easytrieve_inputs_outputs(easytrieve_file_path):
    
    with open(easytrieve_file_path, 'r') as file:
        easytrieve_content = file.read()
    
    
    input_files = set()
    output_files = set()

    # Regular expressions to detect inputs (JOB INPUT) and outputs (PRINT REPORT, TOTAL, FILETYPE IS)
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

    
    data = []
    
    
    for file in input_files:
        data.append({"Name": file, "Input_or_output": "input"})
    
    
    for file in output_files:
        data.append({"Name": file, "Input_or_output": "output"})
    
    
    df = pd.DataFrame(data)
    
    
    df.drop_duplicates(subset=["Name", "Input_or_output"], inplace=True)
    

    return df

def detect_sqr_inputs_outputs(sqr_file_path):
    
    with open(sqr_file_path, 'r') as file:
        sqr_content = file.read()
    
    
    input_items = set()
    output_items = set()

    # Regular expressions to detect inputs (LET, DO, etc.) and outputs (PRINT, SHOW, etc.)
    input_pattern = re.compile(r'let\s+\$(\w+)\s*=', re.IGNORECASE)  # Detect variables being assigned (inputs)
    do_pattern = re.compile(r'do\s+(\w+)', re.IGNORECASE)  # Detect procedure calls (inputs)
    output_pattern_print = re.compile(r'print\s+\$(\w+)', re.IGNORECASE)  # Detect output variables being printed
    output_pattern_show = re.compile(r'#debug\s+show\s+\$(\w+)', re.IGNORECASE)  # Detect debug show outputs

    
    input_matches = input_pattern.findall(sqr_content)
    do_matches = do_pattern.findall(sqr_content)
    input_items.update(input_matches)
    input_items.update(do_matches)

    
    output_matches_print = output_pattern_print.findall(sqr_content)
    output_matches_show = output_pattern_show.findall(sqr_content)
    output_items.update(output_matches_print)
    output_items.update(output_matches_show)

    
    data = []
    
    
    for item in input_items:
        data.append({"Name": item, "Input_or_output": "input"})
    
    
    for item in output_items:
        data.append({"Name": item, "Input_or_output": "output"})
    
    
    df = pd.DataFrame(data)
    
   
    df.drop_duplicates(subset=["Name", "Input_or_output"], inplace=True)
    

    return df

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

        # Inputs
        if ext == "sql":
            input_output = detect_PLSQL_inputs_outputs(path)
        elif ext == "et":
            input_output = detect_easytrieve_inputs_outputs(path)
        elif ext == "sqr":
            input_output = detect_sqr_inputs_outputs(path)
        

        input_output["Object Path"] = path
        input_output["Object Name"] = filename
        
        df_inputs_outputs = pd.concat([df_inputs_outputs, input_output])
        

df_summary.to_csv(r"C:\Users\ZH634TG\OneDrive - EY\Desktop\SQL Dialect Converter\files\content_assessment\Summary.csv", index = False)
df_inputs_outputs.to_csv(r"C:\Users\ZH634TG\OneDrive - EY\Desktop\SQL Dialect Converter\files\content_assessment\Input_Output.csv", index = False)
print("Done!")





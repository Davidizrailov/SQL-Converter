import re
import os
import pandas as pd

def count_lines(file_path):
    with open(file_path, 'r') as file:
        content = file.readlines()
        lines = len(content)
    return lines




PLSQL_patterns = {
    "Loops (FOR, WHILE)": r"\b(FOR|WHILE)\b\s+\w+",
    "Nested Loops": r"\bLOOP\b[\s\S]*?\bLOOP\b",  
    "IF-THEN-ELSE": r"\bIF\b[\s\S]*?\bTHEN\b[\s\S]*?\bEND\s+IF\b",
    "CASE Statements": r"\bCASE\b[\s\S]*?\bEND\s+CASE\b",
    "Recursive Procedures": r"\bPROCEDURE\s+(\w+)[\s\S]+?\bBEGIN\b[\s\S]*?\b\1\b",
    "Cursors": r"\bCURSOR\b\s+\w+\s+(IS|AS)\s+SELECT\b",
    "Exception Handling": r"\bEXCEPTION\b[\s\S]*?\bWHEN\b",
    "Function/Procedure Calls": r"\b(\w+)\s*\([\w\s,]*\)\b", 
    "Triggers": r"\bCREATE\s+(OR\s+REPLACE\s+)?\bTRIGGER\b",
    "Nested Queries": r"\bSELECT\b[\s\S]*?\bFROM\b\s*\(\s*\bSELECT\b"
}

PLSQL_cols = ["Object Path", "Object Name", "Lines of Code", "Sophistication Score", "Loops", "Conditionals", "Recursion", "Cursors", "Exceptions", "External Calls", "Triggers", "Nested Queries"]

df_PLSQL = pd.DataFrame(columns=PLSQL_cols)




ET_patterns = {
    "Multiple Data Sources": r"\bFILE\b.*\b[A-Z]+\b",  # Matches FILE statements with data source names
    "Complex Data Transformations": r"\bMOVE\b.*\bTO\b.*",  # Matches data transformation using MOVE or similar keywords
    "Sort Operations": r"\bSORT\b.*",  # Matches SORT operation
    "Join Operations": r"\bJOIN\b.*",  # Matches JOIN operation
    "Conditional Logic (IF)": r"\bIF\b.*",  # Matches IF conditions
    "Conditional Logic (WHEN)": r"\bWHEN\b.*",  # Matches WHEN conditions
    "Loops or Iterative Logic": r"\bPERFORM\b.*\bUNTIL\b",  # Matches loops or iterative constructs
    "Subroutines and Procedures": r"\bPROC\b.*",  # Matches procedure definitions
    "Error Handling or Input Validation": r"\bERROR\b|\bVALIDATE\b",  # Matches error handling or input validation logic
    "External Function Calls": r"\bCALL\b.*\b[A-Z]+\b",  # Matches external function or system calls
}

ET_cols = ["Object Path", "Object Name", "Lines of Code", "Sophistication Score", "Data Sources", "Data Transformations", 
                   "Sort Operations", "Join Operations", "Conditionals", "Loops", "Subroutines", 
                   "Error Handling", "External Calls"]

df_ET = pd.DataFrame(columns=ET_cols)



SQR_patterns = {
    "Multiple Data Sources": r"\bFROM\b.*\b[A-Z_]+\b",  # Matches FROM clause with table or data source names
    "Complex Data Transformations": r"\bUPDATE\b.*\bSET\b.*",  # Matches UPDATE transformations
    "Sort Operations": r"\bORDER\s+BY\b.*",  # Matches ORDER BY operation
    "Join Operations": r"\bJOIN\b.*",  # Matches JOIN operation
    "Conditional Logic (IF)": r"\bIF\b.*",  # Matches IF conditions (if used in stored procedures or dynamic SQL)
    "Conditional Logic (WHEN)": r"\bCASE\b.*\bWHEN\b.*",  # Matches WHEN conditions in CASE statements
    "Loops or Iterative Logic": r"\bWHILE\b.*\bEND\b",  # Matches loops or iterative constructs (in procedures)
    "Subroutines and Procedures": r"\bPROCEDURE\b|\bFUNCTION\b|\bBEGIN\b",  # Matches procedure definitions or function usage
    "Error Handling or Input Validation": r"\bTRY\b|\bCATCH\b|\bVALIDATE\b",  # Matches error handling or input validation logic
    "External Function Calls": r"\bEXEC\b|\bCALL\b.*\b[A-Z]+\b",  # Matches external function or stored procedure calls
    "Nested Queries": r"\bSELECT\b.*\bIN\b\s*\(.*\bSELECT\b",  # Matches nested SELECT queries
    "Window Functions": r"\bOVER\b\s*\(.*\)",  # Matches window function operations
    "Recursive Queries (CTE)": r"\bWITH\s+RECURSIVE\b",  # Matches recursive CTE queries
    "Set Operations": r"\bUNION\b|\bINTERSECT\b|\bEXCEPT\b",  # Matches UNION, INTERSECT, EXCEPT
}

# Update the complexity columns
SQR_cols = ["Object Path", "Object Name", "Lines of Code", "Sophistication Score", "Data Sources", "Data Transformations", 
                   "Sort Operations", "Join Operations", "Conditionals", "Loops", "Subroutines", 
                   "Error Handling", "External Calls", "Nested Queries", "Window Functions", 
                   "Recursive Queries", "Set Operations"]

df_SQR = pd.DataFrame(columns=SQR_cols)





def count_complexity_instances(code, patterns):
    counts = {}
    for description, pattern in patterns.items():
        matches = re.findall(pattern, code, re.IGNORECASE)
        counts[description] = len(matches)
    return counts

def list_files_recursively(folder_path):
    all_files = []
    for root, dirs, files in os.walk(folder_path):
        for file in files:
            all_files.append(os.path.join(root, file))
    return all_files

folder_path = "files/content_assessment/DEMO_DB"
all_files = list_files_recursively(folder_path)



for file_path in all_files:
    # OBJECT TYPE
    ext = file_path.split(".")[-1]
    if ext == "sql":
        filename = os.path.basename(file_path)
        
        with open(file_path, 'r') as file:
            content = file.read()
        
        complexity_counts = count_complexity_instances(content, PLSQL_patterns)
        

        complexity = {
            "Object Path": file_path,
            "Object Name": filename,
            "Lines of Code": count_lines(file_path),
            "Loops": complexity_counts.get("Loops (FOR, WHILE)", 0) + complexity_counts.get("Nested Loops", 0),
            "Conditionals": complexity_counts.get("IF-THEN-ELSE", 0) + complexity_counts.get("CASE Statements", 0),
            "Recursion": complexity_counts.get("Recursive Procedures", 0),
            "Cursors": complexity_counts.get("Cursors", 0),
            "Exceptions": complexity_counts.get("Exception Handling", 0),
            "External Calls": complexity_counts.get("Function/Procedure Calls", 0),
            "Triggers": complexity_counts.get("Triggers", 0),
            "Nested Queries": complexity_counts.get("Nested Queries", 0),
        }
        
        complexity["Sophistication Score"] = sum([
            complexity["Loops"],
            complexity["Conditionals"],
            complexity["Recursion"],
            complexity["Cursors"],
            complexity["Exceptions"],
            complexity["External Calls"],
            complexity["Triggers"],
            complexity["Nested Queries"]
        ])
        

        df_PLSQL = pd.concat([df_PLSQL, pd.DataFrame([complexity])], ignore_index=True)

# df_PLSQL.to_csv(r"files/content_assessment/ComplexityPLSQL.csv", index=False)





for file_path in all_files:
    # OBJECT TYPE
    ext = file_path.split(".")[-1]
    if ext == "et":
        filename = os.path.basename(file_path)
        
        with open(file_path, 'r') as file:
            content = file.read()
        
        complexity_counts = count_complexity_instances(content, ET_patterns)
        
        complexity = {
            "Object Path": file_path,
            "Object Name": filename,
            "Lines of Code": count_lines(file_path),
            "Data Sources": complexity_counts.get("Multiple Data Sources", 0),
            "Data Transformations": complexity_counts.get("Complex Data Transformations", 0),
            "Sort Operations": complexity_counts.get("Sort Operations", 0),
            "Join Operations": complexity_counts.get("Join Operations", 0),
            "Conditionals": complexity_counts.get("Conditional Logic (IF)", 0) + complexity_counts.get("Conditional Logic (WHEN)", 0),
            "Loops": complexity_counts.get("Loops or Iterative Logic", 0),
            "Subroutines": complexity_counts.get("Subroutines and Procedures", 0),
            "Error Handling": complexity_counts.get("Error Handling or Input Validation", 0),
            "External Calls": complexity_counts.get("External Function Calls", 0),
        }
        
        complexity["Sophistication Score"] = sum([
            complexity["Data Sources"],
            complexity["Data Transformations"],
            complexity["Sort Operations"],
            complexity["Join Operations"],
            complexity["Conditionals"],
            complexity["Loops"],
            complexity["Subroutines"],
            complexity["Error Handling"],
            complexity["External Calls"]
        ])
        
        df_ET = pd.concat([df_ET, pd.DataFrame([complexity])], ignore_index=True)


# df_ET.to_csv(r"files/content_assessment/ComplexityET.csv", index=False)





for file_path in all_files:
    # OBJECT TYPE
    ext = file_path.split(".")[-1]
    if ext == "sqr": 
        filename = os.path.basename(file_path)
        
        with open(file_path, 'r') as file:
            content = file.read()
        
        complexity_counts = count_complexity_instances(content, SQR_patterns)
        
        complexity = {
            "Object Path": file_path,
            "Object Name": filename,
            "Lines of Code": count_lines(file_path),
            "Data Sources": complexity_counts.get("Multiple Data Sources", 0),
            "Data Transformations": complexity_counts.get("Complex Data Transformations", 0),
            "Sort Operations": complexity_counts.get("Sort Operations", 0),
            "Join Operations": complexity_counts.get("Join Operations", 0),
            "Conditionals": complexity_counts.get("Conditional Logic (IF)", 0) + complexity_counts.get("Conditional Logic (WHEN)", 0),
            "Loops": complexity_counts.get("Loops or Iterative Logic", 0),
            "Subroutines": complexity_counts.get("Subroutines and Procedures", 0),
            "Error Handling": complexity_counts.get("Error Handling or Input Validation", 0),
            "External Calls": complexity_counts.get("External Function Calls", 0),
            "Nested Queries": complexity_counts.get("Nested Queries", 0),
            "Window Functions": complexity_counts.get("Window Functions", 0),
            "Recursive Queries": complexity_counts.get("Recursive Queries (CTE)", 0),
            "Set Operations": complexity_counts.get("Set Operations", 0),
        }
        
        complexity["Sophistication Score"] = sum([
            complexity["Data Sources"],
            complexity["Data Transformations"],
            complexity["Sort Operations"],
            complexity["Join Operations"],
            complexity["Conditionals"],
            complexity["Loops"],
            complexity["Subroutines"],
            complexity["Error Handling"],
            complexity["External Calls"],
            complexity["Nested Queries"],
            complexity["Window Functions"],
            complexity["Recursive Queries"],
            complexity["Set Operations"]
        ])
        
        df_SQR = pd.concat([df_SQR, pd.DataFrame([complexity])], ignore_index=True)


# df_SQR.to_csv(r"files/content_assessment/ComplexitySQR.csv", index=False)


with pd.ExcelWriter('files/content_assessment/Complexity.xlsx', engine='openpyxl') as writer:

    df_PLSQL.to_excel(writer, sheet_name='PLSQL', index=False)
    df_SQR.to_excel(writer, sheet_name='SQR', index=False)
    df_ET.to_excel(writer, sheet_name='ET', index=False)

print("Done!")
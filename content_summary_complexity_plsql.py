import re
import os
import pandas as pd

complexity_patterns = {
    "Loops (FOR, WHILE)": r"\b(FOR|WHILE)\b\s+\w+",
    "Nested Loops": r"\bLOOP\b[\s\S]*?\bLOOP\b",  
    "IF-THEN-ELSE": r"\bIF\b[\s\S]*?\bTHEN\b[\s\S]*?\bEND\s+IF\b",
    "CASE Statements": r"\bCASE\b[\s\S]*?\bEND\s+CASE\b",
    "Recursive Procedures": r"\bPROCEDURE\s+(\w+)[\s\S]+?\bBEGIN\b[\s\S]*?\b\1\b",
    "Cursors": r"\bCURSOR\b\s+\w+\s+(IS|AS)\s+SELECT\b",
    "Exception Handling": r"\bEXCEPTION\b[\s\S]*?\bWHEN\b",
    "Function/Procedure Calls": r"\b(\w+)\s*\([\w\s,]*\)\b", 
    "Triggers": r"\bCREATE\s+(OR\s+REPLACE\s+)?\bTRIGGER\b",
    "Nested Queries": r"\bSELECT\b[\s\S]*?\bFROM\b\s*\(\s*\bSELECT\b",
}

complexity_cols = ["Object Path", "Object Name", "Complexity Score", "Loops", "Conditionals", "Recursion", "Cursors", "Exceptions", "External Calls", "Triggers", "Nested Queries"]

df_complexity = pd.DataFrame(columns=complexity_cols)

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
        
        complexity_counts = count_complexity_instances(content, complexity_patterns)
        

        complexity = {
            "Object Path": file_path,
            "Object Name": filename,
            "Loops": complexity_counts.get("Loops (FOR, WHILE)", 0) + complexity_counts.get("Nested Loops", 0),
            "Conditionals": complexity_counts.get("IF-THEN-ELSE", 0) + complexity_counts.get("CASE Statements", 0),
            "Recursion": complexity_counts.get("Recursive Procedures", 0),
            "Cursors": complexity_counts.get("Cursors", 0),
            "Exceptions": complexity_counts.get("Exception Handling", 0),
            "External Calls": complexity_counts.get("Function/Procedure Calls", 0),
            "Triggers": complexity_counts.get("Triggers", 0),
            "Nested Queries": complexity_counts.get("Nested Queries", 0),
        }
        
        complexity["Complexity Score"] = sum([
            complexity["Loops"],
            complexity["Conditionals"],
            complexity["Recursion"],
            complexity["Cursors"],
            complexity["Exceptions"],
            complexity["External Calls"],
            complexity["Triggers"],
            complexity["Nested Queries"]
        ])
        

        df_complexity = pd.concat([df_complexity, pd.DataFrame([complexity])], ignore_index=True)

# Save the DataFrame to a CSV file
df_complexity.to_csv(r"files/content_assessment/ComplexityPLSQL.csv", index=False)
print("Done!")

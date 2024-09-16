import networkx as nx
from ontology import Ontology
import pandas as pd
import os
import re

def get_objects():
    # def get_name(x):
    #     if "*" in x:
    #         return 'Unnamed Function'
    #     else:
    #         return x
    def split_cell(x):
        if type(x)==str:
            return [string.strip() for string in x.split(",")]
        else:
            return []

    df = pd.read_csv("files/content_assessment/Input_Output.csv")
    df2 = pd.read_csv("files/content_assessment/Summary.csv")
    functions = []
    for i in range(len(df)):
        functions.append({
            "name": df.iloc[i]["Object Name"],
            "path": df.iloc[i]['Object Path'],
            "procedures": split_cell(df.iloc[i]['Procedures/Functions/Trigger Name']),
            "inputs": split_cell(df.iloc[i]["Inputs"]),
            "outputs": split_cell(df.iloc[i]["Outputs"]),
            "summary": df.iloc[i]['Summary'],
            "line_count": df2.iloc[i]['Object Line Count']
        })
    return functions

def wrap_summary(summary, max_words_per_line=10):
    words = summary.split()
    wrapped_summary = ""
    current_line = ""

    for word in words:
        if len(current_line.split()) >= max_words_per_line:
            wrapped_summary += current_line + "<br>"
            current_line = word
        else:
            current_line += word + " "

    wrapped_summary += current_line

    return wrapped_summary

objects = get_objects()
# for fun in functions: print(fun)

def get_objects():
    # def get_name(x):
    #     if "*" in x:
    #         return 'Unnamed Function'
    #     else:
    #         return x
    def split_cell(x):
        if type(x)==str:
            return [string.strip() for string in x.split(",")]
        else:
            return []

    df = pd.read_csv("files/content_assessment/Input_Output.csv")
    functions = []
    for i in range(len(df)):
        functions.append({
            "name": df.iloc[i]['Object Name'],
            "path": df.iloc[i]['Object Path'],
            "procedures": split_cell(df.iloc[i]['Procedures/Functions/Trigger Name'])
        })
    return functions

def confirm_keywords_in_file(keywords, file_path):
    with open(file_path, 'r') as file:
        content = file.read()
    
    # # Convert keywords to lowercase for case-insensitive matching
    # keywords = [keyword.lower() for keyword in keywords]
    
    # # Convert content to lowercase for case-insensitive matching
    # content = content.lower()
    
    # Use regex to find any of the keywords in the content
    for keyword in keywords:
        if re.search(r'\b' + re.escape(keyword) + r'\b', content):
            return True
    
    # If no keywords are found, return False
    return False

def get_files():
    df = pd.read_csv("files/content_assessment/Input_Output.csv")
    return list(map(lambda x: os.path.normpath(x), df['Object Path']))

data = get_objects()

dependencies = [
    {'name': inp['name'], 'dependencies': [
        ks['name'] for ks in data if ks['name'] != inp['name'] and confirm_keywords_in_file(ks['procedures'], inp['path'])
    ]}
    for inp in data
]
print(dependencies)

# Define function names, inputs, and outputs (based on the table you provided)
# functions = [
#     {"name": "get_customer_info", "inputs": ["customer_id"], "outputs": ["customer_name", "customer_address", "customer_email"]},
#     {"name": "get_inventory_status", "inputs": ["product_id"], "outputs": ["product_name", "stock_quantity", "product_price"]},
#     {"name": "create_order", "inputs": ["customer_id", "product_id", "quantity", "order_date"], "outputs": ["order_id", "total_order_value"]},
#     {"name": "generate_invoice", "inputs": ["order_id", "customer_info", "total_order_value"], "outputs": ["invoice_id", "invoice_date", "payment_due_date"]},
#     {"name": "process_payment", "inputs": ["invoice_id", "payment_method", "payment_amount"], "outputs": ["payment_confirmation", "balance_due"]},
#     {"name": "update_inventory", "inputs": ["product_id", "quantity_sold"], "outputs": ["updated_stock_quantity"]},
#     {"name": "send_order_confirmation", "inputs": ["customer_email", "order_id", "invoice_id", "total_order_value"], "outputs": ["confirmation_status"]}
# ]

# Create a directed graph
G = nx.MultiDiGraph()
# print(objects)
# Add nodes and edges
for func in objects:
    # G.add_node(func["name"], type='function')
    line_count = func['line_count']
    title = f"""
<div style="border: 1px solid #ddd; padding: 10px; border-radius: 5px;">
  <h4 style="background: linear-gradient(to right, #ff0000, #008000, #0000ff); -webkit-background-clip: text; -webkit-text-fill-color: transparent;">
  Smart Context
</h4>
  <p><b>Number of Lines:</b> {line_count}</p>
  <p><b>Summary:</b> {wrap_summary(func['summary'])}</p>
</div>
"""
    G.add_node(func["name"], title=title, color="#ff9999", shape="ellipse")

    # Add input nodes and connect them to the function
    for input_val in func["inputs"]:
        G.add_node(input_val, type='input', shape='square')
        G.add_edge(input_val, func["name"], color="green")
    
    # Add output nodes and connect the function to them
    for output_val in func["outputs"]:
        G.add_node(output_val, type='output', shape='square')
        G.add_edge(func["name"], output_val, color="green")

    dependencies = [
        ks['name'] for ks in objects if ks['name'] != func['name'] and confirm_keywords_in_file(ks['procedures'], func['path'])
    ]
    print(dependencies)
    for output_package in dependencies:
        G.add_edge(func['name'], output_package, color='red')
        G.add_edge(func['name'], output_package, weight=10, color='transparent')

# for v in G.nodes():
#     for u in G.nodes():
#         G.add_edge(v, u, style='invis')
o = Ontology(G)
o.create_visualization("function_dependencies_graph.html", show=True)

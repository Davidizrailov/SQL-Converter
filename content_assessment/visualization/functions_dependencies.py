# import networkx as nx
# from ontology import Ontology
import pandas as pd
from content_assessment.visualization.generate_yed_graph import *
import os

def get_functions():
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

    df = pd.read_csv("content_assessment/Input_Output.csv")
    functions = []
    for i in range(len(df)):
        functions.append({
            "name": df.iloc[i]["Item Name"],
            "inputs": split_cell(df.iloc[i]["Parameters"]),
            "outputs": split_cell(df.iloc[i]["Outputs"])
        })
    return functions
functions = get_functions()


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
G = nx.DiGraph()

# Add nodes and edges
for func in functions:
    # G.add_node(func["name"], type='function')
    G.add_node(func["name"], color="#DDDDDD", shape="ellipse", label=func["name"], tooltip="Function tooltip")

    # Add input nodes and connect them to the function
    for input_val in func["inputs"]:
        G.add_node(input_val, label=input_val, color="#97c2fc", tooltip="Input tooltip", shape="rectangle")
        G.add_edge(input_val, func["name"], color="#009900")
    
    # Add output nodes and connect the function to them
    for output_val in func["outputs"]:
        G.add_node(output_val, label=output_val, color="#97c2fc", tooltip="Output tooltip", shape="rectangle")
        G.add_edge(func["name"], output_val, color="#FF0000")

folder = "C:/Users/NW538RY/OneDrive - EY/Desktop/Work/git/SQL-Converter/content_assessment/"

path = folder+"functions_dependencies.graphml"
to_graphml(G, path = path)
os.startfile(path)
# nx.write_graphml_xml(G, folder+"output.xml")
# o = Ontology(G)
# o.create_visualization(folder+"function_dependencies_graph.html", show=True)

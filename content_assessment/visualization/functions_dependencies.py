
import pandas as pd
from generate_yed_graph import *
import os

def get_functions():

    def split_cell(x):
        if type(x)==str:
            return [string.strip() for string in x.split(",")]
        else:
            return []

    df = pd.read_csv(r"C:\Users\NW538RY\OneDrive - EY\Desktop\Work\git\SQL-Converter\demo_files\output\Input_Output.csv")
    functions = []
    for i in range(len(df)):
        functions.append({
            "name": df.iloc[i]["Object Name"],
            "inputs": split_cell(df.iloc[i]["Inputs"]),
            "outputs": split_cell(df.iloc[i]["Outputs"])
        })
    return functions
functions = get_functions()



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

folder = r"C:\Users\NW538RY\OneDrive - EY\Desktop\Work\git\SQL-Converter\demo_files\output\visuals"

path = folder+r"\functions_dependencies.graphml"
to_graphml(G, path = path)
os.startfile(path)


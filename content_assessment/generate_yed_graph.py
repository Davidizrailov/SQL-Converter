import networkx as nx

# Create a new graph
# G = nx.Graph()

# Add nodes and edges
# G.add_node(1, label="This is a long node name", color="#BBBBBB", shape="ellipse")
# G.add_node(2, label="This is another long node name 2", color="#BBBBBB", shape="rectangle")
# G.add_edge(1, 2, weight=4.7, color="#FF0000")

def to_graphml(G,path):

    # Start writing custom GraphML with yEd extensions
    with open(path, "w", encoding="utf-8") as f:
        # Write the XML header and namespaces
        f.write('''<?xml version="1.0" encoding="UTF-8"?>
    <graphml xmlns="http://graphml.graphdrawing.org/xmlns"
            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
            xmlns:y="http://www.yworks.com/xml/graphml"
            xsi:schemaLocation="http://graphml.graphdrawing.org/xmlns http://www.yworks.com/xml/schema/graphml/1.1/ygraphml.xsd">
        <key for="node" id="d6" yfiles.type="nodegraphics"/>
        <key for="edge" id="d10" yfiles.type="edgegraphics"/>
        <graph id="G" edgedefault="undirected">
        ''')

        # Write nodes with yEd-specific labels
        for node in G.nodes(data=True):
            label = node[1]['label']
            color = node[1]['color']
            shape = node[1]['shape']
            tooltip = node[1]['tooltip']
            f.write(f'''
            <node id="n{node[0]}">
                <data key="d6">
                    <y:ShapeNode>
                        <y:Geometry height="30.0" width="{5*len(label)+35}" x="-15.0" y="-15.0"/>
                        <y:Fill color="{color}" transparent="false"/>
                        <y:BorderStyle hasColor="false" raised="false" type="line" width="1.0"/>
                        <y:NodeLabel modelName="internal" visible="false" >{tooltip}</y:NodeLabel>
                        <y:NodeLabel modelName="custom"   visible="true" > {label}<y:LabelModel><y:SmartNodeLabelModel distance="4.0"/></y:LabelModel><y:ModelParameter><y:SmartNodeLabelModelParameter labelRatioX="0.0" labelRatioY="0.0" nodeRatioX="0.0" nodeRatioY="0.0" offsetX="0.0" offsetY="0.0" upX="0.0" upY="-1.0"/></y:ModelParameter></y:NodeLabel>
                        <y:Shape type="{shape}"/>
                    </y:ShapeNode>
                </data>
            </node>
            ''')

        # Write edges
        for edge in G.edges(data=True):
            color = edge[2]["color"]
            f.write(f'''
            <edge source="n{edge[0]}" target="n{edge[1]}">
                <data key="d10">
                    <y:PolyLineEdge>
                        <y:LineStyle type="line" width="1.0" color="{color}"/>
                        <y:Arrows source="none" target="standard"/>
                        <y:BendStyle smoothed="false"/>
                    </y:PolyLineEdge>
                </data>
            </edge>
            ''')

        # Close the GraphML tags
        f.write('''
        </graph>
    </graphml>
        ''')
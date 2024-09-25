# Code for the streamlit app

import streamlit as st
import plotly.express as px
import os
import pandas as pd
import time

#############################################################################################            
# Layout
#############################################################################################            

st.image(os.path.join("files", "ey.jpg"),width=300)  
# st.title("EY Content Assessment Dashboard")

st.title("Interactive Charts Dashboard")
st.write('''''')

#############################################################################################            
# Session_state Variables
#############################################################################################            

# # Set the page configuration
# st.set_page_config(
#     page_title="Interactive Charts Dashboard",
#     layout="wide",
#     initial_sidebar_state="expanded",
# )

folder = os.path.dirname(__file__).replace("\\","/")+"/"
print(folder)
# Function to load CSV data with error handling
def load_data(filepath):
    if not os.path.exists(filepath):
        st.error(f"File {filepath} does not exist.")
        return None
    try:
        data = pd.read_csv(filepath)
        return data
    except Exception as e:
        st.error(f"Error loading {filepath}: {e}")
        return None

# Paths to the CSV files
horizontal_bar1_csv = folder+"horizontal_bar1.csv"
horizontal_bar2_csv = folder+"horizontal_bar2.csv"
pie_chart_csv = folder+"pie_chart.csv"
scatter_chart_csv = folder+"scatter_chart.csv"

# Load data 
hb1_data = load_data(horizontal_bar1_csv)
hb2_data = load_data(horizontal_bar2_csv)
pie_data = load_data(pie_chart_csv)
scatter_data = load_data(scatter_chart_csv)

folder_path = st.text_input(label="Enter the path to the folder containing the coding files",
                            value="/full/path/to/folder/")

button_clicked = st.button(label="Start Analysis")
generate_charts = False
progress_text = "Operation in progress. Please wait."
if button_clicked:
    my_bar = st.progress(0, text=progress_text)

    for percent_complete in range(100):
        time.sleep(0.01)
        my_bar.progress(percent_complete + 1, text=progress_text)
        if percent_complete+1==100:
            generate_charts = True
            time.sleep(1)
            my_bar.empty()

if generate_charts:
    bar1_col, pie_col = st.columns(2)

    with bar1_col:
        if hb1_data is not None:
            fig1 = px.bar(
                hb1_data,
                x='Value',
                y='Label',
                orientation='h',
                title="Data sources count by type",
                labels={'Value': 'Value', 'Label': 'Label'},
                color='Label'  # Use different color for each bar
            )
            fig1.update_layout(
                yaxis={'categoryorder':'total ascending'},
                height = 400,
                xaxis_title=None,  # Remove x-axis label
                yaxis_title=None,   # Remove y-axis label
                showlegend=False
            )
            fig1.update_traces(texttemplate='%{x}', textposition='auto')  # Display values on bars
            st.plotly_chart(fig1, use_container_width=True)
        else:
            st.write("No data available")

    with pie_col:
        if pie_data is not None:
            # Assuming the CSV has 'Category' and 'Amount' columns
            fig3 = px.pie(
                pie_data,
                names='Category',
                values='Amount',
                title="Data sources percentage by type",
                hole=0.3,
            )
            st.plotly_chart(fig3, use_container_width=True)
        else:
            st.write("No data available.")


    # Create two columns for pie and scatter charts
    bar2_col, scatter_col = st.columns(2)

    with bar2_col:
        if hb2_data is not None:
            fig2 = px.bar(
                hb2_data,
                x='Value',
                y='Label',
                orientation='h',
                title="Code files count by programming language",
                # labels={'Value': 'Value', 'Label': 'Label'},
                color='Label'  # Use different color for each bar
            )
            fig2.update_layout(
                yaxis={'categoryorder':'total ascending'},
                height = 400,
                xaxis_title=None,  # Remove x-axis label
                yaxis_title=None,   # Remove y-axis label
                showlegend=False
            )
            fig2.update_traces(texttemplate='%{x}', textposition='auto')  # Display values on bars
            st.plotly_chart(fig2, use_container_width=True)
        else:
            st.write("No data available for Horizontal Bar Chart 2.")



    with scatter_col:
        if scatter_data is not None:
            # Assuming the CSV has 'X', 'Y', and 'Category' columns
            unique_categories = scatter_data['Category'].nunique()
            fig4 = px.scatter(
                scatter_data,
                x='X',
                y='Y',
                color='Category',
                title="Code Sophistication",
                color_discrete_sequence=px.colors.qualitative.Plotly[:6],
            )
            fig4.update_layout(
                xaxis_title = "Number of lines",
                yaxis_title = "Number of Components"
            )  # Remove x-axis label
            st.plotly_chart(fig4, use_container_width=True)
        else:
            st.write("No data available for Scatter Chart.")


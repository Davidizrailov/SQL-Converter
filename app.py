# Code for the streamlit app

import streamlit as st
import time
from translator import Translator
from model_classes import ConfigLoader


#############################################################################################            
# Layout
#############################################################################################            

st.image("files\ey.jpg",width=300)  
st.title("EY Code Translator")

st.write('''Welcome to the EY Code Translator, a GenAI-powered tool designed to streamline code translation and debugging. This tool supports translation between SQR, Easytrieve, and PLSQL, using advanced AI models GPT-4 and GPT-4o for accurate and efficient conversions.

Key features include:

* **Input Language Selector**: Choose your source code language.
* **Model Selector**: Select between GPT-4 and GPT-4o for translation.
* **Document Uploader**: Easily upload your code for translation.
* **Syntax Correction**: Test and correct syntax errors in the translated code.
* **Debugging Tool**: Diagnose and resolve issues with built-in error messages and a retry option.''')

#############################################################################################            
# Session_state Variables
#############################################################################################            

if 'placeholder_tr' not in st.session_state:
    st.session_state.placeholder_tr = st.empty()

if 'translate_button_pressed' not in st.session_state:
    st.session_state.translate_button_pressed = False

if 'translated_code' not in st.session_state:
    st.session_state.translated_code = ''

if 'translator' not in st.session_state:
    st.session_state.translator = None
    

#############################################################################################            
# Configuration
#############################################################################################            

language = st.selectbox("Input Language", ["PLSQL", "SQR", "Easytrieve"])
if language=="Easytrieve": language="ET"
config = ConfigLoader(language=language)

model = st.selectbox("Model", ["GPT4", "GPT4o"])

#############################################################################################            
# Input Code
#############################################################################################            

uploaded_file = st.file_uploader("Document to translate", type=["txt", "docx", "pdf"])

if uploaded_file is not None:
    file_content = uploaded_file.read().decode("utf-8")
    
    st.header("Input Code")
    code_input = st.text_area(label="Input Code", 
                              value=file_content, 
                              height=500)

#############################################################################################            
# Translation
#############################################################################################            
    demo = False
    st.session_state.translator = Translator(code   = file_content, 
                                             config = config)
    
    st.session_state.translate_button_pressed = st.button("Translate", use_container_width=True)
    if st.session_state.translate_button_pressed:
        st.session_state.translated_code = st.session_state.translator.translate(demo=demo)
        if not demo:
            st.session_state.translator.save()
        

    st.header("Translated Code")
    st.session_state.placeholder_tr = st.empty()
    if st.session_state.translated_code == 'error':
        st.session_state.placeholder_tr.error("Code was not translated. We encountered an issue with the model API.")
    else:
        translated_code = st.session_state.placeholder_tr.text_area(
                                label  = "Translated Code", 
                                value  = st.session_state.translated_code,
                                height = 500)
 
    # st.write(f"{translated_code}")

#############################################################################################            
# Syntax check
#############################################################################################            
    demo = True
    if st.button("Test Syntax", use_container_width=True):
        syn_error = st.session_state.translator.test_syntax(translated_code, demo=demo)
        placeholder_syn = st.empty()
        placeholder_syn.text("Analyzing syntax...")
        time.sleep(1)
        if syn_error:
            with placeholder_syn.container():
                st.error("The following syntax errors were found:")
                st.write(syn_error)
        else:
            placeholder_syn.info("No syntax errors were found")

#############################################################################################            
# Debugging 
#############################################################################################            

    demo = False
    error_message = st.text_area("Error message")
    
    if st.button("Retry", use_container_width=True):
        placeholder_ret = st.empty()
        translated_code = st.session_state.translator.get_follow_up(error_message, demo=demo)
        st.session_state.placeholder_tr.text_area(label  = "Translated Code ",
                                                  value  = translated_code, 
                                                  height = 500)
        with placeholder_ret.container():
            st.info("New translation created!")
            st.markdown("[Click here](#translated-code) to see it.")


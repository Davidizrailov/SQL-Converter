import os
import prompts
import codeinput_PLSQL
from dotenv import load_dotenv
import requests
# from requests.packages.urllib3.exceptions import InsecureRequestWarning

# Load environment variables
load_dotenv()

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")

# Suppress only the single InsecureRequestWarning from urllib3 needed
# requests.packages.urllib3.disable_warnings(InsecureRequestWarning)

#model params
model = "gpt-4o"
temperature = 0.7
max_tokens = 2000

message_history = []

language = "PLSQL"

# Insert code here
code = codeinput_PLSQL.code

#Prompts
if language == "PLSQL":
    system_message = prompts.system_message_PLSQL
    prompt = prompts.generate_prompt_PLSQL(code)
elif language == "ET":
    system_message = prompts.system_message_ET
    prompt = prompts.generate_prompt_ET(code)
elif language == "SQR":
    system_message = prompts.system_message_SQR
    prompt = prompts.generate_prompt_SQR(code)    


# Add initial messages to the history
message_history.append({"role": "system", "content": system_message})
message_history.append({"role": "user", "content": prompt})

# API request
def oracle_to_snowflake():
    url = "https://api.openai.com/v1/chat/completions"
    headers = {
        "Authorization": f"Bearer {OPENAI_API_KEY}",
        "Content-Type": "application/json"
    }
    data = {
        "model": model,
        "messages": [
            {"role": "system", "content": system_message},
            {"role": "user", "content": prompt}
        ],
        "temperature": temperature,
        "max_tokens": max_tokens
    }
    
    response = requests.post(url, headers=headers, json=data, verify=False)
    response.raise_for_status()  # Raise an exception for HTTP errors
    ouput = response.json()['choices'][0]['message']['content']
    return str(ouput)

# Get the initial response
initial_response = oracle_to_snowflake()
# print(initial_response)

#access n'th response
response_lists = initial_response.split('+++++')
print(response_lists[2])

# print(initial_response)

# Add the initial response to the history
message_history.append({"role": "assistant", "content": initial_response})

# Function to ask follow-up questions
def follow_up(question):
    message_history.append({"role": "user", "content": question})
    follow_up_response = oracle_to_snowflake()
    print(follow_up_response)
    message_history.append({"role": "assistant", "content": follow_up_response})

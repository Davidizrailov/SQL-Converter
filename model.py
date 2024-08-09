import os
import prompts
import codeinput_PLSQL
from dotenv import load_dotenv
import requests

# Load environment variables
load_dotenv()
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")

# Model params
model = "gpt-4o-2024-08-06"
temperature = 0.5
max_tokens = 2000

message_history = []
final_response = None

language = "PLSQL"

# Insert code here
code = codeinput_PLSQL.code

# Prompts
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

original_message = message_history

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
            message_history
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

# Access n'th response
response_lists = initial_response.split('+++++')
print(response_lists[0])
print(response_lists[1])
print(response_lists[2])
print(response_lists[3])
print(response_lists[4])


# Function to ask follow-up questions
def follow_up(error, previous_output):
    message_history.append({"role": "user", "content": error})
    follow_up_response = oracle_to_snowflake()
    message_history.append({"role": "assistant", "content": follow_up_response})
    return follow_up_response

# Function which tests code 
def snowflake_test(input_code):
    # Check to see if error free
    error_log = None
    if error_log == None:
        return True
    else: 
        return error_log

# Code block here to test response 1-5
for i in range(5):
    if snowflake_test(response_lists[i]) == True:
        final_response = response_lists[i]
        break

max_iters = 5
# If 1-5 dont work
if final_response is None:
    for i in range(5):
        message_history = original_message
        previous_output = response_lists[i]
        for j in range(max_iters):
            test_result = snowflake_test(response_lists[i])
            if test_result is True:
                final_response = response_lists[i]
                break
            else:
                # Use the error message as the follow-up prompt
                response_lists[i] = follow_up(test_result, response_lists[i])

        if final_response is not None:
            break

if final_response is None:
    print("None of the responses worked. Returning white flag.")
else:
    print(final_response)

        
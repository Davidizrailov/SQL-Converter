import os
import prompts
from dotenv import load_dotenv
from openai import OpenAI
import time

# Load environment variables
load_dotenv()
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
client = OpenAI(api_key = OPENAI_API_KEY)

# Configuration
language = "PLSQL"
count=0

# Txt file read
with open('code.txt', 'r') as file:
    code = file.read()


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

# Vector Store Init
vector_store = client.beta.vector_stores.create(name="Documents")

# Add files to Vector Store
file_paths = ["Documents\ET.txt", "Documents\Snowflake_Procedures.txt, Documents\SQR.txt"]
file_streams = [open(path, "rb") for path in file_paths]

file_batch = client.beta.vector_stores.file_batches.upload_and_poll(
  vector_store_id=vector_store.id, files=file_streams
)

# Assistant
assistant = client.beta.assistants.create(
  name="SQLConverter",
  instructions=system_message,
  tools=[{"type": "file_search"}],
  model="gpt-4o",
  temperature=0.5
)
assistant = client.beta.assistants.update(
  assistant_id=assistant.id,
  tool_resources={"file_search": {"vector_store_ids": [vector_store.id]}},
)

# Thread Init
thread = client.beta.threads.create()

# Premade prompt as first message
message = client.beta.threads.messages.create(
  thread_id=thread.id,
  role="user",
  content=prompt
)

# Run
run = client.beta.threads.runs.create(
  thread_id=thread.id,
  assistant_id=assistant.id
)

# Wait for run to complete
while run.status != "completed":
    time.sleep(1) 
    run = client.beta.threads.runs.retrieve(
        thread_id=thread.id,
        run_id=run.id
    )
    
# Get message
response_message = client.beta.threads.messages.list(thread_id=thread.id)
new_message = response_message.data[0].content[0].text.value
print(new_message)



# Error handling
follow_up = input("Insert Error message here or 'success' if no errors: ")

while follow_up != "success":
  message = client.beta.threads.messages.create(
    thread_id=thread.id,
    role="user",
    content=follow_up
  )
  run = client.beta.threads.runs.create(
    thread_id=thread.id,
    assistant_id=assistant.id
  )
  while run.status != "completed":
    time.sleep(1) 
    run = client.beta.threads.runs.retrieve(
        thread_id=thread.id,
        run_id=run.id
  )
  response_message = client.beta.threads.messages.list(thread_id=thread.id)
  follow_up_response = response_message.data[0].content[0].text.value
  print("Follow-Up Response:", follow_up_response)
  follow_up = input("Insert Error message here or 'success' if no errors: ")


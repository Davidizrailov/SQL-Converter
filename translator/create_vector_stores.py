from openai import OpenAI
import os
import dotenv
from translator.model_classes import *

# vector_store_ids = VectorStoreIDs(language="plsql").get()
# print(vector_store_ids.get())

api_key = os.getenv("OPENAI_API_KEY_EPS")
client = OpenAI(api_key=api_key)



# assistant = client.beta.assistants.create(
#     name="SQLConverter",
#     instructions="You are a useful assistant",
#     tools=[{"type": "file_search"}],
#     model="gpt-4o",
#     temperature=0.5,
#     tool_resources={"file_search": {"vector_store_ids": vector_store_ids}},
# )
# # print(assistant.id)
# print("*********************","Assistant created. ID:",assistant.id)

# assistant = client.beta.assistants.update(
#     assistant_id=assistant.id,
# )

# dotenv.load_dotenv()

# et_vs_id = os.getenv("PLSQL_VS_ID")
# print(et_vs_id)


file = client.files.create(
  file = open("Documents/SQR.txt", "rb"),
  purpose='assistants'
)
print("*********************","File created. ID:",file.id)

SNOWFLAKE_FILE_ID  = "file-WedBVmjgCUwsYNLbpJom7zot"
# EASYTRIEVE_FILE_ID = "file-eZGIXz9DRhE7W4rgE17Md3nP"

vector_store = client.beta.vector_stores.create(
  name="SQR Documentation",
  file_ids=[SNOWFLAKE_FILE_ID, file.id]
)
print("*********************","Vector store created. ID:", vector_store.id)



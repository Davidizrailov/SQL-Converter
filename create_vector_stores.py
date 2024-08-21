from openai import OpenAI
import os
import dotenv

dotenv.load_dotenv()

et_vs_id = os.getenv("PLSQL_VS_ID")
print(et_vs_id)

# api_key = os.getenv("OPENAI_API_KEY_EPS")
# client = OpenAI(api_key=api_key)

# file = client.files.create(
#   file = open("Documents/ET.txt", "rb"),
#   purpose='assistants'
# )
# print("*********************","File created. ID:",file.id)

# vector_store = client.beta.vector_stores.create(
#   name="Easytrieve Documentation",
#   file_ids=[file.id]
# )
# print("*********************","Vector store created. ID:", vector_store.id)

import os
import app.prompts as prompts
from openai import OpenAI
import time
from dotenv import load_dotenv

load_dotenv()
api_key = os.getenv("OPENAI_API_KEY")
client = OpenAI(api_key=api_key)


vector_store = client.beta.vector_stores.create(
  name="_VS",
)

files=[os.path.join("Documents", "ET.txt"), os.path.join("Documents", "Snowflake_Procedures.txt"), os.path.join("Documents", "SQR.txt")]
file_streams = [open(path, "rb") for path in files]

file_batch = client.beta.vector_stores.file_batches.upload_and_poll(
  vector_store_id=vector_store.id, files=file_streams
)

print(vector_store.id)
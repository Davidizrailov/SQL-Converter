from openai import OpenAI
from dotenv import load_dotenv
import os
import claude_prompts

load_dotenv()


client = OpenAI(
    base_url="https://api.crosshatch.app/v1",
    api_key=os.getenv("CROSSHATCH_API_KEY")
)

lang = "SQR"
path = r"demo_files\DEMO_DB\SQR\dates.sqr"

with open(path, "r") as file:
    code = file.read()

if lang =="PLSQL":
    prompt = claude_prompts.plsql_prompt(code)
if lang =="SQR":
    prompt = claude_prompts.sqr_prompt(code)
if lang =="ET":
    prompt = claude_prompts.easytrieve_prompt(code)


completion = client.chat.completions.create(
    model="moa-coding",
    messages=[
        {"role": "user", "content": prompt}
    ]
)

response = completion.choices[0].message.content
print(response)


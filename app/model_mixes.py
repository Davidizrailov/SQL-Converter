from openai import OpenAI
from dotenv import load_dotenv
import os
import claude_prompts

load_dotenv()


client = OpenAI(
    base_url="https://api.crosshatch.app/v1",
    api_key=os.getenv("CROSSHATCH_API_KEY")
)

lang = "PLSQL"
path = r"demo_files\DEMO_DB\PLSQL\JTA\triggers.sql"

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


base_filename = os.path.basename(path)
        
        
output_directory = os.path.join("demo_files", "output", "mixed_model")
new_path = os.path.join(output_directory, f"{os.path.splitext(base_filename)[0]}_translated{os.path.splitext(base_filename)[1]}")
        
        
os.makedirs(output_directory, exist_ok=True)
        
        
with open(new_path, 'w', encoding='utf-8') as file:
    file.write(response)

print(response)


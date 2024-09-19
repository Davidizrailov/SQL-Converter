import os

from openai import OpenAI
import time
from dotenv import load_dotenv

class ConfigLoader:
    def __init__(self, language):

        load_dotenv()
        self.api_key = os.getenv("OPENAI_API_KEY_EPS")
        self.language = language

class OpenAIClient:
    def __init__(self, api_key):
        self.client = OpenAI(api_key=api_key)

class CodeReader:
    def __init__(self, file_path):
        self.file_path = file_path

    def read_code(self):
        with open(self.file_path, "r") as file:
            return file.read()

            
class AssistantManager:
    def __init__(self, client):
        self.client = client
        self.assistant = self.client.beta.assistants.create(
            name="CodeDescription",

            model="gpt-4o",
            temperature=0.2,

        )

    def create_thread(self):
        return self.client.beta.threads.create()

    def send_message(self, thread_id, content, role="user"):
        return self.client.beta.threads.messages.create(
            thread_id=thread_id,
            role=role,
            content=content
        )

    def run_thread(self, thread_id):
        run = self.client.beta.threads.runs.create(
            thread_id=thread_id,
            assistant_id=self.assistant.id
        )

        while (run.status != "completed") and (run.status != "failed"):
            # print(run.status)
            time.sleep(1)
            run = self.client.beta.threads.runs.retrieve(
                thread_id=thread_id,
                run_id=run.id
            )
        # print(run.status)
        # print(run.usage.total_tokens)
        return run

    def get_response_message(self, thread_id):
        response_message = self.client.beta.threads.messages.list(thread_id=thread_id)
        return response_message.data[0].content[0].text.value


    

# Main 
def main(file, lang):
    config = ConfigLoader(lang) 

    client = OpenAIClient(config.api_key)
    code_reader = CodeReader(file)
    code = code_reader.read_code()
    
  
    prompt = f"Describe what the {lang} code does in one or two sentences max. Here is the code: {code}. No need to specify the language. Use sentences not a list"
    



    assistant_manager = AssistantManager(client.client)
    thread = assistant_manager.create_thread()
    assistant_manager.send_message(thread.id, prompt)
    assistant_manager.run_thread(thread.id)
    
    
    response_message = assistant_manager.get_response_message(thread.id)
    return response_message
    


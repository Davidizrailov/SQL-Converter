import os
import prompts as prompts
from openai import OpenAI
import time
from dotenv import load_dotenv

class ConfigLoader:
    def __init__(self, language = "Java"):
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

class PromptGenerator:
    def __init__(self, language, code):
        self.language = language
        self.code = code

    def generate_prompt(self):
        return prompts.business_rules(self.code)

class VectorStoreManager:
    def __init__(self, language):
        if language in ["PLSQL", "SQR", "ET"]:
            if language == "PLSQL":
                self.vector_store_id = os.getenv("SNOWFLAKE_VS_ID")            
            elif language == "SQR":
                self.vector_store_id = os.getenv("SQR_VS_ID")            
            elif language == "ET":
                self.vector_store_id = os.getenv("EASYTRIEVE_VS_ID")
        else:
            self.vector_store_id = None  # Do not use vector store for other languages

class AssistantManager:
    def __init__(self, client, vector_store_id):
        self.client = client
        self.assistant = self.client.beta.assistants.create(
            name="BusinessRulesAnalyzer",
            tools=[{"type": "file_search"}],
            model="gpt-4o",
            temperature=0.4,
            tool_resources={
                "file_search": {
                    "vector_store_ids": [vector_store_id] if vector_store_id else []
                }
            }
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
            print(run.status)
            time.sleep(1)
            run = self.client.beta.threads.runs.retrieve(
                thread_id=thread_id,
                run_id=run.id
            )
        print(run.status)
        
        return run

    def get_response_message(self, thread_id):
        response_message = self.client.beta.threads.messages.list(thread_id=thread_id)
        return response_message.data[0].content[0].text.value

    

# Main 
def main():
    config = ConfigLoader(language="Java") 

    client = OpenAIClient(config.api_key)
    code_reader = CodeReader("demo_files\Java\Main.java")
    code = code_reader.read_code()

    prompt_generator = PromptGenerator(config.language, code)
    prompt = prompt_generator.generate_prompt()

    vector_store_manager = VectorStoreManager(language=config.language)
    vector_store_id = vector_store_manager.vector_store_id

    assistant_manager = AssistantManager(client.client, vector_store_id)
    thread = assistant_manager.create_thread()
    assistant_manager.send_message(thread.id, prompt)
    assistant_manager.run_thread(thread.id)
    

    
    response_message = assistant_manager.get_response_message(thread.id)
    
    #show analysis
    print(response_message)


if __name__ == "__main__":
    main()

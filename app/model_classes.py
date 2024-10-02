import os
import prompts as prompts
from openai import OpenAI
import time
from dotenv import load_dotenv

class ConfigLoader:
    def __init__(self, language, target):
        load_dotenv()
        self.api_key = os.getenv("OPENAI_API_KEY_EPS")
        self.language = language
        self.target = target

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
    def __init__(self, language, target, code):
        self.language = language
        self.code = code
        self.target = target

    def generate_prompt(self):
        system_prompt = prompts.get_system_prompt(self.language, self.target)
        first_prompt = prompts.generate_prompt(self.language, self.target, self.code)
        return system_prompt, first_prompt

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
            name="SQLConverter",
            tools=[{"type": "file_search"}],
            model="gpt-4o",
            temperature=0.3,
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

class ErrorHandler:
    def __init__(self, assistant_manager, thread_id):
        self.assistant_manager = assistant_manager
        self.thread_id = thread_id

    def get_follow_up_response(self, follow_up):
        self.assistant_manager.send_message(self.thread_id, follow_up)
        self.assistant_manager.run_thread(self.thread_id)
        follow_up_response = self.assistant_manager.get_response_message(self.thread_id)
        return follow_up_response

    def handle_errors(self):
        follow_up = input("Insert Error message here or 'success' if no errors: ")
        while follow_up != "success":
            follow_up_response = self.get_follow_up_response(follow_up)
            print("Follow-Up Response:", follow_up_response)
            follow_up = input("Insert Error message here or 'success' if no errors: ")
        return None if follow_up == "success" else follow_up_response
    

# Main 
def main():
    config = ConfigLoader(language="Cobol") 

    client = OpenAIClient(config.api_key)
    code_reader = CodeReader("coboltest.cbl")
    code = code_reader.read_code()

    prompt_generator = PromptGenerator(config.language, code)
    system_message, prompt = prompt_generator.generate_prompt()

    vector_store_manager = VectorStoreManager(language=config.language)
    vector_store_id = vector_store_manager.vector_store_id

    assistant_manager = AssistantManager(client.client, vector_store_id)
    thread = assistant_manager.create_thread()
    assistant_manager.send_message(thread.id, prompt)
    assistant_manager.run_thread(thread.id)
    print("analysis complete!")
    
    response_message = assistant_manager.get_response_message(thread.id)
    
    #show analysis
    print(response_message)
    
    if config.language != "Java" and config.language !="Cobol":
        prompt2 = prompts.generate_prompt2(response_message, config.language)

        assistant_manager.send_message(thread.id, prompt2)
        assistant_manager.run_thread(thread.id)
        print("compilation complete!")

        response_message = assistant_manager.get_response_message(thread.id)
        print(response_message)

    error_handler = ErrorHandler(assistant_manager, thread.id)
    error_handler.handle_errors()

if __name__ == "__main__":
    main()

import os
import prompts
from openai import OpenAI
import time

class ConfigLoader:
    def __init__(self, language="PLSQL"):
        # load_dotenv()
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
        if self.language == "PLSQL":
            return prompts.system_message_PLSQL, prompts.generate_prompt_PLSQL(self.code)
        elif self.language == "ET":
            return prompts.system_message_ET, prompts.generate_prompt_ET(self.code)
        elif self.language == "SQR":
            return prompts.system_message_SQR, prompts.generate_prompt_SQR(self.code)

class VectorStoreManager:
    def __init__(self, client):
        self.client = client
        self.vector_store = self.client.beta.vector_stores.create(name="Documents")

    def upload_files(self, file_paths):
        file_streams = [open(path, "rb") for path in file_paths]
        file_batch = self.client.beta.vector_stores.file_batches.upload_and_poll(
            vector_store_id=self.vector_store.id, files=file_streams
        )

class AssistantManager:
    def __init__(self, client, system_message, vector_store):
        self.client = client
        self.assistant = self.client.beta.assistants.create(
            name="SQLConverter",
            instructions=system_message,
            tools=[{"type": "file_search"}],
            model="gpt-4o",
            temperature=0.5
        )
        self.assistant = self.client.beta.assistants.update(
            assistant_id=self.assistant.id,
            tool_resources={"file_search": {"vector_store_ids": [vector_store.id]}},
        )

    def create_thread(self):
        return self.client.beta.threads.create()

    def send_message(self, thread_id, content):
        return self.client.beta.threads.messages.create(
            thread_id=thread_id,
            role="user",
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
        return follow_up_response
    

# Main 
def main():
    config = ConfigLoader()
    client = OpenAIClient(config.api_key)

    code_reader = CodeReader("files/code_PLSQL.txt")
    code = code_reader.read_code()

    prompt_generator = PromptGenerator(config.language, code)
    system_message, prompt = prompt_generator.generate_prompt()

    vector_store_manager = VectorStoreManager(client.client)
    # vector_store_manager.upload_files(["Documents\ET.txt", "Documents\Snowflake_Procedures.txt", "Documents\SQR.txt"])
    vector_store_manager.upload_files(["Documents\Snowflake_Procedures.txt"])

    assistant_manager = AssistantManager(client.client, 
                                         system_message, 
                                         vector_store = vector_store_manager.vector_store)
    thread = assistant_manager.create_thread()
    # print(thread.id)
    # print(assistant_manager.assistant.id)
    assistant_manager.send_message(thread.id, prompt)
    assistant_manager.run_thread(thread.id)

    response_message = assistant_manager.get_response_message(thread.id)
    print(response_message)

    error_handler = ErrorHandler(assistant_manager, thread.id)
    error_handler.handle_errors()

if __name__ == "__main__":
    main()

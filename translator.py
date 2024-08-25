from model_classes import *
from code_checker import Linter
import os

class Translator:
    def __init__(self, code, config):
        self.code = code
        self.config = config
        self.assistant_manager = None
        self.thread = None
        # self.gpt = gpt 

    def translate(self, demo=True):
        if demo:
            with open(os.path.join("files", "response_1.txt")) as file:
                translated_code = file.read()
            return translated_code
        else:
            client = OpenAIClient(self.config.api_key)

            # code_reader = CodeReader("code.txt")
            # code = code_reader.read_code()

            prompt_generator = PromptGenerator(self.config.language, self.code)
            system_message, prompt = prompt_generator.generate_prompt()

            # vector_store_manager = VectorStoreManager(client.client)
            # vector_store_manager.upload_files([os.path.join("Documents", "ET.txt"), os.path.join("Documents", "Snowflake_Procedures.txt"), os.path.join("Documents", "SQR.txt")])
            # vector_store_manager.upload_files([os.path.join("Documents", "Snowflake_Procedures.txt")])

            vector_store_ids = VectorStoreIDs(language=self.config.language).get()
            print(vector_store_ids)
            
            self.assistant_manager = AssistantManager(client.client, 
                                                      system_message, 
                                                      vector_store_ids = vector_store_ids)
            
            self.thread = self.assistant_manager.create_thread()

            self.assistant_manager.send_message(self.thread.id, prompt)
            run = self.assistant_manager.run_thread(self.thread.id)
            if run.status == "completed":
                response_message = self.assistant_manager.get_response_message(self.thread.id)
            else:
                response_message = 'error'
        return response_message
    
    def test_syntax(self, input_code, demo=True):
        if demo:
            errors = {}
        else:
            linter = Linter(['python', 'sql'])
            errors = linter.check_response(input_code)
        return errors
    
    
    def retry(self, error_message, demo=True):
        if demo:
            with open(os.path.join("old", "response_2.txt")) as file:
                translated_code_retry = file.read()
        else:
            # assistant_manager, thread = self.load()
            error_handler = ErrorHandler(self.assistant_manager, self.thread.id)
            translated_code_retry = error_handler.get_follow_up_response(error_message)
        return translated_code_retry
    
    
    def save(self):
        with open(os.path.join("files", "assistant_id"), "w") as f:
            f.write(self.assistant_manager.assistant.id)
        f.close()
        with open(os.path.join("files", "thread_id"),"w") as f:
            f.write(self.thread.id)
        f.close()

    def load(self):
        with open(os.path.join("files", "assistant_id"), 'r') as f:
            assistant_id = f.read()
        with open(os.path.join("files", "thread_id"), 'r') as f:
            thread_id = f.read()
            # thread_id = pickle.load(f)            
        return assistant_id, thread_id
    
    def get_follow_up(self, error_message, demo = False):
        if demo:
            with open(os.path.join("files", "response_2.txt")) as file:
                follow_up = file.read()
        else:
            assistant_id, thread_id = self.load()
            client = OpenAI(api_key=os.getenv('OPENAI_API_KEY_EPS'))
            client.beta.threads.messages.create(
                        thread_id = thread_id,
                        role      = "user",
                        content   = error_message
                    )
            run = client.beta.threads.runs.create(
                        thread_id    = thread_id,
                        assistant_id = assistant_id
                    )
            while run.status != "completed":
                print(run.status)
                time.sleep(1)
                run = client.beta.threads.runs.retrieve(
                    thread_id = thread_id,
                    run_id    = run.id
                )
                print(run.status)
            response_message = client.beta.threads.messages.list(thread_id=thread_id)
            follow_up = response_message.data[0].content[0].text.value

        return follow_up

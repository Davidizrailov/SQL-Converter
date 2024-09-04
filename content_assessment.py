from model_classes_2 import *

class AssistantManager2:
    def __init__(self, client):
        self.client = client
        self.assistant = self.client.beta.assistants.create(
            name="Content_Assessment_agent",
            model="gpt-4o",
            temperature=0.8,
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


def main():
    config = ConfigLoader(language="PLSQL") 

    client = OpenAIClient(config.api_key)
    code_reader = CodeReader(r"files\content_assessment\test_proc1.txt")
    code = code_reader.read_code()
    prompt = prompts.content_assessment2(code)

    assistant_manager = AssistantManager2(client.client)
    thread = assistant_manager.create_thread()
    assistant_manager.send_message(thread.id, prompt)
    assistant_manager.run_thread(thread.id)
    print("done!")
    
    response_message = assistant_manager.get_response_message(thread.id)
    #print(response_message)

    with open("files\content_assessment\out.txt","w", encoding="utf-8") as file:
        file.write(response_message)
        print("Written!")

if __name__ == "__main__":
    main()



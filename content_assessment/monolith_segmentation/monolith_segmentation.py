import os
import re
import time
import shutil

# Define the file paths
input_file_path = "C:/Users/NW538RY/OneDrive - EY/Desktop/monolithe.sas"
output_dir = "C:/Users/NW538RY/OneDrive - EY/Desktop/monolith_segments"


# Define regex patterns for key sections
patterns = {
    "PROC_SQL": r"(PROC SQL.*?QUIT;)",  # Match PROC SQL blocks
    "MACRO": r"(%MACRO.*?%MEND;)",  # Match MACRO blocks
    "DATA": r"(DATA.*?RUN;)",  # Match DATA steps
    "OTHER": r"(PROC.*?QUIT;|RUN;)"  # General PROC and RUN blocks
}




def delete_files_in_folder(folder_path):
    if not os.path.exists(folder_path):
        print(f"The folder '{folder_path}' does not exist.")
        return

    # List all files and folders in the given directory
    for filename in os.listdir(folder_path):
        file_path = os.path.join(folder_path, filename)
        
        try:
            # If it's a file, remove it
            if os.path.isfile(file_path) or os.path.islink(file_path):
                os.remove(file_path)
            # If it's a directory, remove it and its contents
            elif os.path.isdir(file_path):
                shutil.rmtree(file_path)
        except: pass

def save_chunk(content, chunk_type, chunk_num):
    """ Saves the given content to a file with a proper name based on the chunk type and number. """
    file_name = f"{chunk_type}_{chunk_num}.sas"
    print(file_name)
    time.sleep(.02)
    with open(os.path.join(output_dir, file_name), 'w') as file:
        file.write(content)

def split_sas_code(input_file_path):
    chunk_num = 1
    with open(input_file_path, 'r') as file:
        content = file.read()  # Read the entire file content

        for chunk_type, pattern in patterns.items():
            matches = re.findall(pattern, content, re.DOTALL | re.IGNORECASE)  # Find all matches for the pattern
            for match in matches:
                save_chunk(match, chunk_type, chunk_num)
                chunk_num += 1
                content = content.replace(match, '')  # Remove the processed section to avoid duplicate processing

        # Save any remaining content (if any sections did not match)
        if content.strip():
            save_chunk(content, "UNKNOWN", chunk_num)

# Execute the global splitting function
os.startfile(input_file_path)
start = input("Start Analysis (y/n):  ")
if start:
    # Ensure the output directory exists
    os.makedirs(output_dir, exist_ok=True)
    delete_files_in_folder(output_dir)
    os.startfile(output_dir)
    time.sleep(2)
    split_sas_code(input_file_path)

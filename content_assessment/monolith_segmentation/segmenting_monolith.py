import os
import re
import time

# Define the file paths
input_file_path = "C:/Users/NW538RY/OneDrive - EY/Desktop/programme.txt"
output_dir = "C:/Users/NW538RY/OneDrive - EY/Desktop/monolith_segments"

# Ensure the output directory exists
os.makedirs(output_dir, exist_ok=True)

# Define regex patterns for key sections
patterns = {
    "PROC_SQL": r"(PROC SQL.*?QUIT;)",  # Match PROC SQL blocks
    "MACRO": r"(%MACRO.*?%MEND;)",  # Match MACRO blocks
    "DATA": r"(DATA.*?RUN;)",  # Match DATA steps
    "OTHER": r"(PROC.*?QUIT;|RUN;)"  # General PROC and RUN blocks
}

def save_chunk(content, chunk_type, chunk_num):
    """ Saves the given content to a file with a proper name based on the chunk type and number. """
    file_name = f"{chunk_type}_{chunk_num}.sas"
    print(file_name)
    time.sleep(.05)
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
split_sas_code(input_file_path)

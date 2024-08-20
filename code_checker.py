# python scripts installed by pip must be executable from program's environment
import re
import subprocess

def run_command(command):
  result = subprocess.run(command, shell=True, capture_output=True, text=True)
  return result.returncode, result.stdout.strip(), result.stderr.strip()

class LinterError:
  pylint_threshold = 0b100
  sqfluff_threshold = 2

  def __init__(self, type, rc, stdout, stderr):
    self.rc = rc
    self.stdout = stdout
    self.stderr = stderr
    self.type = type
    
  def is_fatal(self):
    if self.type == "sql":
      return "prs" in self.stderr.lower() or "prs" in self.stdout.lower()
    elif self.type == "python":
      return self.rc > 0 and self.rc < self.pylint_threshold
    assert(False)
  
  def __repr__(self):
    return self.stderr + self.stdout
  def __str__(self):
    return self.__repr__()


class Linter:
  linter_commands = {
    "python": "pylint -d C,R,I ", 
    "sql": "sqlfluff lint --ignore parsing --rules core --dialect snowflake ",
  }

  def __init__(self, type=['python', 'sql']):
    assert len(type) > 0, "Number of languages should be more than 0"
    self.type = type
  
  def _find_code(self, s, lang):
    sql_pattern = None
    if lang == "sql":
      sql_pattern = r"(?s)```sql(.*?)```"
    if lang == "python":
      sql_pattern = r"(?s)```python(.*?)```"
    return re.findall(sql_pattern, s)
  
  def find_code(self, s):
    res = {}
    for lang in self.type:
      res[lang] = self._find_code(s, lang)
    return res
  
  def check_response(self, response):
    matches = self.find_code(response)

    errors = {}
    for lang in self.type:
      for i, code in enumerate(matches[lang]):
        with open(f'temp_code_{i}.code', 'w') as file:
            file.write(code.strip())
        rc, stdout, stderr = run_command(self.linter_commands[lang] + f"temp_code_{i}.code")
        error = LinterError(lang, rc, stdout, stderr)
        if error.is_fatal():
          errors[f'python_code_{i}'] = error

    return errors
  
  def prompt_after_code(self, errors):
    if not errors:
      return None
    fix_prompt = "The code you wrote produces the following errors/warnings. Please fix them.\n"
    for key, val in errors.items():
      fix_prompt += f"linter output for code snippet f{key}:\n" + str(val) + "\n"
    return fix_prompt
  

if __name__ == "__main__":
  linter = Linter(['python', 'sql'])
  sample_response = r"""
  ```sql
-- Create a sequence to generate unique IDs for each row
CREATE SEQUENCE seq_string_utils;

-- Create a table type to store list of characters
CREATE OR REPLACE TYPE list_char AS TABLE (char_val CHAR(1));

-- Create a table type to store list of strings
CREATE OR REPLACE TYPE list_string AS TABLE (string_val NVARCHAR(500));

-- Create a function to split text based on a separator
CREATE OR REPLACE FUNCTION split_text(text NVARCHAR, separator CHAR DEFAULT ':')
  RETURNS list_string
  LANGUAGE PYTHON
  EXECUTE AS CALLER
AS
$$
  chars = []
  strings = []
  length = 0
  start = 0
  split_start = 0
  split_length = 0
  first = True

  for char in text:
      chars.append(char)

  for i in range(len(chars)):
      if first and chars[i] == separator:
          length = 1
          split_start = start
          split_length = i
          strings.append(text[split_start:split_length])
          start = i
          first = False
          continue

      if chars[i] == separator:
          length += 1
          split_start = start + 1
          split_length = i - (start + 1)
          strings.append(text[split_start:split_length])
          start = i
          continue

      if i == len(chars) - 1:
          split_start = start + 1
          split_length = i + 1
          length += 1
          strings.append(text[split_start:split_length])

  return strings
$$;

-- Call the function to split text and output the results
DECLARE
  v_strings list_string;
BEGIN
  v_strings := split_text('12,9993,3,3,99,11,1,333333333333,4', ',');
  FOR i, val IN SELECT * FROM TABLE(v_strings) ORDER BY seq_string_utils.NEXTVAL LOOP
    -- Output each string value
    v_output := val.string_val;
    -- PRINT(v_output); -- Snowflake does not support DBMS_OUTPUT
  END LOOP;
END;
``` 
"""
  errors = linter.check_response(sample_response)
  print(linter.prompt_after_code(errors))
  
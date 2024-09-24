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

  ```python
  CREATE OR REPLACE PROCEDURE process_employee_salaries()
  RETURNS STRING
  LANGUAGE PYTHON
  RUNTIME_VERSION = '3.8'
  PACKAGES = ('snowflake-snowpark-python')
  HANDLER = 'main'
  AS
  $$
  def main(session):
      v_dept_id = 10
      v_bonus_percentage = 0.10
      v_raise_percentage = 0.05

      emp_cursors = session.sql(f"SELECT employee_id, first_name, salary FROM employees WHERE department_id = {v_dept_id}").collect()

      for emp in emp_cursor:
          v_employee_id = emp['EMPLOYEE_ID']
          v_employee_name = emp['FIRST_NAME']
          v_new_salary = emp['SALARY']

          v_bonus = v_new_salary * v_bonus_percentage
          v_raise = v_new_salary * v_raise_percentage
          v_new_salary = v_new_salary + v_raise

          session.sql(f"INSERT INTO employee_bonus (employee_id, bonus_amount, bonus_date) VALUES ({v_employee_id}, {v_bonus}, CURRENT_DATE)").collect()
          session.sql(f"UPDATE employees SET salary = {v_new_salary} WHERE employee_id = {v_employee_id}").collect()

          print(f'Employee ID: {v_employee_id}, Name: {v_employee_name}, New Salary: {v_new_salary}, Bonus: {v_bonus}')

      v_avg_salary = session.sql(f"SELECT AVG(salary) AS AVG_SALARY FROM employees WHERE department_id = {v_dept_id}").collect()[0]['AVG_SALARY']

      print(f'Average Salary in Department {v_dept_id}: {v_avg_salary}')
      return "SUCCESS"
  $$;
  ```
"""
  errors = linter.check_response(sample_response)
  print(linter.prompt_after_code(errors))
  
```sql
CREATE OR REPLACE PROCEDURE calculate_avg_salary()
RETURNS TABLE(job_title STRING, avg_salary NUMBER)
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'calculate_avg_salary_handler'
AS
$$
from snowflake.snowpark import Session
from snowflake.snowpark.functions import col

def calculate_avg_salary_handler(session: Session):
    # Create a DataFrame for the employees table
    employees_df = session.table("employees")
    
    # Get distinct job titles
    job_titles_df = employees_df.select("job_title").distinct()
    
    # Initialize result list
    result = []
    
    # Iterate through each job title
    for job_title_row in job_titles_df.collect():
        job_title = job_title_row["job_title"]
        
        # Filter employees with the current job title
        employees_with_title_df = employees_df.filter(col("job_title") == job_title)
        
        # Calculate total salary and employee count
        total_salary = employees_with_title_df.select(col("salary")).sum(col("salary")).collect()[0][0]
        employee_count = employees_with_title_df.count()
        
        # Calculate average salary
        avg_salary = total_salary / employee_count if employee_count > 0 else 0
        
        # Append the result
        result.append((job_title, avg_salary))
    
    # Return the result as a DataFrame
    return session.create_dataframe(result, schema=["job_title", "avg_salary"])

$$;

-- Call the procedure
CALL calculate_avg_salary();
```
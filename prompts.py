Snowflake_documentation = """
Writing stored procedures in Python
This topic explains how to write a stored procedure in Python. You can use the Snowpark library within your stored procedure to perform queries, updates, and other work on tables in Snowflake.

Introduction
With Snowpark Stored Procedures, you can build and run your data pipeline within Snowflake, using a Snowflake warehouse as the compute framework. Build your data pipeline by using the Snowpark API for Python to write stored procedures. To schedule the execution of these stored procedures, you use tasks.

For information on machine learning models and Snowpark Python, see Training Machine Learning Models with Snowpark Python.

You can write Snowpark Stored Procedures for Python using a Python worksheet, or using a local development environment.

You can capture log and trace data as your handler code executes. For more information, refer to Logging and tracing overview.

Note

To both create and call an anonymous procedure, use CALL (with anonymous procedure). Creating and calling an anonymous procedure does not require a role with CREATE PROCEDURE schema privileges.

Prerequisites for writing stored procedures locally
To write Python stored procedures in your local development environment, meet the following prerequisites:

You must use version 0.4.0 or a more recent version of the Snowpark library.

Enable Anaconda Packages so that Snowpark Python can load the required third party dependencies. Refer to Using third-party packages from Anaconda.

The supported versions of Python are:

3.8

3.9

3.10

3.11

Be sure to set up your development environment to use the Snowpark library. Refer to Setting Up Your Development Environment for Snowpark.

Writing the Python code for the stored procedure
For your procedure’s logic, you write handler code that executes when the procedure is called. This section describes the design of a handler.

You can create a stored procedure from the handler code in several ways:

Include the code in-line with the SQL statement that creates the procedure. Refer to Keeping handler code in-line or on a stage.

Copy the code to a stage and reference it there when you create the procedure. Refer to Keeping handler code in-line or on a stage.

Write the code in a Python worksheet and deploy the worksheet contents to a stored procedure. Refer to Creating a Python stored procedure to automate your Python worksheet code.

Limitations
Snowpark Stored Procedures have the following limitations:

Creating processes is not supported in stored procedures.

Running concurrent queries is not supported in stored procedures.

You cannot use APIs that execute PUT and GET commands, including Session.sql("PUT ...") and Session.sql("GET ...").

When you download files from a stage using session.file.get, pattern matching is not supported.

If you execute your stored procedure from a task, you must specify a warehouse when creating the task. You cannot use serverless compute resources to run the task.

Creating named temp objects is not supported in an owner’s rights stored procedure. An owner’s rights stored procedure is a stored procedure that runs with the privileges of the stored procedure owner. For more information, refer to caller’s rights or owner’s rights.

Planning to write your stored procedure
Stored procedures run inside Snowflake, and so you must plan the code that you write with that in mind.

Limit the amount of memory consumed. Snowflake places limits on a method in terms of the amount of memory needed. For guidance, refer to Designing Handlers that Stay Within Snowflake-Imposed Constraints.

Make sure that your handler method or function is thread safe.

Follow the rules and security restrictions. Refer to Security Practices for UDFs and Procedures.

Decide whether you want the stored procedure to run with caller’s rights or owner’s rights.

Consider the snowflake-snowpark-python version used to run stored procedures. Due to limitations in the stored procedures release process, the snowflake-snowpark-python library available in the Python Stored Procedure environment is usually one version behind the publicly released version. Use the following SQL to find out the latest available version:

SELECT * FROM information_schema.packages WHERE package_name = 'snowflake-snowpark-python' ORDER BY version DESC;
Writing the method or function
When writing the method or function for the stored procedure, note the following:

Specify the Snowpark Session object as the first argument of your method or function. When you call your stored procedure, Snowflake automatically creates a Session object and passes it to your stored procedure. (You cannot create the Session object yourself.)

For the rest of the arguments and for the return value, use the Python types that correspond to Snowflake data types. Snowflake supports the Python data types listed in SQL-Python Data Type Mappings for Parameters and Return Types.

When you run an asynchronous child job from within a procedure’s handler – such as by using DataFrame.collect_nowait – “fire and forget” is not supported.

In other words, if the handler issues a child query that is still running when the parent procedure job completes, the child job is canceled automatically.

Handling errors
You can use the normal Python exception-handling techniques to catch errors within the procedure.

If an uncaught exception occurs inside the method, Snowflake raises an error that includes the stack trace for the exception. When logging of unhandled exceptions is enabled, Snowflake logs data about unhandled exceptions in an event table.

Making dependencies available to your code
If your handler code depends on code defined outside the handler itself (such as code defined in a module) or on resource files, you can make those dependencies available to your code by uploading them to a stage. Refer to Making dependencies available to your code, or for Python worksheets, refer to Add a Python File from a Stage to a Worksheet.

If you create your stored procedure using SQL, use the IMPORTS clause when writing the CREATE PROCEDURE statement, to point to the dependency files.

Accessing data in Snowflake from your stored procedure
To access data in Snowflake, use the Snowpark library APIs.

When handling a call to your Python stored procedure, Snowflake creates a Snowpark Session object and passes the object to the method or function for your stored procedure.

As is the case with stored procedures in other languages, the context for the session (e.g. the privileges, current database and schema, etc.) is determined by whether the stored procedure runs with caller’s rights or owner’s rights. For details, see Accessing and setting the session state.

You can use this Session object to call APIs in the Snowpark library. For example, you can create a DataFrame for a table or execute an SQL statement.

See the Snowpark Developer Guide for more information.

Data access example
The following is an example of a Python method that copies a specified number of rows from one table to another table. The method takes the following arguments:

A Snowpark Session object

The name of the table to copy the rows from

The name of the table to save the rows to

The number of rows to copy

The method in this example returns a string. If you run this example in a Python worksheet, change the return type for the worksheet to a String

def run(session, from_table, to_table, count):

  session.table(from_table).limit(count).write.save_as_table(to_table)

  return "SUCCESS"
Reading files
Using the SnowflakeFile class in the Snowpark snowflake.snowpark.files module, your Python handler can dynamically read a file from one of the following Snowflake stages:

A named internal stage.

A specified table’s internal stage.

The current user’s internal stage.

Snowflake supports reading files with SnowflakeFile for both stored procedures and user-defined functions. For more information about reading files in your handler code, as well as more examples, refer to Reading a File with a Python UDF Handler.

This example demonstrates how to create and call an owner’s rights stored procedure that reads a file using the SnowflakeFile class.

Create the stored procedure with an in-line handler, specifying the input mode as binary by passing rb for the mode argument:

CREATE OR REPLACE PROCEDURE calc_phash(file_path string)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.8'
PACKAGES = ('snowflake-snowpark-python','imagehash','pillow')
HANDLER = 'run'
AS
$$
from PIL import Image
import imagehash
from snowflake.snowpark.files import SnowflakeFile

def run(ignored_session, file_path):
    with SnowflakeFile.open(file_path, 'rb') as f:
        return imagehash.average_hash(Image.open(f))
$$;
Call the stored procedure:

CALL calc_phash(build_scoped_file_url(@my_files, 'my_image.jpg'));
Using third-party packages from Anaconda
You can specify Anaconda packages to install when you create Python stored procedures. To view the list of third-party packages from Anaconda, see the Anaconda Snowflake channel. These third-party packages are built and provided by Anaconda. You may use the Snowflake conda channel for local testing and development at no cost under the Supplemental Embedded Software Terms to Anaconda’s Terms of Service.

For limitations, see Limitations.

Getting started
Before you start using the packages provided by Anaconda inside Snowflake, you must acknowledge the External Offerings Terms.

Note

You must be the organization administrator (use the ORGADMIN role) to accept the terms. You only need to accept the terms once for your Snowflake account. See Enabling the ORGADMIN role in an account.

Sign in to Snowsight.

Select Admin » Billing & Terms.

In the Anaconda section, select Enable.

In the Anaconda Packages dialog, click the link to review the External Offerings Terms page.

If you agree to the terms, select Acknowledge & Continue.

If you see an error when attempting to accept the terms of service, your user profile might be missing a first name, last name, or email address. If you have an administrator role, refer to Add user details to your user profile to update your profile using Snowsight. Otherwise, contact an administrator to update your account.

Note

If you don’t acknowledge the Snowflake External Offerings Terms as described above, you can still use stored procedures, but with these limitations:

You can’t use any third-party packages from Anaconda.

You can still specify Snowpark Python as a package in a stored procedure, but you can’t specify a specific version.

You can’t use the to_pandas method when interacting with a DataFrame object.

Displaying and using packages
You can display all available packages and their version information by querying the PACKAGES view in the Information Schema:

select * from information_schema.packages where language = 'python';
For more information, see Using Third-Party Packages in the Snowflake Python UDF documentation.

Creating the stored procedure
You can create a stored procedure from a Python worksheet, or using SQL.

To create a stored procedure with SQL, see Creating a stored procedure.

To create a stored procedure from a Python worksheet, see Creating a Python stored procedure to automate your Python worksheet code.

Creating a Python stored procedure to automate your Python worksheet code
Create a Python stored procedure from your Python worksheet to automate your code. For details on writing Python worksheets, see Writing Snowpark Code in Python Worksheets.

Prerequisites
Your role must have OWNERSHIP or CREATE PROCEDURE privileges on the database schema in which you run your Python worksheet to deploy it as a stored procedure.

Deploy a Python worksheet as a stored procedure
To create a Python stored procedure to automate the code in your Python worksheet, do the following:

Sign in to Snowsight.

Open Projects » Worksheets.

Open the Python worksheet that you want to deploy as a stored procedure.

Select Deploy.

Enter a name for the stored procedure.

(Optional) Enter a comment with details about the stored procedure.

(Optional) Select Replace if exists to replace an existing stored procedure with the same name.

For Handler, select the handler function for your stored procedure. For example, main.

Review the arguments used by your handler function and if needed, override the SQL data type mapping for a typed argument. For details about how Python types are mapped to SQL types, see SQL-Python Data Type Mappings.

(Optional) Select Open in Worksheets to open the stored procedure definition in a SQL worksheet.

Select Deploy to create the stored procedure.

After the stored procedure is created, you can go to the procedure details or select Done.

You can create multiple stored procedures from one Python worksheet.

After you create a stored procedure, you can automate it as part of a task. Refer to Introduction to tasks.

Returning tabular data
You can write a procedure that returns data in tabular form. To write a procedure that returns tabular data, do the following:

Specify TABLE(...) as the procedure’s return type in your CREATE PROCEDURE statement.

As TABLE parameters, you can specify the returned data’s column names and types if you know them. If you don’t know the returned columns when defining the procedure – such as when they’re specified at run time – you can leave out the TABLE parameters. When you do, the procedure’s return value columns will be converted from the columns in the DataFrame returned by its handler. Column data types will be converted to SQL according to the mapping specified in SQL-Python Data Type Mappings.

Write the handler so that it returns the tabular result in a Snowpark DataFrame.

For more information about dataframes, see Working with DataFrames in Snowpark Python.

Example
The examples in this section illustrate returning tabular values from a procedure that filters for rows where a column matches a string.

Defining the data
Code in the following example creates a table of employees.

CREATE OR REPLACE TABLE employees(id NUMBER, name VARCHAR, role VARCHAR);
INSERT INTO employees (id, name, role) VALUES (1, 'Alice', 'op'), (2, 'Bob', 'dev'), (3, 'Cindy', 'dev');
Specifying return column names and types
This example specifies column names and types in the RETURNS TABLE() statement.

CREATE OR REPLACE PROCEDURE filterByRole(tableName VARCHAR, role VARCHAR)
RETURNS TABLE(id NUMBER, name VARCHAR, role VARCHAR)
LANGUAGE PYTHON
RUNTIME_VERSION = '3.8'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'filter_by_role'
AS
$$
from snowflake.snowpark.functions import col

def filter_by_role(session, table_name, role):
   df = session.table(table_name)
   return df.filter(col("role") == role)
$$;
Omitting return column names and types
Code in the following example declares a procedure that allows return value column names and types to be extrapolated from columns in the handler’s return value. It omits the column names and types from the RETURNS TABLE() statement.

CREATE OR REPLACE PROCEDURE filterByRole(tableName VARCHAR, role VARCHAR)
RETURNS TABLE()
LANGUAGE PYTHON
RUNTIME_VERSION = '3.8'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'filter_by_role'
AS
$$
from snowflake.snowpark.functions import col

def filter_by_role(session, table_name, role):
  df = session.table(table_name)
  return df.filter(col("role") == role)
$$;
Calling the procedure
The following example calls the stored procedure:

CALL filterByRole('employees', 'dev');
The procedure call produces the following output:

+----+-------+------+
| ID | NAME  | ROLE |
+----+-------+------+
| 2  | Bob   | dev  |
| 3  | Cindy | dev  |
+----+-------+------+
Calling your stored procedure
After creating a stored procedure, you can call it from SQL or as part of a scheduled task.

For information on calling a stored procedure from SQL, refer to Calling a stored procedure.

For information on calling a stored procedure as part of a scheduled task, refer to Introduction to tasks.

Examples
Running concurrent tasks with worker processes
You can run concurrent tasks using Python worker processes. You might find this useful when you need to run parallel tasks that take advantage of multiple CPU cores on warehouse nodes.

Note

Snowflake recommends that you not use the built-in Python multiprocessing module.

To work around cases where the Python Global Interpreter Lock prevents a multi-tasking approach from scaling across all CPU cores, you can execute concurrent tasks using separate worker processes, rather than threads.

You can do this on Snowflake warehouses by using the joblib library’s Parallel class, as in the following example.

CREATE OR REPLACE PROCEDURE joblib_multiprocessing_proc(i INT)
  RETURNS STRING
  LANGUAGE PYTHON
  RUNTIME_VERSION = 3.8
  HANDLER = 'joblib_multiprocessing'
  PACKAGES = ('snowflake-snowpark-python', 'joblib')
AS $$
import joblib
from math import sqrt

def joblib_multiprocessing(session, i):
  result = joblib.Parallel(n_jobs=-1)(joblib.delayed(sqrt)(i ** 2) for i in range(10))
  return str(result)
$$;
Note

The default backend used for joblib.Parallel differs between Snowflake standard and Snowpark-optimized warehouses.

Standard warehouse default: threading

Snowpark-optimized warehouse default: loky (multiprocessing)

You can override the default backend setting by calling the joblib.parallel_backend function, as in the following example.

import joblib
joblib.parallel_backend('loky')
Using Snowpark APIs for asynchrononous processing
The following examples illustrate how you can use Snowpark APIs to begin asynchronous child jobs, as well as how those jobs behave under different conditions.

Example 1: Checking the status of an asynchronous child job
In the following example, the checkStatus procedure executes an asynchronous child job that waits 60 seconds. The procedure then checks on the status of the job before it can have finished, so the check returns False.

CREATE OR REPLACE PROCEDURE checkStatus()
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = 3.8
PACKAGES = ('snowflake-snowpark-python')
HANDLER='async_handler'
EXECUTE AS CALLER
AS $$
def async_handler(session):
    async_job = session.sql("select system$wait(60)").collect_nowait()
    return async_job.is_done()
$$;
The following code calls the procedure.

CALL checkStatus();
+------------+
| checkStatus |
|------------|
| False      |
+------------+
Example 2: Cancelling an asynchronous child job
In the following example, the cancelJob procedure uses SQL to insert data into the test_tb table with an asynchronous child job that would take 10 seconds to finish. It then cancels the child job before it finishes and the data has been inserted.

CREATE OR REPLACE TABLE test_tb(c1 STRING);
CREATE OR REPLACE PROCEDURE cancelJob()
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = 3.8
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'async_handler'
EXECUTE AS OWNER
AS $$
def async_handler(session):
    async_job = session.sql("insert into test_tb (select system$wait(10))").collect_nowait()
    return async_job.cancel()
$$;

CALL cancelJob();
The following code queries the test_tb table, but returns no results because no data has been inserted.

SELECT * FROM test_tb;
+----+
| C1 |
|----|
+----+
Example 3: Waiting and blocking while an asynchronous child job runs
In the following example, the blockUntilDone procedure executes an asynchronous child job that takes 5 seconds to finish. Using the snowflake.snowpark.AsyncJob.result method, the procedure waits and returns when the job has finished.

CREATE OR REPLACE PROCEDURE blockUntilDone()
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = 3.8
PACKAGES = ('snowflake-snowpark-python')
HANDLER='async_handler'
EXECUTE AS CALLER
AS $$
def async_handler(session):
    async_job = session.sql("select system$wait(5)").collect_nowait()
    return async_job.result()
$$;
The following code calls the blockUntilDone procedure, which returns after waiting 5 seconds.

CALL blockUntilDone();
+------------------------------------------+
| blockUntilDone                               |
|------------------------------------------|
| [Row(SYSTEM$WAIT(5)='waited 5 seconds')] |
+------------------------------------------+
Example 4: Returning an error after requesting results from an unfinished asynchronous child job
In the following example, the earlyReturn procedure executes an asynchronous child job that takes 60 seconds to finish. The procedure then attempts to return a DataFrame from the job’s result before it can have finished. The result is an error.

CREATE OR REPLACE PROCEDURE earlyReturn()
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = 3.8
PACKAGES = ('snowflake-snowpark-python')
HANDLER='async_handler'
EXECUTE AS CALLER
AS $$
def async_handler(session):
    async_job = session.sql("select system$wait(60)").collect_nowait()
    df = async_job.to_df()
    try:
        df.collect()
    except Exception as ex:
        return 'Error: (02000): Result for query <UUID> has expired'
$$;
The following code calls the earlyReturn procedure, returning the error.

CALL earlyReturn();
+------------------------------------------------------------+
| earlyReturn                                                 |
|------------------------------------------------------------|
| Error: (02000): Result for query <UUID> has expired        |
+------------------------------------------------------------+
Example 5: Finishing a parent job before a child job finishes, canceling the child job
In the following example, the earlyCancelJob procedure executes an asynchronous child job to insert data into a table and takes 10 seconds to finish. However, the parent job — async_handler — returns before the child job finishes, which cancels the child job.

CREATE OR REPLACE PROCEDURE earlyCancelJob()
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = 3.8
PACKAGES = ('snowflake-snowpark-python')
HANDLER='async_handler'
EXECUTE AS OWNER
AS $$
def async_handler(session):
    async_job = session.sql("insert into test_tb (select system$wait(10))").collect_nowait()
$$;
The following code calls the earlyCancelJob procedure. It then queries the test_tb table, which returns no result because no data was inserted by the canceled child job.

CALL earlyCancelJob();
SELECT * FROM test_tb;
+----+
| C1 |
|----|
+----+
"""

system_message_PLSQL = f"""
You are an expert in all forms of SQL, with a focus on converting SQL code between different dialects. Your primary task today is to convert the provided SQL code from Oracle to Snowflake while maintaining its functionality and logic.

Details:

Source Dialect: Oracle PL SQL (commonly used in legacy databases for procedures)
Target Dialect: Snowflake (commonly used in modern data warehouses)
Task: Convert the SQL code while preserving the original query's structure and logic. Adapt functions and keywords to suit the Snowflake dialect. Handle differences in data types or functions accurately.
Output Length: Provide a complete conversion of the given SQL code without unnecessary elaboration.

Steps:

Identify and adapt any Oracle-specific syntax and functions to their Snowflake equivalents.
Ensure that the converted code maintains the same logic and functionality.
Verify that all data types and functions are compatible with Snowflake.

Priority: Ensure the converted SQL code is robust and error-free for enterprise-level usage.

Instructions:
Follow the specified steps for conversion.
I have provided examples and documentation about scripting python in Snowflake can be found here: {Snowflake_documentation}. Use python 3.11. Don't use javascript use python for the language. Make sure to properly deal with the keyword "OUT" as it is an unsupported data type. 

"""

system_message_ET = f"""
You are an expert in all forms of SQL, with a focus on converting SQL code between different dialects. Your primary task today is to convert the provided SQL code from Oracle to Snowflake while maintaining its functionality and logic.

Details:

Source Dialect: Oracle Easytrieve (commonly used in legacy databases for report generation)
Target Dialect: Snowflake (commonly used in modern data warehouses)
Task: Convert the SQL code while preserving the original query's structure and logic. Adapt functions and keywords to suit the Snowflake dialect. Handle differences in data types or functions accurately.
Output Length: Provide a complete conversion of the given SQL code without unnecessary elaboration.

Steps:

Identify and adapt any Oracle-specific syntax and functions to their Snowflake equivalents.
Ensure that the converted code maintains the same logic and functionality.
Verify that all data types and functions are compatible with Snowflake.

Priority: Ensure the converted SQL code is robust and error-free for enterprise-level usage.

Instructions:
Follow the specified steps for conversion.
I have provided examples and documentation about scripting python in Snowflake can be found here: {Snowflake_documentation}. Use python 3.11. Don't use javascript use python for the language. Make sure to properly deal with the keyword "OUT" as it is an unsupported data type. 

"""

system_message_SQR = f"""
You are an expert in all forms of SQL, with a focus on converting SQL code between different dialects. Your primary task today is to convert the provided SQR code from Oracle to Snowflake while maintaining its functionality and logic.

Details:

Source Dialect: Oracle SQR (commonly used in legacy databases for report preperation)
Target Dialect: Snowflake (commonly used in modern data warehouses)
Task: Convert the SQL code while preserving the original query's structure and logic. Adapt functions and keywords to suit the Snowflake dialect. Handle differences in data types or functions accurately.
Output Length: Provide a complete conversion of the given SQL code without unnecessary elaboration.

Steps:

Identify and adapt any Oracle-specific syntax and functions to their Snowflake equivalents.
Ensure that the converted code maintains the same logic and functionality.
Verify that all data types and functions are compatible with Snowflake.

Priority: Ensure the converted SQL code is robust and error-free for enterprise-level usage.

Instructions:
Follow the specified steps for conversion.
I have provided examples and documentation about scripting python in Snowflake can be found here: {Snowflake_documentation}. Use python 3.11. Don't use javascript use python for the language. Make sure to properly deal with the keyword "OUT" as it is an unsupported data type. 

"""

#Update in the future to give 5 codes which we test elsehwere

def generate_prompt_PLSQL(code):
    prompt = f"""

        Below is the code I want you to convert from Oracle PL/SQL to Snowflake SQL. Provide me 5 variations of ONLY the converted code, ensuring it is compatible with Snowflake syntax. 
        There should be no text other than the code. Put '+++++' as a delimiter between the 5 versions so that I can seperate them.
       
        Here is the code:
        {code}
    """
    return prompt


def generate_prompt_ET(code):
    prompt = f"""

        Below is the code I want you to convert from Oracle EasyTrieve to Snowflake SQL. Provide me 5 variations of ONLY the converted code, ensuring it is compatible with Snowflake syntax. 
        There should be no text other than the code. Put '+++++' as a delimiter between the 5 versions so that I can seperate them.
       
        Here is the code:
        {code}
    """
    return prompt

def generate_prompt_SQR(code):
    prompt = f"""

        Below is the code I want you to convert from Oracle SQR to Snowflake SQL. Provide me 5 variations of ONLY the converted code, ensuring it is compatible with Snowflake syntax. 
        There should be no text other than the code. Put '+++++' as a delimiter between the 5 versions so that I can seperate them.
       
        Here is the code:
        {code}
    """
    return prompt

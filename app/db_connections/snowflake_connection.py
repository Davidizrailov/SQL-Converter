import snowflake.connector
import os
from dotenv import load_dotenv

load_dotenv()


#account details
account = os.getenv("ACCOUNT")
user = os.getenv("USERNAME")
password = os.getenv("PASSWORD")

database = "TEST_ENV"
schema = "PUBLIC"

#create con
conn = snowflake.connector.connect(
    user=user,
    password=password,
    account=account,

    database=database,
    schema=schema
)

#cursor
cursor = conn.cursor()

#test
cursor.execute("SELECT CURRENT_VERSION()")

#fetch
one_row = cursor.fetchone()
print(one_row)

#close
cursor.close()
conn.close()
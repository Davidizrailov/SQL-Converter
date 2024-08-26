
import cx_Oracle
import os

# (description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1522)(host=adb.ca-toronto-1.oraclecloud.com))(connect_data=(service_name=g4ca7f11b8779ff_testdatabase_high.adb.oraclecloud.com))(security=(ssl_server_dn_match=yes)))
# (description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1522)(host=adb.ca-toronto-1.oraclecloud.com))(connect_data=(service_name=g4ca7f11b8779ff_testdatabase_low.adb.oraclecloud.com))(security=(ssl_server_dn_match=yes)))
# (description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1522)(host=adb.ca-toronto-1.oraclecloud.com))(connect_data=(service_name=g4ca7f11b8779ff_testdatabase_medium.adb.oraclecloud.com))(security=(ssl_server_dn_match=yes)))


# Define the path to your Oracle Instant Client
oracle_client_path = r"C:\Users\NW538RY\OneDrive - EY\Desktop\instantclient\instantclient_23_4"

# Initialize the Oracle Client with the specified path
cx_Oracle.init_oracle_client(lib_dir=oracle_client_path)

# Set the TNS_ADMIN environment variable to point to the wallet directory
os.environ['TNS_ADMIN'] = r"C:\Users\NW538RY\OneDrive - EY\Desktop\Wallet_TESTDATABASE"

# Define the connection parameters
dsn = cx_Oracle.makedsn('adb.ca-toronto-1.oraclecloud.com', 1521, service_name='g4ca7f11b8779ff_testdatabase_high')

# Establish the connection
connection = cx_Oracle.connect(
    user='ADMIN',
    password='!EnKETnA2NXjD9y',
    dsn=dsn
)

# Create a cursor
cursor = connection.cursor()

# Execute PL/SQL code
plsql_code = """
BEGIN
    DBMS_OUTPUT.PUT_LINE('Hello, World!');
END;
"""

cursor.execute(plsql_code)

# Commit if needed (optional)
connection.commit()

# Fetch and print the output if applicable
cursor.execute("BEGIN DBMS_OUTPUT.GET_LINE(:1, :2); END;", ['output', 'status'])
print("Output:", cursor.getvalue(0))

# Close the cursor and connection
cursor.close()
connection.close()

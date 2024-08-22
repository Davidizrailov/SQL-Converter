import cx_Oracle

# Define the connection parameters
import cx_Oracle

oracle_client_path = r"C:\Users\NW538RY\OneDrive - EY\Desktop\instantclient\instantclient_23_4"

# Initialize the Oracle Client with the specified path
cx_Oracle.init_oracle_client(lib_dir=oracle_client_path)

# print(cx_Oracle.clientversion())

# Define the connection parameters
dsn = cx_Oracle.makedsn('adb.region.oraclecloud.com', 1521, service_name='mydb_high')

# Path to the wallet
wallet_location = r"C:\Users\NW538RY\OneDrive - EY\Desktop\Wallet_TESTDATABASE"

# Establish the connection
connection = cx_Oracle.connect(
    user='ADMIN', 
    password='!EnKETnA2NXjD9y',
    dsn=dsn,
    config_dir=wallet_location
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

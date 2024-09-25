import oracledb
import os

# If you are using 'thin' mode, you don't need the Oracle Client libraries
# oracledb.init_oracle_client(lib_dir=r"C:\path\to\your\instantclient_19_11")

# Set TNS_ADMIN to the directory containing the wallet files
os.environ['TNS_ADMIN'] = r"C:\Users\NW538RY\OneDrive - EY\Desktop\Wallet_TESTDATABASE"

# Define the connection parameters
dsn = (
"(description= (address=(protocol=tcps)(port=1522)(host=adb.ca-toronto-1.oraclecloud.com))(connect_data=(service_name=g4ca7f11b8779ff_testdatabase_medium.adb.oraclecloud.com))(security=(ssl_server_dn_match=yes)))"
)
# Establish the connection
try:
    connection = oracledb.connect(
        user='ADMIN',
        password='!EnKETnA2NXjD9y',
        dsn=dsn
    )
    print("Connection successful")

    # Create a cursor
    cursor = connection.cursor()

    # Execute a test query
    cursor.execute("SELECT 'Hello, World!' FROM dual")
    result = cursor.fetchone()
    print(result[0])

    # Close the cursor and connection
    cursor.close()
    connection.close()

except oracledb.DatabaseError as e:
    error, = e.args
    print("Error:", error.message)

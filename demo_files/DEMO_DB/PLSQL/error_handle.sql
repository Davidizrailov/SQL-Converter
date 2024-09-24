PL/SQL block to handle the exception when a division by zero occurs
DECLARE
dividend   NUMBER := 10;
divisor    NUMBER := 0;
result     NUMBER;
BEGIN
   BEGIN
result := dividend / divisor;
      DBMS_OUTPUT.PUT_LINE('Result: ' || result);
   EXCEPTION
      WHEN ZERO_DIVIDE THEN
         DBMS_OUTPUT.PUT_LINE('Error: Division by zero');
   END;
END;
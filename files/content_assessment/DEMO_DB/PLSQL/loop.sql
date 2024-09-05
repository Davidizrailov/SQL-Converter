DECLARE
  n NUMBER := 0;
BEGIN
  LOOP
    DBMS_OUTPUT.PUT_LINE ('The value of n inside the loop is:  ' || TO_CHAR(n));
    n := n + 1;
    IF n > 5 THEN
      EXIT;
    END IF;
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('The value of n outside the loop is: ' || TO_CHAR(n));
END;

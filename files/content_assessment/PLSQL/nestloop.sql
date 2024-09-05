DECLARE
  m  PLS_INTEGER := 0;
  n  PLS_INTEGER := 0;
  k  PLS_INTEGER;
BEGIN
  <>
  LOOP
    n := n + 1;
    k := 0;
DBMS_OUTPUT.PUT_LINE ('The values of inner loop are: ');	
    <>
    LOOP
      k := k + 1;
      m := m + n * k; -- Sum several products
  
      EXIT inner_loop WHEN (k > 3);
DBMS_OUTPUT.PUT_LINE ('n='||TO_CHAR(n)||'  k='||TO_CHAR(k)||'  m='||TO_CHAR(m));		  
      EXIT outer_loop WHEN ((n * k) > 6);
    END LOOP inner_loop;
  END LOOP outer_loop;
  DBMS_OUTPUT.PUT_LINE
    ('The total sum after completing the process is: ' || TO_CHAR(m));
END;
/
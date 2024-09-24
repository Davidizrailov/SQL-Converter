DECLARE
v_input_stringVARCHAR2(100);
v_trimmed_stringVARCHAR2(100);
BEGIN
v_input_string := '00000test string00000';

v_trimmed_string := TRIM('0' FROM v_input_string);
  DBMS_
code = """
! Sample SQR Program to generate an employee report

begin-program
  do main
end-program

begin-procedure main
  do InitializeReport

  begin-select
    emp_id
    emp_name
    emp_salary
    print emp_id () no-newline
    print emp_name () no-newline
    print emp_salary ()
    do ProcessRow
  from employees
  end-select

  do FinalizeReport
end-procedure

begin-procedure InitializeReport
  let $report_title = 'Employee Salary Report'
  print $report_title (1,1)
  print 'ID' (3,1)
  print 'Name' (3,10)
  print 'Salary' (3,30)
end-procedure

begin-procedure ProcessRow
  let #total_salary = #total_salary + &emp_salary
end-procedure

begin-procedure FinalizeReport
  print 'Total Salary: ' () new-page
  print #total_salary ()
end-procedure


"""
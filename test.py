import time
status = "in_progress"
i=0
while (status != 'complete') and (status != "failed") :
    i += 1
    time.sleep(1)
    print(status)
    if i==3: status = "failed" 
print(status)

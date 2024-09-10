from pathlib import Path
import os
import pandas as pd
import re
keywords = ['<IN>', '<CASE>', '<OUT>', '<START-PROCEDURES>', '<END-PROCEDURES>']
with open("et.txt", "r") as f:
  text = f.read()
  #print(text)
  #procedures_pattern = r"<START-PROCEDURES>(.*?)<END-PROCEDURES>"

  found = []
  for k in keywords:
    pattern = k + r"(.*?)" + k
    found.append(list(map(lambda x: x.strip(), re.findall(pattern, text, re.DOTALL))))

  
  ready_results = [False if result == "CASE-SPECIFIC" else True for result in found[2]]
  df = pd.DataFrame(
    {'input': found[0],
     'code': found[1],
     'result': found[2],
     'ready_result': ready_results
    })
  df.to_json("et.jsonl", orient="records", lines=True)
  #print(sum(1 for ready in ready_results if not ready))

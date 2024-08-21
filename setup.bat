ECHO OFF
python.exe -m ensurepip --upgrade
python.exe -m pip install --upgrade pip
python.exe -m pip install -r requirements.txt

:: [TODO] add lines for starting the translator

ECHO:
ECHO:
ECHO:
ECHO:
ECHO INSTALLATION COMPLETED. THE TRANSLATOR CAN BE RUN NOW.
ECHO TO RUN THE TRANSLATOR TYPE IN THE FOLLOWING COMMAND BELOW:
ECHO [[[write python command here]]]
ECHO: & PAUSE
cmd /k
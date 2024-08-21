#!/bin/bash
python -m ensurepip --upgrade
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
printf "\n\n\n\n"
printf "INSTALLATION COMPLETED. THE TRANSLATOR CAN BE RUN NOW.\n"
printf "TO RUN THE TRANSLATOR TYPE IN THE FOLLOWING COMMAND BELOW:\n"
printf "[[[write python command here]]]\n\n"
read -p "Press enter to continue..."
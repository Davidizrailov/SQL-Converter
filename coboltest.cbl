       IDENTIFICATION DIVISION.
       PROGRAM-ID. LegacyTest.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-NUMBER1          PIC 9(5) VALUE 0.
       01 WS-NUMBER2          PIC 9(5) VALUE 0.
       01 WS-RESULT           PIC 9(5).
       01 WS-CHOICE           PIC X VALUE ' '.
       01 WS-CONTINUE         PIC X VALUE 'Y'.

       PROCEDURE DIVISION.
       MAIN-PARA.
           PERFORM UNTIL WS-CONTINUE NOT = 'Y'
               DISPLAY "ENTER FIRST NUMBER: " WITH NO ADVANCING
               ACCEPT WS-NUMBER1

               DISPLAY "ENTER SECOND NUMBER: " WITH NO ADVANCING
               ACCEPT WS-NUMBER2

               DISPLAY "CHOOSE OPERATION: A-ADD S-SUBTRACT M-MULTIPLY D-DIVIDE"
               ACCEPT WS-CHOICE

               IF WS-CHOICE = 'A'
                   COMPUTE WS-RESULT = WS-NUMBER1 + WS-NUMBER2
                   DISPLAY "RESULT: " WS-RESULT
               ELSE IF WS-CHOICE = 'S'
                   COMPUTE WS-RESULT = WS-NUMBER1 - WS-NUMBER2
                   DISPLAY "RESULT: " WS-RESULT
               ELSE IF WS-CHOICE = 'M'
                   COMPUTE WS-RESULT = WS-NUMBER1 * WS-NUMBER2
                   DISPLAY "RESULT: " WS-RESULT
               ELSE IF WS-CHOICE = 'D'
                   IF WS-NUMBER2 = 0
                       DISPLAY "DIVISION BY ZERO IS NOT ALLOWED"
                   ELSE
                       COMPUTE WS-RESULT = WS-NUMBER1 / WS-NUMBER2
                       DISPLAY "RESULT: " WS-RESULT
                   END-IF
               ELSE
                   DISPLAY "INVALID CHOICE."
               END-IF

               DISPLAY "DO YOU WANT TO CONTINUE? (Y/N): " WITH NO ADVANCING
               ACCEPT WS-CONTINUE
           END-PERFORM.

           STOP RUN.

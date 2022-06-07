*PROCEDURE ErrHand
* Error displaying routine
* Place the following line in program to detect error.
*ON ERROR Do ErrHand WITH LINENO(),PROGRAM(),ERROR(),MESSAGE()
PARAMETERS xxline, xprog, xerr, xmes
DEFINE WINDOW ShowErr FROM 10,10 TO 19,60 ;
  TITLE "Program ERROR:"

ACTIVATE WINDOW ShowErr

@ 02,01 SAY "   Line: " + LTRIM(STR(xxline))
@ 03,01 SAY "Program: " + xprog
@ 04,01 SAY "  Error: " + LTRIM(STR(xerr))
@ 05,01 SAY "Message: " + xmes


wait window 'Press Any Key to continue'
wait window 'Press Any Key to continue'
RELEASE WINDOW ShowErr
cancel

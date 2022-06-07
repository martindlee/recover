**********************************************
* MessageBox simulator for FPD *
**********************************************
* We use rMsgBox code for compatibility with different FoxPro platforms.
* PROCEDURE rMsgBox
PARAMETERS msg, b_type, windowtitle
*
*  Returns (if pressed button):
*	OK	1
*	CANCEL	2
*	ABORT	3
*	RETRY	4
*	IGNORE	5
*	YES	6
*	NO	7
*
*  Description:
*	<exp1C>	Contents of dialog box
*	<exp2C>	Title of dialog box window
*	<expN>	Type of dialog box as follows:
*
*	Buttons OK			0
*	Buttons OK CANCEL		1
*	Buttons ABORT RETRY IGNORE	2
*	Buttons YES NO CANCEL		3
*	Buttons YES NO			4
*	Buttons RETRY CANCEL		5
*
windowtitle = ' '+windowtitle+' '
PRIVATE msg, m.button, m.icon, RetVal, Deflt
RetVal=0
Deflt = IIF(b_type=0,1,2)
m.button=''
fontname=IIF(_WINDOWS,"MS Sans Serif","Geneva")
PUSH KEY CLEAR
ON KEY LABEL ESCAPE
DEFINE WINDOW xMsgBox AT  0 , 0  SIZE 8, 60 ;
  TITLE " "+windowtitle+" " FLOAT NOCLOSE NOMINIMIZE DOUBLE COLOR W+/RB
MOVE WINDOW xMsgBox CENTER

IF WVISIBLE("xMsgBox")
  ACTIVATE WINDOW xMsgBox SAME
ELSE
  ACTIVATE WINDOW xMsgBox NOSHOW
ENDIF
DO CASE

CASE b_type=0
  @ 7, 27 GET m.button PICTURE "@*HT \!Ok";
    SIZE 1, 6, 1 DEFAULT 1

CASE b_type=1
  @ 7, 24 GET m.button PICTURE "@*HT \<Ok;\<Cancel" ;
    SIZE 1, 6, 1 DEFAULT 1 ;

CASE b_type=2
  @ 7, 17  GET m.button PICTURE "@*HT \<Abort;\<Retry;\<Ignore" ;
    SIZE 1, 6, 1 DEFAULT 1

CASE b_type=3
  @ 7, 19  GET m.button PICTURE "@*HT \<Yes;\<No;\<Cancel" ;
    SIZE 1, 6, 1 DEFAULT 1

CASE b_type=4
  @ 7, 23  GET m.button PICTURE "@*HT \<Yes; \!\<No" ;
    SIZE 1, 6, 1 DEFAULT 1

CASE b_type=5
  @ 7, 22  GET m.button PICTURE "@*HT \<Retry;\<Cancel" ;
    SIZE 1, 6, 1 DEFAULT 1

ENDCASE

@ 0, 3 SAY msg SIZE 7 ,56

IF NOT WVISIBLE("xMsgBox")
  ACTIVATE WINDOW xMsgBox
ENDIF

READ CYCLE MODAL;
  ACTIVATE CheckBoxA(Deflt)

DO CASE
CASE LEFT(m.button,1)='O'
  RetVal=1
CASE LEFT(m.button,1)='C'
  RetVal=2
CASE LEFT(m.button,1)='A'
  RetVal=3
CASE LEFT(m.button,1)='R'
  RetVal=4
CASE LEFT(m.button,1)='I'
  RetVal=5
CASE LEFT(m.button,1)='Y'
  RetVal=6
CASE LEFT(m.button,1)='N'
  RetVal=7
ENDCASE

RELEASE WINDOW xMsgBox
POP KEY
RETURN RetVal

PROCEDURE CheckBoxA
* sets the default button
PARAMETER Cval
_CUROBJ = Cval

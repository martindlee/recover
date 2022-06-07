**************************************
* FPW, VFP MessageBox simulator *
**************************************
* We use this rMsgBox code for compatibility with different versions of FoxPro.
* It reduces writing extra RECOVER code for different versions.
* It also responds to keyboard command whereas foxtools.fll one doesn't

PARAMETERS xmsg, b_type, windowtitle
*
*  Returns:
*	OK		1
*	CANCEL	2
*	ABORT	3
*	RETRY	4
*	IGNORE	5
*	YES		6
*	NO		7
*
*  Description:
*	<xmsg>	Contents of dialog box
*	<windowtitle>	Title of dialog box window
*	<b_type>	Type of dialog box as follows:
*
*	Buttons OK					0
*	Buttons OK CANCEL			1
*	Buttons ABORT RETRY IGNORE	2
*	Buttons YES NO CANCEL		3
*	Buttons YES NO				4
*	Buttons RETRY CANCEL		5
*
PRIVATE m.button, m.icon, RetVal, Deflt, FontName
RetVal=0
Deflt = IIF(b_type=0,1,2)
m.button=''
IF USED("RecovMsg")
  GO TOP in RecovMsg
  FontName= ALLT(RecovMsg.msg)
ELSE
  FontName=IIF(_WINDOWS,"MS Sans Serif","Geneva")
ENDIF
PUSH KEY CLEAR
ON KEY LABEL ESCAPE
DEFINE WINDOW xMsgBox AT  0.000, 0.000 SIZE 9.231,63.600 ;
  TITLE windowtitle FONT FontName, 9 ;
  FLOAT NOCLOSE NOMINIMIZE DOUBLE COLOR RGB(,,,192,192,192)
MOVE WINDOW xMsgBox CENTER

IF WVISIBLE("xMsgBox")
  ACTIVATE WINDOW xMsgBox SAME
ELSE
  ACTIVATE WINDOW xMsgBox NOSHOW
ENDIF

DO CASE
CASE b_type=0
  RetVal=1
  @ 7.0,24.800 GET m.button PICTURE "@*HT \!Ok" ;
    SIZE 1.769,11.500,1.667 DEFAULT 1 ;
    FONT FontName, 9 STYLE "B"
CASE b_type=1
  RetVal=2
  @ 7.0,17.000 GET m.button PICTURE "@*HT \<Ok;\<Cancel" ;
    SIZE 1.769,11.500,1.667 DEFAULT 1 ;
    FONT FontName, 9 STYLE "B"
CASE b_type=2
  RetVal=3
  @ 7.0,9.000 GET m.button PICTURE "@*HT \<Abort;\<Retry;\<Ignore" ;
    SIZE 1.769,11.500,1.667 DEFAULT 1 ;
    FONT FontName, 9 STYLE "B"
CASE b_type=3
  RetVal=2
  @ 7.0,9.000 GET m.button PICTURE "@*HT \<Yes;\<No;\<Cancel" ;
    SIZE 1.769,11.500,1.667 DEFAULT 1 ;
    FONT FontName, 9 STYLE "B"
CASE b_type=4
  RetVal=7
  @ 7.0,17.000 GET m.button PICTURE "@*HT \<Yes; \!\<No" ;
    SIZE 1.769,11.500,1.667 DEFAULT 1 ;
    FONT FontName, 9 STYLE "B"
CASE b_type=5
  RetVal=2
  @ 7.0,17.000 GET m.button PICTURE "@*HT \<Retry;\<Cancel" ;
    SIZE 1.769,11.500,1.667 DEFAULT 1 ;
    FONT FontName, 9 STYLE "B"
ENDCASE

@ 0.500,3.800 SAY xmsg SIZE 6.000,47.00 FONT FontName, 9 ;
  STYLE "B"
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

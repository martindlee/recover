**************************************
* FPW, FoxTools/MessageBox simulator for VFP *
**************************************
* We use rMsgBox for compatibility with different versions of FoxPro.
* PROCEDURE rMsgBox
PARAMETERS String1, MsgTitle, Parm
RETURN MessageBox(String1, Parm+256, MsgTitle)

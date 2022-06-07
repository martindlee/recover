y = (x <= z)

return

? MessageBox("Pack " + "SomeFile.DBF", 4, "Notice!") = 7

*----------
Procedure MessageBox
* This will be ignored by VFP
Parameters Msg, Msgtype, MsgTitle
Private MacroStr
MacroStr = "rMsgBox(Msg, MsgType, MsgTitle)"
Return &MacroStr
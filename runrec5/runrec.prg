_SCREEN.WindowState = 2
_SCREEN.caption = "Recover - VFP StandAlone"
_SCREEN.Closable = .F.
SET SYSMENU TO _MSM_EDIT
IF !FILE('recovers.app')
  MESSAGEBOX("Please select directory of RecoverS.app file!",0,"Notice.")
  SET default to getdir()
ENDIF
IF FILE('recovers.app')
  DO recovers.app
ENDIF


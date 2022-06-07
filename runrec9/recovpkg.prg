_SCREEN.WINDOWSTATE = 2 && 2 = maximized, 1 = minimized, 0 = normal
_SCREEN.CAPTION = "Recover File Error Scan and Repair"
_SCREEN.CLOSABLE = .F.
SET SYSMENU OFF
SET CPDIALOG OFF
USE RecovLst SHARED
SCAN FOR !DELETED() AND DoThisOne
  _SCREEN.CAPTION = "Recover - scanning file: " + ALLT(TABLEPATH)
  REPLACE RecovLst.RecResult;
    WITH RECOVER(ALLT(TABLEPATH), ALLT(MEMOFILE), ALLT(RECOPTS)),;
    RecovLst.Finished WITH .T.,;
    DateDone with Date(),;
    TimeDone with Time()
ENDSCAN
QUIT


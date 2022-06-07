*RecovPkg for FPD2.6
SET TALK OFF
* MODI WINDOW SCREEN TITLE "Recover 2.0 File Error Scan and Repair"
SET SYSMENU OFF
*SET CPDIALOG OFF
USE RecovLst SHARED
SCAN FOR !DELETED() AND DoThisOne
*  MODI WINDOW SCREEN TITLE "Recover 2.0 - scanning file: " + ALLT(TABLEPATH)
  REPLACE RecovLst.RecResult;
    WITH RECOVER(ALLT(TABLEPATH), ALLT(MEMOFILE), ALLT(RECOPTS)),;
    RecovLst.Finished WITH .T.,;
    DateDone with Date(),;
    TimeDone with Time()
ENDSCAN
QUIT


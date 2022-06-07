* moverecs
PARAMETERS StartRec, LastRec, MvStep, MvDir
*move records startrec to LastRec by MvDir*MvStep records
IF PARAMETERS() < 4
  ?? chr(7)
  WAIT WINDOW "USAGE: =MoveRecs(StartRec, LastRec, MvStep, MvDir)" + CHR(13) + CHR(13) + "Press any key/mouse to continue..."
  return
ENDIF
MvDir = SIGN(MvDir)
IF LastRec + MvDir*MvStep > RECCOUNT()
  FOR i = 1 TO LastRec+MvDir*MvStep - RECCOUNT()
    APPEND BLANK
  ENDFOR
ENDIF
a = IIF(MvDir>0, LastRec, StartRec)
b = IIF(MvDir>0, StartRec, LastRec)
FOR i= a TO b STEP -MvDir
  GO i
  SCATTER MEMVAR
  SKIP MvDir*MvStep
  GATHER MEMVAR

  GO i
  SCATTER MEMVAR MEMO BLANK
  GATHER MEMVAR
ENDFOR

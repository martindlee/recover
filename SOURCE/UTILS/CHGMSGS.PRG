* ChgMsgs routine: changes "GM( X," to "GM(nn," or back again
* used on files: RECOVER.PRG, MSALVAGE.PRG, MEMOSCAN.PRG and RECVAL.PRG:
* works with 2 digit nn numbers - can change to 3 digits if
* "GM( X," changed to "GM(  X,"
PARAMETER filename, MsgReset
* MsgReset = .T. if to reset all "GM(xx," to "GM( X,"
IF PARAMETERS() = 0 OR !FILE(filename)
  ?? CHR(7)
  RETURN
ENDIF
FileHandle = FOPEN(FileName, 2)
FileLen = FSEEK(FileHandle, 0, 2)
IF MsgReset
  TempS = "GM("
  TempNo = SrchFile(FileHandle,0, FileLen-1, TempS)
  DO WHILE TempNo > 0
    =FWRITE(FileHandle, "GM( X")
    TempNo = SrchFile(FileHandle, TempNo + 5, FileLen-1, TempS)
  ENDDO
ELSE
  USE recovmsg
  SCAN FOR !EMPTY(recovmsg.msg)
    TempS = "GM( X, "+CHR(34)+ALLT(Recovmsg.msg)
    TempNo = SrchFile(FileHandle,0, FileLen-1, TempS)
    DO WHILE TempNo > 0
      =FWRITE(FileHandle, "GM(" + STR(RECNO("Recovmsg"), 2,0) + ", "+ CHR(34) + ALLT(Recovmsg.msg))
      TempNo = SrchFile(FileHandle, TempNo + 5, FileLen-1, TempS)
    ENDDO
  ENDSCAN
  USE IN recovmsg
ENDIF
=FCLOSE(filehandle)

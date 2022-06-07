* check table and version compatibility and give message to user - he still may be able to repair but not Scan/View, etc.
PARAMETER DBFfile
PRIVATE ALL
DBFleft = UPPER(IIF(RAT('.', DBFfile)>0, LEFT(DBFfile, RAT('.', DBFfile)-1), DBFfile))
DefFile = DBFleft + '.DEF'
IF "VISUAL" $ VERSION()
  VersNo = VAL(SUBSTR(VERSION(), 15, 4))
ELSE
  VersNo = 2
ENDIF
IF FILE(DefFile) && use deffile
  ON ERROR *
  USE (DefFile) ALIAS DefFile
  ON ERROR
  IF USED("DefFile")
    GO BOTTOM
    nCompVers = 2
    DO CASE
    CASE LEFT(Field_Name, 4) == 'VF30'
      nCompVers = 5
    CASE LEFT(Field_Name, 4) == 'VF31'
      nCompVers = 8
    CASE LEFT(Field_Name, 4) == 'VF32'
      nCompVers = 9
    ENDCASE
    USE IN DefFile
    IF (VersNo < nCompVers)
      =MESSAGEBOX("The selected .DBF file, a Visual FoxPro" + ALLT(STR(nCompVers)) + "+ table type,";
        + " is incompatible with older FoxPro version you are now using.", 0, "Notice!")
    ENDIF
  ENDIF
ELSE && check file header marker
  FileHandle = FOPEN(DBFfile)
  IF FileHandle > -1
    cByteRead = FREAD(FileHandle, 1)
    =FCLOSE(FileHandle)
    nCompVers = 2
    DO CASE
    CASE cByteRead == CHR(48)
      nCompVers = 5
    CASE cByteRead == CHR(49)
      nCompVers = 8
    CASE cByteRead == CHR(50)
      nCompVers = 9
    ENDCASE
    IF (VersNo < nCompVers)
      =MESSAGEBOX("The selected .DBF file, appears to be a Visual FoxPro" + ALLT(STR(nCompVers)) + " table type,";
        + " is incompatible with older FoxPro you are now using.", 0, "Notice!")
    ENDIF
  ENDIF
ENDIF

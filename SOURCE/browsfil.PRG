PARAMETER FileName, ScanLevel, Demo
* 07/28/03 revision
* 01/04/06 revision with Demo param

* For browsing tables - opens/closes table

* along with recval.prg
* The BrowsFil.app is not built everytime - needs to be hand built if 'browsfil.prg' or 'recval.prg' change.
SET TALK OFF
SET CPDIALOG OFF
IF PARAMETERS() < 2
  =MESSAGEBOX("Missing parameter(s)", 0, "BrowsFile usage error:")
  RETURN
ENDIF
PRIVATE ALL
FileName = FULLPATH(FileName)
DBFleft = UPPER(IIF(RAT('.',FileName)>0, LEFT(FileName, RAT('.',FileName)-1), FileName))
IF FILE(FileName)
  PRIVATE ErrorMsg, BrowWin
  ErrorMsg = ''
  ON ERROR ErrorMsg = MESSAGE()
  SELECT 0
  USE (FileName) && ALIAS DBFfile - changed 2007/12/25. Generates error if .cdx has (DBFleft).something
  IF !EMPTY(ErrorMsg)
    ON ERROR
    RETURN MESSAGEBOX("Error opening file: "+ FileName + CHR(13)+CHR(10)+"** "+ErrorMsg+" **", 0, "Notice:")
  ENDIF
  ErrMsg = ""
  cAlias = Alias()
  SET ESCAPE OFF
  PUSH KEY
  ON KEY LABEL CTRL+E USE IN (cAlias)
  ON KEY LABEL CTRL+HOME GO TOP
  ON KEY LABEL CTRL+END GO BOTTOM
  ON KEY LABEL CTRL+P DO PackFile
  IF Demo
    ON KEY LABEL CTRL+N WAIT WINDOW "Feature not available with Demo." + CHR(13) + " Click Mouse or any key to continue..."
    ON KEY LABEL CTRL+B WAIT WINDOW "Feature not available with Demo." + CHR(13) + " Click Mouse or any key to continue..."
    ON KEY LABEL CTRL+R WAIT WINDOW "Feature not available with Demo." + CHR(13) + " Click Mouse or any key to continue..."
  ELSE
    ON KEY LABEL CTRL+N APPEND BLANK
    ON KEY LABEL CTRL+B DO BadRecord WITH ScanLevel
    ON KEY LABEL CTRL+R DO ReindexFile WITH DBFleft
  ENDIF

  * Field property variables for RecVal
  PRIVATE PrevWidth, NullCount, NullFlagCeil, VFP, RecNum, FirstRecPos, RecordLen, RTraceFlag
  DIMENSION FldProp[1, 5]
  FldProp = .F.
  FldProp[1,3] = 0 && use as flag for no values yet.
  PrevWidth = 2
  NullCount = 0
  NullFlagCeil = 1
  VFP = .F.
  RecNum = 1
  FirstRecPos = 0
  RecordLen = 0
  RTraceFlag =.F.

  * browse the file if possible
  DO WHILE USED(cAlias)
    =BrowseTheFile(RecNum)
  ENDDO
  POP KEY
  IF USED("RecoverDef")
    USE IN RecoverDef
  ENDIF
  USE
ELSE
  ?? CHR(7)
ENDIF
SET ESCAPE ON
RETURN

*-----
PROCEDURE BrowseTheFile
PARAMETER RecNumber
IF RECCOUNT() > 0 AND RecNumber <= RECCOUNT()
  GO RecNumber
ENDIF
IF ATC("Windows",VERSION())=0 AND ATC("Visual",VERSION())=0 && DOS
  DEFINE WINDOW _brow11;
    AT  1.000,0.000 SIZE 23.000, 80.000 ;
    FLOAT GROW NOMINIMIZE ZOOM
ELSE && FoxWin or VFP
  DEFINE WINDOW _brow11;
    AT  1.000,1.000 SIZE 35.000, 120.000 ;
    FONT 'MS Sans Serif', 8 STYLE 'N' FLOAT GROW NOMINIMIZE ZOOM
ENDIF
MOVE WINDOW _brow11 CENTER
*  SYS(2014,FileName) + ': .... minimum path name
BrowWin = 'Ctrl+E exits, Ctrl+B find bad rec, Ctrl+N append blank, Ctrl+P Pack, Ctrl+R Reindex'
BROWSE;
  TITLE BrowWin ;
  FONT 'MS Sans Serif', 8 STYLE 'N' WINDOW _brow11
RELEASE WINDOW _brow11
*use && xxx
RETURN

*----------------------
PROCEDURE BadRecord
* Finds record with bad or suspicious field
PARAMETER ScanLevel
IF RECCOUNT(cAlias) = 0
  =MESSAGEBOX("This file has no records.", 0, "Notice!")
  RETURN
ENDIF
PRIVATE ShowProgrM, MsgFont, DelChar
ShowProgrM = .T.
MsgFont = IIF(_WINDOWS,"MS Sans Serif", "Geneva")
DelChar     = '* ' && IIF(Alpha5, '*- ', '* ')
RecNum = RECNO(cAlias) && the user may have changed the record pointer
IF FldProp[1,3] = 0 && FldProp not defined yet
  IF !FILE(DBFleft + ".DEF")
    =MESSAGEBOX("Correct .DEF file required for error scan.", 0, "Missing .DEF file!")
    RETURN
  ENDIF

  SELECT 0
  USE (DBFleft + ".DEF") ALIAS RecoverDef
  SELECT RecoverDef
  GO BOTTOM
  VFP = LEFT(Field_name, 2) = 'VF'
  DIMENSION FldProp[RECCOUNT()-1, 5]
  *=== Recover.prg potential code copy change
  PrevWidth = 2
  NullCount = 0
  SCAN FOR RECNO()<RECCOUNT()
    FldProp[Recno(), 2] = LEFT(RecoverDef.TYPE, 1) && Field Type
    IF VFP AND FldProp[Recno(), 2] == 'C' AND Bit(2, VAL(SUBSTR(RecoverDef.TYPE, 4, 1)))
      FldProp[Recno(), 2] = 'Cb' && binary character type
    ENDIF
    IF FldProp[Recno(), 2] == 'C' AND ATC('TEXT', RecoverDef.Dec)>0 && overides the previous IF
      FldProp[Recno(), 2] = 'Ct' && text type
    ENDIF
    IF Bit(1, VAL(SUBSTR(RecoverDef.TYPE, 4, 1))) OR FldProp[Recno(), 2] $ 'QV'
      NullCount = NullCount+1
    ENDIF
    FldProp[Recno(), 1] = RecoverDef.Field_name
    FldProp[Recno(), 3] = VAL(RecoverDef.WIDTH) && Field Width
    FldProp[Recno(), 5] = PrevWidth && Position in record - 1st byte is No. 1
    FldProp[Recno(), 4] = VAL(RecoverDef.Dec) && decimal width
    PrevWidth = PrevWidth + FldProp[Recno(), 3]
  ENDSCAN
  NullFlagCeil = IIF(NullCount>0, 2^NullCount, 1) && 2^(count of null field types in .def)
  *=== Recover.prg part code change end
  SELECT 0 && keeps RecoverDef
ENDIF

USE IN (cAlias)
PRIVATE PrevSec, TempS2, TempS, DBFhandle
DBFhandle = FOPEN(FileName)
FirstRecPos = GetValue(DBFhandle, 8, 2, 1)
RecordLen   = GetValue(DBFhandle, 10, 2,1)
* scan through records

PrevSec = SECONDS()

=WaitWin("Checking record - "+STR(RecNum+1))
=FSEEK(DBFhandle, FirstRecPos + (RecNum - 1)*RecordLen)
DO WHILE !FEOF(DBFhandle)
  TempS2=FREAD(DBFhandle, RecordLen)
  TempS = ''
  IF LEN(TempS2) == RecordLen
    TempS = RecVal(TempS2, .T., ScanLevel, .F.)
  ENDIF
  IF SECONDS() > PrevSec+2.0
    =WaitWin("Checking record - "+ALLT(STR(RecNum)))
    PrevSec = SECONDS()
  ENDIF
  IF LEN(TempS2)==RecordLen && !FEOF
    IF LEN(TempS)>0 && scan good records until bad found
      * warning or error record found
      FilePos = FSEEK(DBFhandle, 0 , 1) - RecordLen
      =WaitWin()
      =MESSAGEBOX("Record: " + ALLT(STR(RecNum)) + " " + TempS, 0, "Notice:")
      EXIT
    ENDIF
  ENDIF
  IF FEOF(DBFhandle) && EOF - display Last Record & 'No Errors found' message
    FilePos = FSEEK(DBFhandle, 0 , 1) - RecordLen - LEN(TempS2)
    =WaitWin()
    =MESSAGEBOX('End of file reached!', 0, "Notice:")
    EXIT
  ENDIF
  RecNum = RecNum + 1
ENDDO
=FCLOSE(DBFhandle)
SELECT 0
USE (FileName) ALIAS (cAlias)
RecNum = IIF(RecNum > RECCOUNT(), RECCOUNT(), RecNum)
IF RECCOUNT() > 0
  GO RecNum
ENDIF

PROCEDURE CheckRecV && for checking individual record
PRIVATE TempS
TempS = RecVal(recstr,.T., Senslvl, .F.)
IF LEN(TempS)>0
  =MESSAGEBOX(TempS, 0, "Notice:")
ELSE
  =MESSAGEBOX('Record appears OK!', 0, "Notice:")
ENDIF
RETURN

*----------------------
PROCEDURE PackFile
* Packs the file
IF RECCOUNT(cAlias) = 0
  =MESSAGEBOX("This file has no records.", 0,"Notice!")
  RETURN
ENDIF
IF MESSAGEBOX("Pack " + FileName, 4, "Notice!") = 7
  RETURN
ENDIF
PRIVATE ShowProgrM, MsgFont
ShowProgrM = .T.
MsgFont = IIF(_WINDOWS,"MS Sans Serif", "Geneva")
=WaitWin("Packing file. Please wait...")
PACK
=WaitWin()
RETURN

*----------------------
PROCEDURE ReindexFile
* reindex the file
PARAMETER DBFleft
IF RECCOUNT(cAlias) = 0
  =MESSAGEBOX("This file has no records.", 0,"Notice!")
  RETURN
ENDIF
IF !FILE(DBFleft + '.CDX')
  =MESSAGEBOX("This file has no .CDX index type.", 0, "Notice!")
  RETURN
ENDIF
IF MESSAGEBOX("Reindex " + FileName, 4, "Notice!") = 7
  RETURN
ENDIF
PRIVATE ShowProgrM, MsgFont
ShowProgrM = .T.
MsgFont = IIF(_WINDOWS,"MS Sans Serif", "Geneva")
=WaitWin("Packing file. Please wait...")
SET TALK ON
REINDEX
SET TALK OFF
=WaitWin()
RETURN

*---------------
PROCEDURE MESSAGEBOX
* This will be ignored by VFP
PARAMETERS Msg, Msgtype, MsgTitle
PRIVATE MacroStr
MacroStr = "rMsgBox(Msg, MsgType, MsgTitle)"
RETURN &MacroStr

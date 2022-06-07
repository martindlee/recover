* Autoincrement dialog routine for checking/correcting autoinc NextVal's & StepVal's
PARAMETERS DBFfile
PRIVATE ALL
Params = PARAMETERS()
* initial error checks
IF Params < 1
  MESSAGEBOX("Missing DBF name parameter!", 0, "Recover Autoinc Editor.")
  RETURN .F.
ENDIF

DBFfile = UPPER(DBFfile)
IF Params < 1 OR !(".DBF" $ DBFfile)
  MESSAGEBOX("Invalid .DBF file spec: " + DBFfile, 0, "Recover Autoinc Editor.")
  RETURN .F.
ENDIF
DBFleft = UPPER(IIF(RAT('.',DBFfile)>0, LEFT(DBFfile, RAT('.',DBFfile)-1), DBFfile))
DefFile = DBFleft + '.DEF'
IF !FILE(DefFile)
  MESSAGEBOX("Missing " + DefFile + " - cannot continue with Autoinc checking.", 0, "Recover Autoinc Editor.")
  RETURN .F.
ENDIF

ON ERROR *
USE (DefFile) ALIAS DefFile && check if there is an auto inc field
ON ERROR
IF USED("DefFile")
  LOCATE FOR RECNO() < RECCOUNT() AND SUBSTR(DefFile.TYPE, 5, 1) == 'a'
  IF !FOUND()
    USE IN DefFile
    MESSAGEBOX(DBFfile + " not a VFP autoincrement file type.", 0, "Recover Autoinc Editor.")
    RETURN .F.
  ENDIF
ENDIF


Errno = 0
ON ERROR Errno = ERROR()
USE (DBFfile) ALIAS DataFile
ON ERROR
IF Errno != 0
  MESSAGEBOX(DBFfile + " missing or corrupt. Restore file before checking autoincrement fields.", 0, "Recover Autoinc Editor.")
  RETURN .F.
ENDIF
RecCnt = RECCOUNT("DataFile")

* store autoinc variable info into a cursor
CREATE CURSOR AutoIncrm (DefRec N(3), FieldName C (30), NEXTVAL N(11), StepVal N(3), Warnings C(40), ArchiveNext N(11), ArchiveStep N(3), FileAI L, DefAI L)
INDEX ON DefRec TAG DefRec
SELECT 0
USE (DefFile) ALIAS RecoverDef
SELECT DataFile
FieldCount = FCOUNT("DataFile")
FOR i = 1 TO FieldCount
  INSERT INTO AutoIncrm (DefRec, FieldName) VALUES (i, FIELD(i, "DataFile"))
ENDFOR
*append blank
USE IN DataFile
* get autoinc file info from file
IF !GetAutoIncValues(DBFfile, .F.) && fieldnames missmatch
  USE IN AutoIncrm
  USE IN RecoverDef
  MESSAGEBOX(DBFfile + " file header does not match .DEF file field names." + CHR(13) +;
    "Update .DEF file or fileRepair DBF first.", 0, "Recover Autoinc Editor.")
  RETURN .F.
ENDIF

DO FORM AutoIncrm WITH DBFfile, RecCnt
USE IN AutoIncrm
USE IN RecoverDef

*-------------------------
PROCEDURE GetAutoIncValues
PARAMETER DBFfile, AIRefresh
PRIVATE ALL
DBFHandle = FOPEN(DBFfile)
RecordLen   = GetValue(DBFHandle, 10, 2, 1)
SELECT AutoIncrm
SET FILTER TO
IF AIRefresh && not the first time - empty all records
  SCATTER MEMVAR MEMO BLANK
  SCAN
    GATHER MEMVAR MEMO FIELDS EXCEPT DefRec, FieldName
  ENDSCAN
ENDIF

* get field info from file
SCAN FOR GetString(DBFHandle, RECNO()*32 + 11, 1) = 'I'
  IF GetValue(DBFHandle, RECNO()*32 + 18, 1, 1) = 12
    REPLACE AutoIncrm.FileAI WITH .T.,;
      AutoIncrm.NEXTVAL WITH GetSValue(DBFHandle, RECNO()*32 + 19, 4, 1),;
      AutoIncrm.StepVal WITH ASC(GetString(DBFHandle, RECNO()*32 + 23, 1))
  ELSE && just an integer
    REPLACE AutoIncrm.FileAI WITH .T.,;
      AutoIncrm.NEXTVAL WITH 0, AutoIncrm.StepVal WITH 0
  ENDIF
ENDSCAN

* SCAN FOR GetValue(DBFHandle, RECNO()*32 + 18, 1, 1) = 12;
*     AND GetString(DBFHandle, RECNO()*32 + 11, 1) = 'I'
*   REPLACE AutoIncrm.FileAI WITH .T.,;
*     AutoIncrm.NEXTVAL WITH GetSValue(DBFHandle, RECNO()*32 + 19, 4, 1),;
*     AutoIncrm.StepVal WITH ASC(GetString(DBFHandle, RECNO()*32 + 23, 1))
* ENDSCAN

=FCLOSE(DBFHandle)

* Check for field count consistency
SELECT RecoverDef
LOCATE FOR "_NULLFLAGS" $ UPPER(RecoverDef.Field_Name)
DefFCount = RECCOUNT() - IIF(FOUND(), 2, 1)
IF RECCOUNT('AutoIncrm') != DefFCount
  RETURN .F. && field names missmatch
ENDIF

SET RELATION TO RECNO("RecoverDef") INTO AutoIncrm
SCAN
  IF RECNO("RecoverDef") < RECCOUNT("RecoverDef");
      AND !"_NULLFLAGS" $ UPPER(RecoverDef.Field_Name);
      AND UPPER(LEFT(AutoIncrm.FieldName, 8)) != UPPER(LEFT(Field_Name, 8))
    RETURN .F. && field names missmatch
  ENDIF
  IF SUBSTR(RecoverDef.TYPE, 5, 1) = 'a'
    sOldNextVal = SUBSTR(RecoverDef.TYPE, 6, 4) && archived next value string
    nOldNextVal = SByte2Int(sOldNextVal, 4, 1)
    sOldStep = SUBSTR(RecoverDef.TYPE, 10, 1) && archived next value step
    nOldStep = ASC(sOldStep)
    REPLACE AutoIncrm.DefAI WITH .T.;
      AutoIncrm.ArchiveNext WITH nOldNextVal,;
      AutoIncrm.ArchiveStep WITH nOldStep
  ENDIF
ENDSCAN
SET RELATION OFF INTO AutoIncrm
SELECT AutoIncrm
GO TOP
SET FILTER TO FileAI OR DefAI
=SetAIWarnings()

PROCEDURE SetAIWarnings
* places warning messages into AutoIncrmt
PRIVATE ALL
SELECT AutoIncrm
CurRecNo = RECNO()
REPLACE Warnings WITH '' ALL
SCAN && the filter is on
  DO CASE
  CASE AutoIncrm.FileAI AND !AutoIncrm.DefAI AND AutoIncrm.StepVal = 0
    * this does not exist in def file nor in field def
    REPLACE AutoIncrm.Warnings WITH ALLT(ALLT(Warnings) + " Not AutoInc.")
  CASE AutoIncrm.FileAI AND !AutoIncrm.DefAI
    * this does not exist in def file
    REPLACE AutoIncrm.Warnings WITH ALLT(ALLT(Warnings) + " AutoInc field not in .def file.")
  CASE !AutoIncrm.FileAI AND AutoIncrm.DefAI
    REPLACE AutoIncrm.Warnings WITH ALLT(ALLT(Warnings) + " No AutoInc field flag.")

  OTHERWISE
    IF AutoIncrm.NEXTVAL + AutoIncrm.StepVal => 256^4/2 -1
      REPLACE AutoIncrm.Warnings WITH ALLT(ALLT(AutoIncrm.Warnings) + " NextVal limit reached.")
    ENDIF
    DO CASE
    CASE AutoIncrm.StepVal = 0
      REPLACE AutoIncrm.Warnings WITH ALLT(ALLT(Warnings) + " Invalid StepVal.")
    CASE StepVal != ArchiveStep
      REPLACE AutoIncrm.Warnings WITH ALLT(ALLT(AutoIncrm.Warnings) + " StepVal <> Archive.")
    ENDCASE
    IF AutoIncrm.NEXTVAL < AutoIncrm.ArchiveNext
      REPLACE AutoIncrm.Warnings WITH ALLT(ALLT(AutoIncrm.Warnings) + " NextVal < Archive.")
    ENDIF
    IF ABS(AutoIncrm.NEXTVAL) > 256^4/2 -1
      REPLACE AutoIncrm.Warnings WITH ALLT(ALLT(AutoIncrm.Warnings) + " Invalid NextVal.")
    ENDIF
  ENDCASE
ENDSCAN
GO CurRecNo

*-------------
PROCEDURE AutoIncSave
* saves changes user made in AutoIncrm
PARAMETER DBFfile
PRIVATE ALL
DBFHandle = FOPEN(DBFfile, 2)
SELECT AutoIncrm
SET FILTER TO
SELECT RecoverDef
SET RELATION TO RECNO("RecoverDef") INTO AutoIncrm
SCAN FOR AutoIncrm.DefAI OR AutoIncrm.FileAI
  IF AutoIncrm.StepVal = 0 && Remove AutoInc flag from file & .DEF file
    PutString(DBFHandle, RECNO()*32 + 18, CHR(0)) && reset flag
    REPLACE RecoverDef.TYPE WITH LEFT(RecoverDef.TYPE, 2)
  ELSE && write Changes/NoChanges to file
    PutString(DBFHandle, RECNO("RecoverDef")*32 + 18, CHR(12)) && flag
    PutSValue(DBFHandle, RECNO("RecoverDef")*32 + 19, AutoIncrm.NEXTVAL, 4, 1) && NextVal
    PutString(DBFHandle, RECNO("RecoverDef")*32 + 23, CHR(AutoIncrm.StepVal)) && StepVal
    * place changes into RecoverDef
    REPLACE RecoverDef.TYPE WITH LEFT(RecoverDef.TYPE, 2) + '12a' + Int2Sbyte(AutoIncrm.NEXTVAL, 4, 1) + CHR(AutoIncrm.StepVal)
  ENDIF
ENDSCAN
=FCLOSE(DBFHandle)

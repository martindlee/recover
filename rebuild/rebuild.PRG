*-----------------------------------------------------------
* Rebuild Utility: Copyright Abri Technologies, www.abri.com
*-----------------------------------------------------------
PARAMETER Par1, Par2, Par3, Par4 && up to 4 directories can be handled or other defined parameters used.
PRIVATE ALL
Params = PCOUNT()
CLOSE DATA ALL

ErrorCount = IIF(Params > 4, 1, 0)

IF Params > 0
  Par1 = UPPER(ALLT(Par1))
  ErrorCount = IIF(TYPE('Par1')!='C', ErrorCount + 1, ErrorCount)
ENDIF
IF Params > 1
  Par2 = UPPER(ALLT(Par2))
  ErrorCount = IIF(TYPE('Par2')!='C', ErrorCount + 1, ErrorCount)
ENDIF
IF Params > 2
  Par3 = UPPER(ALLT(Par3))
  ErrorCount = IIF(TYPE('Par3')!='C', ErrorCount + 1, ErrorCount)
ENDIF
IF Params > 3
  Par4 = UPPER(ALLT(Par4))
  ErrorCount = IIF(TYPE('Par4')!='C', ErrorCount + 1, ErrorCount)
ENDIF

* parameters used later
lUserFileDefs = .F. && user file defs collection
lNewFileDefs = .F. && developer file defs collection
lUserUpdate = .F.
lErrorScan = .F.
lDelete = .F.
cFName = "" && single filename to handle or FileList filename

DirCount = 0 && 0 required for following CASE set

*** preliminary classifications
DO CASE
CASE FILE("REBUILD.DBF") AND FILE("NEWREBUILD.DBF") AND PARAMS = 0 && allow update only with no parameters
  lUserUpdate = .T.
CASE Params = 0 AND FILE("NEWREBUILD.DBF") && this should not be - NewRebuild table by itself requires parameters here
  ErrorCount = ErrorCount + 1
CASE (Params = 0 AND !FILE("NEWREBUILD.DBF"));
    OR (Params > 0 AND '*ERRORSCAN*' $ UPPER(ALLT(Par1))) && User Errorscan
  lErrorScan = .T.
  IF !FILE('Rebuild.dbf')
    ErrorCount = ErrorCount + 1
  ENDIF
CASE LEFT(ALLT(Par1), 1) == '*' AND (Params !=2 OR !FILE(ALLT(Par2))) && mixed up parameters
  ErrorCount = ErrorCount + 1
CASE Params > 0 AND FILE("REBUILD.DBF") &&AND !FILE("NEWREBUILD.DBF");
  && and possibly *DELETE* *ADD* *REFRESH* in second parameter
  lUserFileDefs = .T.
  IF INLIST(Par1, "*DELETE*", "*ADD*", "*REFRESH*", "*FILELIST*", "*EXCLUDELIST*")
    IF Params != 2 OR !FILE(Par2)
      ErrorCount = ErrorCount + 1
    ELSE
      cFname = UPPER(ALLT(Par2))
    ENDIF
  ELSE
    DirCount = Params
  ENDIF
CASE FILE("NEWREBUILD.DBF") AND !FILE("REBUILD.DBF") && developer file defs collecting;
  && and possibly *DELETE* *ADD* *REFRESH* in second parameter;
  && but with no parameters collect current dir info
  lNewFileDefs = .T.
  IF Params > 0 AND INLIST(Par1, "*DELETE*", "*ADD*", "*REFRESH*", "*FILELIST*", "*EXCLUDELIST*")
    IF Params != 2 OR !FILE(Par2)
      ErrorCount = ErrorCount + 1
    ELSE
      cFname = UPPER(ALLT(Par2))
    ENDIF
  ELSE && directories
    DirCount = Params
  ENDIF
OTHERWISE
  ErrorCount = ErrorCount + 1
ENDCASE

* if directories only
DIMENSION Dy[Max(DirCount,1)]
Dy = "" && needed for *ADD*DELETE*REFRESH*
IF DirCount = 0 AND !EMPTY(cFname)
  Dy[1] = Par1
ENDIF
IF DirCount > 0
  Dy[1] = DirName(Par1)
ENDIF
IF DirCount> 1
  Dy[2] = DirName(Par2)
ENDIF
IF DirCount > 2
  Dy[3] = DirName(Par3)
ENDIF
IF DirCount > 3
  Dy[4] = DirName(Par4)
ENDIF
IF DirCount > 0
  FOR I = 1 TO DirCount
    IF !EMPTY(Dy[I]) AND !DIRECTORY(Dy[I])
      ErrorCount = ErrorCount + 1
      EXIT
    ENDIF
  ENDFOR
ENDIF

* Initialize temporary messages table
cRebFilePath = ''
ERASE (TempFile("_RebMssgs.*"))
CREATE TABLE (TempFile("_RebMssgs")) FREE (Progress L, ERRORM L, EndM L, LogFile L, NoCreate L, INIT L, LogText M)
APPEND BLANK
REPLACE _RebMssgs.ERRORM WITH .T. && to allow possible missing rebuild.dbf and newrebuild.dbf error message.
nErrNo = 0
SELECT 0
ON ERROR nErrNo = ERROR()
DO CASE
CASE FILE('Rebuild.dbf')
  cRebFilePath = FULLPATH('Rebuild.dbf')
  USE Rebuild
CASE FILE('NewRebuild.dbf')
  cRebFilePath = FULLPATH('NewRebuild.dbf')
  USE NewRebuild ALIAS Rebuild
OTHERWISE && both files missing
  nErrNo = 1
ENDCASE
ON ERROR
IF nErrNo = 0
  TempString = REPLICATE('*', 25) + ' ' + DTOC(DATETIME()) + ' ' + TIME() + CHR(13) + CHR(10)
  SELECT _RebMssgs
  GO TOP IN Rebuild
  REPLACE;
    _RebMssgs.Progress WITH IIF(UPPER(LEFT(Rebuild.Codes, 1)) != 'F', .T., .F.),;
    _RebMssgs.ERRORM WITH IIF(UPPER(SUBSTR(Rebuild.Codes, 2, 1)) != 'F', .T., .F.),;
    _RebMssgs.EndM WITH IIF(UPPER(SUBSTR(Rebuild.Codes, 3, 1)) != 'F', .T., .F.);
    _RebMssgs.LogFile WITH IIF(UPPER(SUBSTR(Rebuild.Codes, 4, 1)) != 'F', .T., .F.);
    _RebMssgs.NoCreate WITH IIF(UPPER(SUBSTR(Rebuild.Codes, 5, 1)) != 'F', .T., .F.);
    _RebMssgs.INIT WITH .T.;
    _RebMssgs.LogText WITH TempString && =Initial logfile text - rebuild may or may not be logged
ELSE
  ErrorCount = ErrorCount + 1
ENDIF

IF USED("Rebuild")
  USE IN Rebuild
ELSE && invalid NewRebuild table
  nErrNo = -100
ENDIF

SELECT 0
** Save some environment variables
SetTalk = SET("TALK")
SET TALK OFF
SetCPDialog = SET("CPDIALOG")
SET CPDIALOG OFF
SetExcl = SET("EXCLUSIVE")
SET EXCLUSIVE ON
SetPath = SET("Path")
SET PATH TO && prevents problems with Recover.app / windows/system/recover.exe in VFP8+
SETDEFAULT = FULLPATH('.')

** Preliminary - error/safety checks, Open NewRebuild and/or Rebuild tables
DO CASE
CASE !FILE("REBUILD.DBF") AND !FILE("NEWREBUILD.DBF") && both files missing
  =Msg("Rebuild and/or NewRebuild tables not found in directory " + FULLPATH('.'),  "", "Rebuild notice!", 2)
  RETURN RestoreEnv(-1)
CASE nErrNo = -100 && corrupt Rebuild/NewRebuild tables
  =Msg("Invalid " + cRebFilePath + " table.",  "", "Rebuild notice!", 2)
  RETURN RestoreEnv(-1)
CASE ErrorCount > 0 && parameter errors
  =Msg("Invalid Rebuild parameter(s). Quiting Rebuild.", "", "Rebuild notice!", 2)
  RETURN RestoreEnv(-ErrorCount)
CASE lErrorScan && enduser ErrorScan
  IF !CheckReb("Rebuild.dbf") && there must be no errors in Rebuild.dbf/fpt
    RETURN RestoreEnv(-1)
  ENDIF
  USE Rebuild EXCL
  IF RECCOUNT() = 1
    =Msg("Cannot ErrorScan. No data file defs collected yet.", "", "Rebuild notice!", 2)
    RETURN RestoreEnv(-1)
  ENDIF
CASE lUserFileDefs && End user file defs collection
  IF !CheckReb("Rebuild.dbf") && there must be no errors in Rebuild.dbf/fpt
    RETURN RestoreEnv(1)
  ENDIF
  USE Rebuild.DBF EXCL ALIAS Rebuild
CASE lNewFileDefs && New File Defs collection
  IF !CheckReb("NewRebuild.dbf") && there must be no errors in Rebuild.dbf/fpt
    RETURN RestoreEnv(-1)
  ENDIF
  USE NewRebuild.DBF EXCL ALIAS Rebuild
CASE lUserUpdate = .T. && this should be an update

  IF !CheckReb("Rebuild.dbf") OR !CheckReb("NewRebuild.dbf") && there must be no errors in Rebuild.dbf/fpt
    RETURN RestoreEnv(-1)
  ENDIF

  USE Rebuild EXCL
  IF RECCOUNT("REBUILD") = 1 && the enduser has not run rebuild yet to collect data info
    =Msg("User data file structure info does not exist.",  "", "Rebuild Update Notice!", 2)
    RETURN RestoreEnv(-1)
  ENDIF
  USE NewRebuild EXCL IN 0 && Alias NewRebuild
  IF RECCOUNT("NEWREBUILD") < 2
    =Msg("Error! NewRebuild.dbf/.fpt is missing new update structure info.", "", "Rebuild Update Notice!", 2)
    RETURN RestoreEnv(-1)
  ENDIF
  lUserUpdate = .T.
ENDCASE
RELEASE cRebFilePath

* Recover/gendef.app/Rebuild.def are stored in the CheckReb intial checking routine
ERASE gendef.APP
ERASE RECOVER.APP && this will erase it after CheckReb routine if needed
ERASE Rebuild.Def
ERASE NewRebuild.Def

IF !lErrorScan AND (EMPTY(cFname) OR '*DELETE*' $ Par1) && or *DELETE* xxxx && filedefs or update requires exclusive use
  SELECT Rebuild
  Alias1 = ALIAS()
  Alias1dbf = DBF()
  Alias2 = ''
  IF USED ("NewRebuild")
    Alias2 = "NewRebuild"
  ENDIF

  * test exclusivenes
  FOR I = 1 TO MAX(DirCount, 1)
    IF !TestExclusive(lUserFileDefs OR lNewFileDefs, Dy[I], cFName)
      RETURN RestoreEnv(-1)
    ENDIF
  ENDFOR
  * exclusivenes test passed
  CLOSE DATA ALL && CLOSE ALL && necessary when dbc's present - VFP does not close .dbc completely to give access to *.dbc
  USE (Alias1dbf) EXCL ALIAS Rebuild
  IF !EMPTY(Alias2)
    USE NewRebuild EXCL IN 0
  ENDIF
ENDIF

FixedCount = 0 && used in errorscan

** now process jobs
DO CASE
CASE lUserFileDefs OR lNewFileDefs  && get new defs & cdx's OR first time use
  SELECT Rebuild
  nDataRecs = 0
  ExtNoticeType = ""
  IF INLIST(Dy[1], "*ADD*", "*DELETE*", "*REFRESH*") && specific 1 file request
    nTemp = 1 && first record
    lTemp = .F. && assume record does not exist
    SCAN FOR LIKE(FULLPATH(CFname), FULLPATH(Rebuild.File_Name))
      lTemp = .T. && in New/Reb list
      nTemp = RECNO() && point to last entry if exists
    ENDSCAN
    DO CASE
    CASE Dy[1] $ "*DELETE*" && just a simple entry delete - but not found in list
      IF lTemp && the file was found in rebuild list
        nDataRecs = 1
        DELETE FOR LIKE(FULLPATH(CFname), FULLPATH(Rebuild.File_Name)) && multiple just in case of redundant entries
      ENDIF
      ExtNoticeType = "deleted from"
    CASE INLIST(Dy[1], "*ADD*", "*REFRESH*")
      DELETE FOR LIKE(FULLPATH(CFname), FULLPATH(Rebuild.File_Name)) && multiple just in case of redundant entries
      IF !GetFileDefs(Dy[1], CFname) && this may be a corrupt file - leave entry as is
        ErrorCount = ErrorCount + 1
        GO nTemp
        RECALL && last entry only - but there should be only one
      ELSE
        nDataRecs = 1
      ENDIF
      ExtNoticeType = IIF (lTemp, "updated in", "added to")
    ENDCASE
    PACK
  ELSE && this is regular directory or file list collection
    DELETE FOR RECNO() > 1
    PACK
    FOR I = 1 TO MAX(DirCount, 1)
      ErrorCount = ErrorCount + IIF(GetFileDefs(Dy[I], CFname), 0, 1)
    ENDFOR
    IF ErrorCount = 0
      ExtNoticeType = "collected into"
    ENDIF
    nDataRecs = RECCOUNT() - 1
  ENDIF
  IF ErrorCount > 0
    RETURN RestoreEnv(-ErrorCount)
  ENDIF
  *  WaitClear()

  ExtNotice = "" && for lNewFileDefs
  IF lNewFileDefs AND RECCOUNT() > 1 && developer file info collection
    ExtNotice = + CHR(13) + CHR(10) + "Now you can change Recover option codes for special files";
      + CHR(13) + CHR(10) + "and/or special codes in NewRebuild.codes field."
  ENDIF

  sTemp = ALLT(STR(nDataRecs)) + " table/dbc/cdx file info records " + ExtNoticeType;
    + " " + IIF(lNewFileDefs, "New", "")    + "Rebuild table." + ExtNotice
  =Msg(sTemp, "", "Rebuild notice!", 3)
  RETURN RestoreEnv(nDataRecs) && the number of data file info collected
CASE lUserUpdate && Enduser update, should have both Rebuild.dbf/.fpt and NewRebuild.dbf/.fpt

  nTemp = UserUpdate()

  ErrorCount = ErrorCount + IIF(nTemp < 0, -nTemp, 0)
  IF ErrorCount > 0
    RETURN RestoreEnv(-ErrorCount)
  ENDIF
  WaitClear()
  =Msg("Data files update complete. " + ALLT(STR(nTemp)) + " data files updated", "", "Rebuild notice", 3)
  RETURN RestoreEnv(nTemp) && number of files updated
CASE lErrorScan && File errorscan/repair
  ErrorString = ErrorScan()
  ErrorCount = ErrorCount + VAL(RIGHT(ErrorString, 4))
  IF ErrorCount > 0
    RETURN RestoreEnv(-ErrorCount)
  ENDIF
  FixedCount = VAL(LEFT(ErrorString, 4))
  WaitClear()
  =Msg("Data file error scanning completed. ";
    +IIF(FixedCount > 0, ALLT(STR(FixedCount)) + " files repaired.", "No errors found."), "", "Rebuild notice", 3)
  RETURN RestoreEnv(FixedCount) && Return number of file repairs done
ENDCASE
WaitClear()
RETURN RestoreEnv(ErrorCount) && nonfixable ErrorCount should be 0

**-- Procedures
*-------------------
PROCEDURE TestExclusive
* checks that all needed files have exclusive access
PARAMETER lGetFileDefs, cCode_Dry, cFiles
* cCode_Dry is either *...* code or a directory
* cFiles is the filename if *...* code used otherwise ''
PRIVATE ALL
IF '*DELETE*' $ UPPER(ALLT(cCode_Dry)) && only delete a line entry
  RETURN
ENDIF

cRelDir = IIF(EMPTY(cFiles) AND !EMPTY(cCode_Dry), cCode_Dry, "")
IF lGetFileDefs && if lGetFileDefs => not in Rebuild yet, retreive file name(s)
  cCurrDir = FULLPATH('.')

  DIMENSION FileNames[1] && this may be changed by GetFileNames()

  FileCount = GetFileNames(@FileNames, cCode_Dry, "DBC", cFiles) && check dbc's
  FOR I = 1 TO FileCount
    IF !CheckAccess(FileNames[i], cRelDir)
      RETURN .F.
    ENDIF
  ENDFOR

  FileCount = GetFileNames(@FileNames, cCode_Dry, "DBF", cFiles) && check dbf's
  FOR I = 1 TO FileCount
    IF !CheckAccess(FileNames[i], cRelDir)
      RETURN .F.
    ENDIF
  ENDFOR
  RETURN
ENDIF

* otherwise these files already are in Rebuild - for errorscan, or update
SELECT Rebuild
SCAN FOR ".DBC" $ File_name OR ".DBF" $ File_name
  IF !CheckAccess(Rebuild.File_name, cRelDir)
    RETURN .F.
  ENDIF
ENDSCAN

*---
PROCEDURE CheckAccess
* checks exclusive access to a file
PARAMETER FileName, cRelDir
PRIVATE ALL
IF !AllowedDBF(FileName)  && Foxuser.dbf etc. files
  RETURN .T.
ENDIF

OldAlias = ALIAS()
cCurrDir = FULLPATH('.')
cFileName = FileName
IF !EMPTY(cRelDir)
  SET DEFAULT TO (cRelDir)
  IF '\' $ cFileName
    cFileName = SUBSTR(cFileName, RAT('\', cFileName) + 1)
  ENDIF
ENDIF

SELECT 0

* check if inaccessible
IF !FCLOSE(FOPEN(cFileName, 2))
  =Msg("Rebuild utility cannot access file " + ALLT(FULLPATH(cFileName)) + CHR(13) + CHR(10);
    + "File access denied.", "", "Rebuild Notice", 2)
  RETURN .F.
ENDIF
lDBC = ".DBC" $ UPPER(FileName)

* check if corrupt
ErrNo = 0
ON ERROR ErrNo = ERROR()
IF lDBC
  OPEN DATA (cFileName)
ELSE
  USE (cFileName) EXCL && ALIAS TempAlias
  Tempalias = ALIAS()
ENDIF
IF !(ErrNo = 0 OR (ErrNo = 1707 AND ".DBC" $ UPPER(cFileName))) && missing .dcx file is not an access error
  =Msg("Rebuild utility cannot process file " + ALLT(cFileName) + "! ";
    + CHR(13) + CHR(10) + MESSAGE(), "", "Rebuild Notice", 2)
  ON ERROR
  RETURN .F.
ENDIF
ON ERROR
DO CASE
CASE lDBC AND DBUSED(FileName)
  CLOSE DATA
CASE !lDBC AND USED(TempAlias)
  USE IN (TempAlias)
ENDCASE

IF !EMPTY(OldAlias)
  SELECT (OldAlias)
ENDIF

IF !EMPTY(cRelDir)
  SET DEFAULT TO (cCurrDir)
ENDIF

*-------------------
PROCEDURE GetFileDefs
* Collects new table and DBC info into Rebuild or NewRebuild
* this expects Rebuild.dbf or NewRebuild.dbf to be open ("USED") with "Rebuild" alias
* store .DBC's etc.
PARAMETER cCode_Dry, cFiles
PRIVATE ALL
Dirctry = IIF(LEFT(cCode_Dry,1) == '*', '', cCode_Dry)
GO TOP
GenOpts = Gen_Opts
Recopts = ALLT(Rec_opts)  && could be either Rebuild. or NewRebuild.

* DBC's
DIMENSION DBCx[1]
DBCCount = GetFileNames(@DBCx, cCode_Dry, "DBC", cFiles)
IF DBCCount < 0
  =Msg("Invalid or missing DBC file path specified " + "(" + cFiles + ")", "", "Rebuild GetFileDefs Notice", 2)
  RETURN .F.
ENDIF
IF DBCCount > 0
  =Msg("Saving .DBC's","", "", 1)
ENDIF

FOR I = 1 TO DBCCount
  * check DBC corruption
  =Msg("Checking " + DBCx[i] + " validation...", "", "", 1)
  ErrNo = 0
  ON ERROR ErrNo = ERROR()
  OPEN DATA (DBCx[i])
  IF ErrNo != 0
    WaitClear()
    =Msg(MESSAGE();
      + CHR(13) + CHR(10) + "Data file info collection cancelled.", "", "Rebuild GetFileDefs notice!", 2)
    ON ERROR
    RETURN .F.
  ENDIF
  ON ERROR
  * check dbc validation
  ERASE (TempFile("_reb_temp.txt"))
  VALIDATE DATA NOCONSOLE TO FILE (TempFile("_reb_temp.txt"))
  TempString = File2String(TempFile("_reb_temp.txt"))
  ERASE (TempFile("_reb_temp.txt"))
  IF "OBJECT #" $ UPPER(TempString) && DBC not valid - stop data info collection
    =Msg("Database " + DBCx[i] + " not valid.";
      + CHR(13) + CHR(10) + "Data file info collection cancelled.", "", "Rebuild notice!", 2)
    CLOSE DATA
    RETURN .F.
  ENDIF
  PACK DATA && clean it up - prevent bloat
  CLOSE DATA

  INSERT INTO Rebuild (File_name, Memo1, Memo3) VALUES (;
    DBCx[i],;
    File2String(DBCx[i]),;
    File2String(LEFT(DBCx[i], RAT('.', DBCx[i])) + 'DCT') ) && the .DCT file - .DCX not needed
  *  ENDIF
ENDFOR

* DBF's & indexes
* store .defs & indexes
1
=String2file(Memo2, 'gendef.app')
DIMENSION DBFx[1]
DBFCount = GetFileNames(@DBFx, cCode_Dry, "DBF", cFiles)
IF DBFCount < 0
  =Msg("Invalid or missing .DBF file path specified " + "(" + cFiles + ")", "", "", 2)
  RETURN .F.
ENDIF

GenDefError = .F.
CDXerror = .F.
FOR I = 1 TO DBFCount
  DBFx[i] = DBFx[i]
  IF AllowedDBF(DBFx[i])

    =Msg(PADR(ALLT(STR(I)) + '/' + ALLT(STR(DBFCount)) + " - Collecting structure info for " + DBFx[i], 80), "", "", 1)

    * store def file
    SpecialDef = .F.
    DBFleft = LEFT(DBFx[i], RAT('.', DBFx[i]))
    DefFileName = DBFleft + 'def'
    De_FileName = DBFleft + 'de_' && old style dbc path storage
    CdxFileName = DBFleft + 'cdx'

    IF FILE(De_FileName) && just delete old style .def/.de_ files and gen new style
      ERASE (De_FileName)
      ERASE(DefFileName)
    ENDIF

    IF !FILE(DefFileName) && no existing special def file
      IF gendef(DBFx[i],'',GenOpts) < 0 && quit if GenDef error
        GenDefError = .T.
        ERASE (DefFileName) && just in case GenDef created something erroneous anyway
        EXIT && exit loop on gendef error
      ENDIF
    ELSE && existing def file - leave it and use it
      SpecialDef = .T.
    ENDIF

    * store good .def into rebuild record.
    *    LOCATE FOR UPPER(DBFx[i]) $ UPPER(Rebuild.File_name)
    *    IF FOUND()
    *      GOTO RECNO() && prevent wrong replacement - found some cases
    *      REPLACE Rebuild.Memo1 WITH File2String(DefFileName)
    *    ELSE
    INSERT INTO Rebuild (File_name, Rec_opts, Memo1, Gen_Opts) VALUES(DBFx[i], Recopts, File2String(DefFileName), GenOpts)
    *    ENDIF

    * get index info
    SELECT 0
    ERRORNO = 0
    ON ERROR ERRORNO = ERROR()
    USE (DBFx[i])
    DBFalias = ALIAS()
    * CDXError = .F.
    CDXTagCount = TAGCOUNT()
    IF CDXTagCount > 0 && there are active indexes
      IF ERRORNO !=0
        CDXerror = .T.
        ON ERROR
        EXIT
      ENDIF
      ON ERROR
      CDXfile = CDX(1)
      TagString = ''
      FOR j = 1 TO CDXTagCount
        KeyString = IIF(PRIMARY(j), "PRIMARY", "")
        KeyString = IIF(CANDIDATE(j), "CANDIDATE", KeyString)
        KeyString = IIF(UNIQUE(j), "UNIQUE", KeyString)
        TagFilter = FOR(j)
        TagString = TagString + IIF(EMPTY(TagString), '', CHR(13)) + TAG(j) + ';' + SYS(14, j);
          + ";" + KeyString + ";" + TagFilter && do not add CHR(10) beside CHR(13)
      ENDFOR
      * copy the dbf structure to an empty table and then use the empty .cdx for storage
      DBCPath = GetDBCPath(DefFileName) && from DefFile
      SELECT (DBFalias)
      SETDEFAULT = FULLPATH(".") &&*---------- save original directory default

      SET DEFAULT TO LEFT(DBFx[i], RAT('\',DBFx[i])) && DBCpaths in files are relative and need to be addressed from there

      IF !EMPTY(DBCPath) && this has a dbc path
        COPY STRUCTURE TO _Reb_Tmp WITH CDX DATABASE (DBCPath)
      ELSE
        COPY STRUCTURE TO _Reb_Tmp WITH CDX
      ENDIF
      TempCDXFile = "_Reb_Tmp.CDX"
      SELECT Rebuild
      REPLACE Rebuild.Memo2 WITH TagString,;
        Rebuild.tag_count WITH CDXTagCount,;
        Rebuild.Memo3 WITH File2String(TempCDXFile)
      USE IN (DBFalias)

      * now remove the temporary table with .cdx
      IF !EMPTY(DBCPath)
        OPEN DATA (DBCPath)
        ON ERROR * && VFP5/6 STUMLES HERE
        REMOVE TABLE _Reb_Tmp DELETE
        ON ERROR
        CLOSE DATABASE && it also closes tables belonging to database
      ELSE
        ERASE _Reb_Tmp.DBF
        ERASE _Reb_Tmp.FPT
        ERASE _Reb_Tmp.CDX
      ENDIF
      SET DEFAULT TO (SETDEFAULT) &&*---------- restore original directory default

    ENDIF && IF CDXTagCount > 0
    ON ERROR
    * cleanup directory
    IF !SpecialDef OR FILE("Rebuild.DBF") && do not erase in developer's control
      ERASE (DefFileName) && but erase for enduser
    ENDIF
    IF USED(DBFalias)
      USE IN (DBFalias)
    ENDIF
    SELECT Rebuild
  ENDIF
ENDFOR

WaitClear()
ERASE gendef.APP
IF GenDefError
  =Msg(DBFx[i]+ " gendef error. File not accessible.";
    + CHR(13) + CHR(10) + "Data file info collection cancelled.", "", "Rebuild notice!", 2)
  RETURN .F.
ENDIF
IF CDXerror
  =Msg(CDXfile+ " indexfile error. File not accessible or invalid.";
    + CHR(13) + CHR(10) + "Data file info collection cancelled.", "", "Rebuild notice!", 2)
  RETURN .F.
ENDIF
IF DBCCount + DBFCount = 0
  =Msg("No data files found in " + Dirctry + " directory.", "", "Rebuild notice!", 2)
  RETURN .F.
ENDIF
WaitClear()

*-------------------
PROCEDURE GetDBCPath && used in GetFileDefs()
PARAMETER DefFileName
PRIVATE ALL
OldAlias = ALIAS()
SELECT 0
USE (DefFileName) ALIAS RecoverDef
DBCFilePath = ""
IF "FIELDALIAS" $ UPPER(FIELD(5)) && older style def file
  DBCPathFile = LEFT(DefFileName, LEN(DefFileName) - 3) + 'DE_'
  IF FILE(DBCPathFile)
    FileHandle = FOPEN(DBCPathFile)
    DBCFilePath = FGETS(FileHandle)
    =FCLOSE(FileHandle)
  ENDIF
ELSE && standard def file
  SCAN FOR !EMPTY(RecoverDef.DBCPath)
    DBCFilePath = DBCFilePath + ALLT(RecoverDef.DBCPath)
  ENDSCAN
ENDIF
USE IN RecoverDef
IF !EMPTY(OldAlias)
  SELECT (OldAlias)
ENDIF
RETURN DBCFilePath

*-------------------
PROCEDURE RemoveDBCCDX
* Removes DBC path/CDX flag from DBFfile
* File must be closed
PARAMETER DBFfile
*SET PROC TO CreateTable ADDITIVE
PRIVATE ALL
DBFhandle = FOPEN(DBFfile, 2)
IF DBFhandle > -1
  FirstRecPos = GetValue(DBFhandle, 8, 2, 1)
  FileType    = GetValue(DBFhandle, 0, 1, 1)
  VFP         = INLIST(FileType, 48, 49, 50)

  * remove CDX flag
  TableFlag = BITAND(GetValue(DBFhandle, 28, 1, 1), 2)
  =PutValue(DBFhandle, 28, TableFlag, 1, 1)

  * is it a VFP? - remove DBCpath
  IF VFP
    =FSEEK(DBFhandle, FirstRecPos - 263)
    =FWRITE(DBFhandle, REPLICATE(CHR(0), 263))
    =FCLOSE(DBFhandle)
  ENDIF
ELSE
  MESSAGEBOX("Could not access file " + DBFfile, 0, "Rebuild Procedure Error" )
ENDIF


*-------
PROCEDURE UserUpdate
* updates DBC/DBF/CDX's
*--- Rebuild & NewRebuild aliases should exist now
PRIVATE ALL
UpdateErrCount = 0

* Check-for/create-empty-new tables (if they do not already exist)
SELECT Rebuild
ERASE TempRebuild.idx
INDEX ON UPPER(ALLT(Rebuild.File_name)) TO TempRebuild.idx
SELECT NewRebuild
SET RELATION TO UPPER(ALLT(File_name)) INTO Rebuild
SCAN FOR ".DBF" $ UPPER(NewRebuild.File_name) AND EOF("Rebuild")
  DBFxName = ALLT(UPPER(File_name))
  IF !FILE(DBFxName) && table does not exist, create it
    =Msg(PADR("Creating new table: " + ALLT(File_name), 80), "", "", 1)
    DefFileName = LEFT(DBFxName, RAT('.', DBFxName)) + 'DEF'
    CdxFileName = ''
    IF !EMPTY(NewRebuild.Memo3) && cdx file exists - needed for table creation
      CdxFileName = LEFT(DBFxName, RAT('.', DBFxName)) + 'CDX'
      =String2file(NewRebuild.Memo3, CdxFileName)
    ENDIF
    =String2file(NewRebuild.Memo1, DefFileName)
    =CreateTable(DBFxName) && will create VFP as well as fox2x table types
    ERASE (DefFileName)
  ENDIF
ENDSCAN

* Check for field changes. If so, create temporary new tables and collect data into them
SomeTableChanges = .F. && alias is NewRebuild
TableChangeCount = 0

SCAN FOR !("NOMOD" $ UPPER(NewRebuild.Codes)) AND ".DBF" $ UPPER(NewRebuild.File_name) AND !EOF("Rebuild") && scan NewRebuild for already common tables
  * Compare .def files from both
  =Msg(PADR(ALLT(STR(RECNO())) + '/' + ALLT(STR(RECCOUNT())) + " - Scanning for changes in " + ALLT(File_name), 80), "", "", 1)
  =String2file(Rebuild.Memo1, "_Reb_File.Def")
  DBFxName = ALLT(NewRebuild.File_name)
  Dry=LEFT(DBFxName, RAT("\", DBFxName))
  Tname = SUBSTR(DBFxName, RAT("\", DBFxName)+1)
  TempTableName = Dry + "Temp_Reb" + Tname
  NewDefFile = LEFT(TempTableName, RAT('.', TempTableName)) + 'DEF'
  =String2file(NewRebuild.Memo1, NewDefFile)
  OldFileDBCPath = GetDBCPath("_Reb_File.Def")
  USE _Reb_File.Def IN 0 ALIAS RecDef
  USE (NewDefFile) IN 0 ALIAS NewRecDef
  ThisTableChanged = .F.
  SELECT NewRecDef
  GO BOTTOM IN NewRecDef
  GO BOTTOM IN RecDef
  DO CASE
  CASE RECCOUNT("NewRecDef") != RECCOUNT("RecDef") && different field count
    ThisTableChanged = .T.
    SomeTableChanges = .T.
  CASE !LIKE(ALLT(NewRecDef.Field_Name), ALLT(RecDef.Field_Name));
      OR VAL(NewRecDef.WIDTH) != VAL(RecDef.WIDTH);
      OR VAL(NewRecDef.Dec) != VAL(RecDef.Dec)
    * Table type, memoblock size or first record pos changed
    ThisTableChanged = .T.
    SomeTableChanges = .T.
  OTHERWISE && check for field changes
    GO TOP IN RecDef
    GO TOP IN NewRecDef && alias
    SCAN && for different fields in this table definition
      IF !LIKE(ALLT(RecDef.Field_Name), ALLT(NewRecDef.Field_Name));
          OR ALLT(RecDef.TYPE) != ALLT(NewRecDef.TYPE);
          OR ALLT(RecDef.WIDTH) != ALLT(NewRecDef.WIDTH);
          OR ALLT(RecDef.Dec) != ALLT(NewRecDef.Dec);
          OR ALLT(RecDef.DBCPath) != ALLT(NewRecDef.DBCPath)
        * some field has changed
        ThisTableChanged = .T.
        SomeTableChanges = .T.
        EXIT
      ENDIF
      SKIP IN RecDef
    ENDSCAN
  ENDCASE

  IF ThisTableChanged && copy data to a temporary table with changed fields
    TableChangeCount = TableChangeCount + 1
    = TablesChanged(TempTableName) && save table name of temporary tables created
    =Msg("Copying data to new table " + ALLT(DBFxName), "", "", 1)
    USE IN NewRecDef
    =CreateTable(TempTableName, .T.)
    SELECT 0
    USE (TempTableName) ALIAS NewTable
    * remove DBClink from old table first - otherwise may not append data correctly
    IF !EMPTY(OldFileDBCPath)
      RemoveDBCCDX(DBFxName)
    ENDIF
    APPEND FROM (DBFxName) && is old table now open? - should not be
    USE IN NewTable
  ENDIF

  USE IN RecDef
  ERASE _Reb_File.Def && was alias RecDef
  IF USED("NewRecDef")
    USE IN NewRecDef
  ENDIF
  IF !ThisTableChanged && no table changes, erase def file - but if changes, keep it for below process
    ERASE (NewDefFile)
  ENDIF
  SELECT NewRebuild
ENDSCAN
SELECT NewRebuild

**  Check if any tables have changed - copy old table contents into new table structures
IF SomeTableChanges AND USED("ChangedTables")
  GO TOP IN ChangedTables && current alias is NewRebuild
  DO WHILE !EOF("ChangedTables")
    TempDBFName = ALLT(ChangedTables.TableName)
    TempFPTName = LEFT(TempDBFName, RAT('.', TempDBFName)) + 'FPT'
    TempDefFile = LEFT(TempDBFName, RAT('.', TempDBFName)) + 'DEF'
    DBFxName = STRTRAN(TempDBFName, "Temp_Reb") && original table name
    SKIP IN ChangedTables
    LOCATE FOR ALLT(UPPER(DBFxName)) == ALLT(UPPER(NewRebuild.File_name))
    FptName = LEFT(DBFxName, RAT('.', DBFxName)) + 'FPT'
    IF FOUND() && the changed table - it should be found
      SELECT 0
      USE (TempDefFile) ALIAS NewRecDef
      ** restore its cdx/VFPmem/dbc flags & DBClinks
      GO BOTTOM
      FirstRecPos = VAL(NewRecDef.Dec)
      TableFlags = VAL(SUBSTR(Field_Name,5,3))

      * restore DBC link if any
      DBCFilePath = ''
      SCAN FOR !EMPTY(NewRecDef.DBCPath)
        DBCFilePath = DBCFilePath + NewRecDef.DBCPath
      ENDSCAN
      USE IN NewRecDef
      FileHandle = FOPEN(TempDBFName, 2)
      IF !EMPTY(DBCFilePath)
        =FSEEK(FileHandle, FirstRecPos - 263)
        =FWRITE(FileHandle, DBCFilePath)
      ENDIF

      * write (cdx/(VFP memo/DCB) table flags
      =FSEEK(FileHandle, 28)
      =FWRITE(FileHandle, CHR(TableFlags))
      =FCLOSE(FileHandle)

      * erase old table, rename new to old
      ERASE (DBFxName)
      RENAME (TempDBFName) TO (DBFxName)
      IF FILE(FptName)
        ERASE (FptName)
      ENDIF
      IF FILE(TempFPTName) && the old one may have memos but the new one may not
        RENAME (TempFPTName) TO (FptName)
      ENDIF
    ELSE
      =Msg("Rebuild - Table transfer error", "", "Rebuild notice!", 2)
      UpdateErrCount = UpdateErrCount + 1
    ENDIF
    ERASE (TempDefFile)
    SELECT NewRebuild
  ENDDO
  USE IN ChangedTables
ENDIF

**--- CDX changes
SELECT NewRebuild && relation still exists
SCAN FOR ".DBF" $ UPPER(NewRebuild.File_name) AND !EOF("Rebuild") AND !LIKE(NewRebuild.Memo2, Rebuild.Memo2) && index changes

  DBFxName = ALLT(NewRebuild.File_name)
  CdxFileName = LEFT(DBFxName, RAT('.', DBFxName)) + 'CDX'

  * check for non existing previous cdx or new created cdx
  IF NewRebuild.tag_count = 0 OR Rebuild.tag_count = 0
    FileHandle = FOPEN(DBFxName, 2)
    =FSEEK(FileHandle, 28)
    nTableFlags = ASC(FREAD(FileHandle, 1))
    IF NewRebuild.tag_count = 0 && no cdx file in new setup
      ERASE (CdxFileName) && erase non-attached old floating CDX's
      nTableFlags = BITCLEAR(nTableFlags, 0) && reset dbf header CDX flag
    ENDIF

    IF Rebuild.tag_count = 0 AND NewRebuild.tag_count > 0
      nTableFlags = BITSET(nTableFlags, 0) && set dbf header CDX flag
    ENDIF
    =FSEEK(FileHandle, 28)
    =FWRITE(FileHandle, CHR(nTableFlags))
    =FCLOSE(FileHandle)
  ENDIF

  IF NewRebuild.tag_count > 0
    * extract changed CDX file
    =String2file(NewRebuild.Memo3, CdxFileName)
  ENDIF
ENDSCAN

SELECT NewRebuild
SET RELATION OFF INTO Rebuild
SELECT Rebuild
CLOSE INDEXES
SELECT NewRebuild

CLOSE DATA ALL && CLOSE ALL
ERASE TempRebuild.idx
*ERASE TempNewRebuild.idx
ERASE Rebuild.DBF
ERASE Rebuild.FPT
RENAME NewRebuild.DBF TO Rebuild.DBF
RENAME NewRebuild.FPT TO Rebuild.FPT

** extract new DBC files
USE Rebuild EXCL && NewRebuild has been renamed to Rebuild now
SCAN FOR ".DBC" $ Rebuild.File_name
  DBCname = ALLT(Rebuild.File_name)
  DCTname = LEFT(DBCname, RAT('.', DBCname)) + 'DCT'
  DCXname = LEFT(DBCname, RAT('.', DBCname)) + 'DCX'
  =Msg("Updating .DBC files: " + DBCname, "", "", 1)
  ERASE (DCXname) && it will automatically be regenerated when DBC is needed
  =String2file(Rebuild.Memo1, DBCname)
  =String2file(Rebuild.Memo3, DCTname)
ENDSCAN

** reindex files - some changes have occured
SCAN FOR ".CDX" $ Rebuild.File_name AND !EMPTY(Rebuild.Memo2)
  =Msg("Reindexing file: " + ALLT(Rebuild.File_name), "", "", 1)
  SELECT 0
  USE (Rebuild.File_name) EXCL
  REINDEX
  USE
  SELECT Rebuild
ENDSCAN

IF UpdateErrCount > 0
  RETURN -UpdateErrCount
ELSE
  RETURN TableChangeCount
ENDIF

*-------
PROCEDURE TablesChanged
PARAMETERS TempTableName
* Save table name of temporary tables created
PRIVATE ALL
IF !USED("ChangedTables") && first time use
  CREATE CURSOR ChangedTables (TableName C (100))
ENDIF
INSERT INTO ChangedTables VALUES (TempTableName)

*---------------------
PROCEDURE GetFileNames
PARAMETER cFLArr, cCode_Dry, cFileType, cFiles
* retreives file list into array cFLArr
* file names retreived with relative path to current dir or whatever is in list rel to cur dir
* 1. cFLArr is the array to return the file list in - (@arrayname,.....)
* 2a. cCode_Dry is one of the "*DELETE*, *ADD*, *REFRESH*, *FILELIST* or *EXCLUDELIST* codes
*   2b. or directory for whole directory data collect
* 3. cFileType is 'DBF' or 'DBC'
* 4. cFiles is the name of file that contains a list or the single filename with code in 2a
* Parameters are required to be correct - check for errors at rebuild.prg start - not here
PRIVATE ADirArr, FileHandle, cLineText, RetVal, I, J, FileCount, cTemp, cCurrDir
DO CASE
CASE '*FILELIST*' $ UPPER(cCode_Dry) AND FILE(cFiles) && files list file cFiles
  DIMENSION cFLArr[10000]
  FileHandle = FOPEN(cFiles)
  i = 0
  DO WHILE !FEOF(FileHandle)
    cLineText = ALLT(FGETS(FileHandle))
    IF '.' + UPPER(cFileType) $ UPPER(RIGHT(cLineText, 4)) && cFileType must be 'DBF' or 'DBC'
      IF FILE(FULLPATH(cLineText))
        I = I + 1
        cFLArr[I] = cLineText
      ENDIF
    ENDIF
  ENDDO
  FCLOSE(FileHandle)
  RetVal = I
  IF I > 0
    DIMENSION cFLArr[I]
  ELSE
    DIMENSION cFLArr[1]
  ENDIF
  RETURN I
CASE INLIST(UPPER(cCode_Dry), "*DELETE*", "*ADD*", "*REFRESH*") AND FILE(cFiles)
  IF '.' + cFileType $ ALLT(UPPER(RIGHT(cFiles, 4)))
    cFLArr[1] = ALLT(UPPER(cFiles))
    RETURN 1
  ELSE && different cFileType
    RETURN 0
  ENDIF
CASE EMPTY(cFiles) OR ('*EXCLUDELIST*' $ UPPER(cCode_Dry) AND FILE(cFiles))
  ** get filenames from directory but exclude those in optional exclude list
  cTemp = ALIAS()

  * get exclude list (if any) into cursor _RebExclTemp_
  CREATE CURSOR _RebExclTemp_ (FileNames C(100))
  INDEX ON UPPER(FileNames) TAG FileNames
  SET ORDER TO
  PRIVATE cRelDir
  cRelDir = DirName(cCode_Dry)
  IF '*EXCLUDELIST*' $ UPPER(cCode_Dry) AND FILE(cFiles)
    cRelDir = ""
    APPEND FROM (cFiles) SDF
    REPLACE _RebExclTemp_.FileNames WITH ALLT(UPPER(_RebExclTemp_.FileNames)) ALL
  ENDIF
  SET ORDER TO FileNames

  cCurrDir = FULLPATH('.')
  SET DEFAULT TO (cRelDir) && adir() will not work correctly with relative directories
  FileCount = ADIR(ADirArr, "*." + cFileType)
  SET DEFAULT TO (cCurrDir)
  DIMENSION cFLArr[Max(FileCount,1)]
  I = 0
  FOR J = 1 TO FileCount
    IF !(SEEK(UPPER(FULLPATH(cRelDir + ADirArr[J, 1])));
        OR SEEK(UPPER(cRelDir + ADirArr[J, 1]))) && don't include those in _RebExclTemp_
      I = I + 1
      cFLArr[I] = UPPER(cRelDir + ADirArr[J, 1])
    ENDIF
  ENDFOR

  IF I > 0
    DIMENSION cFLArr[I]
  ELSE
    DIMENSION cFLArr[1]
  ENDIF

  USE IN _RebExclTemp_
  RELEASE ADirArr
  IF !EMPTY(cTemp)
    SELECT (cTemp)
  ENDIF
  RETURN I
OTHERWISE
  *  MESSAGEBOX("Specified file: '" + cFiles + "' not found.", 0, "Rebuild file collect error!")
  RETURN -1 && invalid file name specified
ENDCASE


*-------
PROCEDURE ErrorScan
* ErrorScans/repairs files in Rebuild alias table
PRIVATE ALL
ScanErrCount = 0
FixedCount = 0
* check any problems with .dbc and replace files if necessary
SCAN FOR '.DBC' $  UPPER(Rebuild.File_name) && Memo1/Memo3
  DBCname = ALLT(Rebuild.File_name)
  IF !FILE(DBCname)
    =Msg("Missing file " + DBCname, "", "Rebuild notice!", 2)
    ScanErrCount = ScanErrCount + 1
    LOOP && go back to scan start
  ENDIF
  DCTname = LEFT(DBCname, RAT('.', DBCname)) + 'DCT'
  DCXname = LEFT(DBCname, RAT('.', DBCname)) + 'DCX'
  ErrNo = 0
  ON ERROR ErrNo = ERROR()
  OPEN DATABASE (DBCname)
  ON ERROR
  IF DBUSED(DBCname)
    CLOSE DATABASE
  ENDIF
  IF ErrNo > 0 AND ErrNo != 1707 && bad dbc, extract good copy and replace - 1707 missing dcx fixed prev lines
    ERASE (DCXname)
    =String2file(Rebuild.Memo1, DBCname)
    =String2file(Rebuild.Memo3, DCTname)
    OPEN DATA (DBCname) && this with the above "ERASE" will create a new .DCX
    IF DBUSED(DBCname)
      CLOSE DATABASE && now it works
      =Msg("Corrupted " + DBCname + "/.DCT replaced with saved copy.", "", "Rebuild notice!", 2)
      FixedCount = FixedCount + 1
    ELSE && still a problem
      =Msg(DBCname + " problems... not fixed.", "", "Rebuild notice!", 2)
      ScanErrCount = ScanErrCount + 1
    ENDIF
  ENDIF
ENDSCAN
1
=String2file(Memo3, 'Recover.app') && extract recover.app

SCAN FOR '.DBF' $  UPPER(Rebuild.File_name)
  =Msg(PADR(ALLT(STR(RECNO('Rebuild'))) + '/' + ALLT(STR(RECCOUNT('Rebuild'))) + " - Errorscaning " + ALLT(Rebuild.File_name), 80), "", "", 1)

  * recover errorscan
  DBFxName = ALLT(Rebuild.File_name)

  IF !FILE(DBFxName)
    =Msg("Missing file " + DBFxName, "", "Rebuild notice!", 2)
    ScanErrCount = ScanErrCount + 1
    LOOP && go back to scan start
  ENDIF

  Recopts = ALLT(Rebuild.Rec_opts)
  DefFileName = LEFT(DBFxName, RAT('.', DBFxName)) + 'DEF'
  IF !EMPTY(Rebuild.Memo1)
    =String2file(Rebuild.Memo1, DefFileName) && extract .def file
  ENDIF
  FixRes = RECOVER(DBFxName, '', Recopts)
  ERASE (DefFileName) && not needed any more
  DO CASE
  CASE FixRes > 0
    = Msg("Repairs done on " + DBFxName + " - details in Recoverep.txt", "", "Rebuild notice!", 2)
    FixedCount = FixedCount + 1
  CASE FixRes < 0
    = Msg(DBFxName + " not fixed. Recover error No." + STR(FixRes, 3), "", "Rebuild notice!", 2)
    ScanErrCount = ScanErrCount + 1
  ENDCASE

  * now check .cdx tags
  IF FixRes => 0 && DBF was ok or was structurally fixed - check/fix .CDX, reindex, rebuildindex
    SELECT 0
    * check for .cdx errors
    ErrNo = 0
    DBFx = ''
    ON ERROR ErrNo = ERROR()
    USE (DBFxName) && ALIAS DBFx
    DBFx = ALIAS()
    ON ERROR
    =Msg('Checking ' + DBFxName + ' index file.', "", "", 1)
    IF USED (DBFx)
      USE IN (DBFx)
    ENDIF
    CDXfile = LEFT(DBFxName, RAT('.', DBFxName)) + 'CDX'
    IndexErr = INLIST(ErrNo, 19, 114, 1707, 1567) OR (Rebuild.tag_count > 0 AND !FILE(CDXfile))
    IF IndexErr OR 'REBUILDINDEX' $ Rebuild.Codes
      * replace the .CDX file with stored one - index error or REBUILDINDEX
      =String2file(Rebuild.Memo3, CDXfile)

    ENDIF

    * make sure the CDX file is linked in the DBF header - Recover, etc. could have removed it
    IF Rebuild.tag_count > 0
      DBFFileHandle = FOPEN(DBFxName, 2)
      =FSEEK(DBFFileHandle, 28)
      nTableFlags = ASC(FREAD(DBFFileHandle, 1))
      IF !BITTEST(nTableFlags, 0)
        nTableFlags = BITSET(nTableFlags, 0) && set dbf header CDX flag
        =FSEEK(DBFFileHandle, 28)
        =FWRITE(DBFFileHandle, CHR(nTableFlags))
        IndexErr = .T.
      ENDIF
      =FCLOSE(DBFFileHandle)
    ENDIF

    IF IndexErr OR 'REBUILDINDEX' $ Rebuild.Codes OR 'REINDEX' $ Rebuild.Codes
      =Msg('Reindexing ' + DBFxName + ' index file.', "", "", 1)
      * Any of the 3 cases require reindexing.
      USE (DBFxName) ALIAS DBFx
      REINDEX
      USE IN DBFx
    ENDIF

    IF IndexErr && invalid CDX file
      FixedCount = FixedCount + 1
      =Msg("IndexFile " + CDXfile + " error fixed!", "", "Rebuild notice!", 2)
    ENDIF

    IF USED ('DBFx')
      USE IN DBFx
    ENDIF
    SELECT Rebuild
  ENDIF && checking .cdx tags
ENDSCAN

USE IN Rebuild
ERASE RECOVER.APP && don't leave it in directory
RETURN STR(FixedCount, 4) + STR(ScanErrCount, 4)

*-----
PROCEDURE DirName
* makes sure directory path has '\' at end and that currdir is ""
PARAMETER Dirctry
IF Dirctry == '.'
  Dirctry = ""
ENDIF
RETURN IIF(EMPTY(Dirctry) OR '\' $ ALLT(RIGHT(Dirctry, 1)), ALLT(Dirctry), ALLT(Dirctry) + '\') && need '\' in directory string

*-----
PROCEDURE File2String
* saves file to referenced string StringStore
PARAMETERS FilePath
PRIVATE ALL
StringStore = ''
FileHandle = FOPEN(FilePath)
IF FileHandle < 1
  =Msg("File " + FilePath + " is not accessible - close any program using it first!" + CHR(13) + CHR(10) + "Quiting this program now....", "", "Rebuild notice!", 2)
  CANCEL
ENDIF
DO WHILE !FEOF(FileHandle)
  StringStore = StringStore + FREAD(FileHandle, 5000)
ENDDO
=FCLOSE(FileHandle)
RETURN StringStore

PROCEDURE String2file
* writes referenced string StringStore to file
PARAMETERS StringStore, FilePath
PRIVATE ALL
FileHandle = FCREATE(FilePath)
IF FileHandle < 1
  =Msg("File " + FilePath + " is not accessible - close the program first!" + CHR(13) + CHR(10) + "Quiting this program now....", "", "Rebuild notice!", 2)
  CANCEL
ENDIF
DO WHILE LEN(StringStore) > 0
  =FWRITE(FileHandle, LEFT(StringStore, 3000))
  StringStore = IIF(LEN(StringStore) > 3000, SUBSTR(StringStore, 3001), "")
ENDDO
=FCLOSE(FileHandle)

*--------
PROCEDURE CheckReb
* Checks structural health of Rebuild/NewRebuild tables
* and stores their .def files, and recover.app, gendef.app files.
PARAMETER TableName
PRIVATE ALL
=Msg("Self checking " + TableName, "", "", 1)
*=Msg("Self checking " + TableName, "NOCLEAR", "", 1)

SELECT 0
ErrNo = 0
ON ERROR ErrNo = ERROR()
USE (TableName) EXCL ALIAS TempAlias
IF ErrNo != 0
  WaitClear()
  =ProbMsg(ALLT(TableName) + " corrupt or inaccessible.")
  ON ERROR
  IF USED(TableName)
    USE IN (TableName)
  ENDIF
  WaitClear()
  RETURN .F.
ENDIF
ON ERROR

USE (TableName) ALIAS Rebuild EXCL

TableDBF = IIF("NEWREBUILD.DBF" $ UPPER(DBF()), "NewRebuild", "Rebuild")

* store new Gendef.app, Recover.app and Rebuild.def files
GO TOP
IF FILE("Gendef.app") && store new edition of Gendef.app
  REPLACE Memo2 WITH File2String('gendef.app')
ENDIF
IF EMPTY(Memo2)
  USE IN Rebuild
  RETURN ProbMsg("Gendef.app or Recover.app not loaded yet into " + TableDBF + ".dbf/fpt table.";
    + CHR(13) + "Please place a copy of Recover.app and Gendef.app in same directory.")
ENDIF

IF FILE("Recover.app") && store new edition of Gendef.app
  REPLACE Memo3 WITH File2String('Recover.app')
ENDIF
IF EMPTY(Memo3)
  USE IN Rebuild
  RETURN ProbMsg("Recover.app or Gendef.app not loaded yet into " + TableDBF + ".dbf/fpt table.";
    + CHR(13) + "Please place a copy of Recover.app and Gendef.app in same directory.")
ENDIF

* store New/Rebuild.def files or extract them
DefFileName = IIF("NEWREBUILD.DBF" $ UPPER(DBF()), "NewRebuild.def", "Rebuild.def")

IF FILE(DefFileName)
  GOTO 1 && precaution
  REPLACE Memo1 WITH File2String(DefFileName)
ENDIF

IF EMPTY(Memo1)
  USE IN Rebuild
  RETURN ProbMsg(DefFileName + " file not loaded yet into " + TableDBF + " table.";
    + CHR(13) + "Please create a copy of " + DefFileName + " in same directory.";
    + CHR(13) + "Rebuild uses this .def file for " + TableDBF + " self error checking.")
ENDIF

IF !FILE(DefFileName) && extract .def only if not already in the directory
  = String2file(Rebuild.Memo1, DefFileName)
ENDIF

* extract Recover.app file
IF !FILE("Recover.App")
  =String2file(Memo3, "Recover.App")
ENDIF

* now open Message table in case closed
IF !USED("_RebMssgs")
  USE (TempFile("_RebMssgs")) IN 0
ENDIF
USE IN Rebuild
* now scan rebuild for errors
RecResult = RECOVER(TableName,"", "TTTFFFFFTTTFFFFFFTFFF")
WaitClear()
IF RecResult != 0
  RETURN ProbMsg("Corrupt " + TableName)
ENDIF

*--
PROCEDURE ProbMsg
PARAMETER MsgTxt
WaitClear()
=Msg(MsgTxt + CHR(13) + "         Quiting Rebuild!", "", "Rebuild SelfCheck Error!", 2)
RETURN .F.

*--------
PROCEDURE RestoreEnv
** restore some environment parameters
PARAMETER ReturnV
SET DEFAULT TO (SETDEFAULT)
* record logfile if permitted
IF !USED("_RebMssgs")
  USE (TempFile("_RebMssgs")) IN 0
ENDIF
IF _RebMssgs.LogFile
  PRIVATE LogHandle, Fexist
  LogHandle = -1
  Fexist = .F.
  IF FILE("RebuildLog.txt")
    LogHandle = FOPEN("RebuildLog.txt", 2)
    =FSEEK(LogHandle, 0 ,2)
    Fexist = .T.
  ELSE
    LogHandle = FCREATE("RebuildLog.txt")
  ENDIF
  FWRITE(LogHandle, IIF(Fexist, CHR(13) + CHR(10), '') + _RebMssgs.LogText)
  =FCLOSE(LogHandle)
ENDIF
WaitClear()
USE IN _RebMssgs
ERASE (TempFile("_RebMssgs.*"))
IF ATC("Visual", VERSION())>0 AND SetCPDialog = 'ON'
  SET CPDIALOG ON
ENDIF
IF SetTalk = 'ON'
  SET TALK ON
ENDIF
IF SetExcl = 'OFF'
  SET EXCLUSIVE OFF
ENDIF
SET PATH TO (SetPath)
CLOSE DATA ALL && CLOSE ALL
RETURN ReturnV

*------------
PROCEDURE AllowedDBF
* Checks for excluded dbf files
PARAMETER FileName
FileName = UPPER(FileName)
IF  'FOXUSER.DBF'    $ FileName OR;
    'RECOVMSG.DBF'   $ FileName OR;
    'RECOVERM.DBF'   $ FileName OR;
    'NEWREBUILD.DBF' $ FileName OR;
    'REBUILD.DBF'    $ FileName OR;
    '_REBMSSGS.DBF'  $ FileName OR;
    '_REB_TMP.DBF'   $ FileName
  RETURN .F.
ENDIF

*---------------
PROCEDURE TempFile && returns temporary file path on Fox temp directory.
PARAMETER FileName
PRIVATE cRetVal
cRetVal = SYS(2023)
IF RIGHT(cRetVal, 1) != '\'
  cRetVal = cRetVal + '\'
ENDIF
RETURN cRetVal + FileName

*------
PROCEDURE Msg
* returns messages if allowed
PARAMETER Par1, Par2, Par3, MsgType
PRIVATE ALL
CurSelect = SELECT()
IF !USED("_RebMssgs")
  USE TempFile("_RebMssgs") IN 0
ENDIF
SELECT _RebMssgs
IF MsgType !=1 && message logging
  IF _RebMssgs.LogFile
    REPLACE _RebMssgs.LogText WITH _RebMssgs.LogText + DTOC(DATETIME()) + ' ' + TIME() + ' ' + Par1 + CHR(13) + CHR(10)
  ENDIF
ENDIF
DO CASE
CASE MsgType = 1 && progress messages
  IF _RebMssgs.Progress
    IF "NOCLEAR" $ Par2
      WAIT WINDOW Par1 NOWAIT NOCLEAR
    ELSE
      WAIT WINDOW Par1 NOWAIT
    ENDIF
  ENDIF
  SELECT (CurSelect)
  RETURN 0
CASE MsgType = 2 && error messages
  WaitClear()
  SELECT (CurSelect)
  RETURN IIF(_RebMssgs.ERRORM, MESSAGEBOX(Par1, 0, Par3), 0)
CASE MsgType = 3 && end messages
  WaitClear()
  SELECT (CurSelect)
  RETURN IIF(_RebMssgs.EndM, MESSAGEBOX(Par1, 0, Par3), 0)
ENDCASE
SELECT (CurSelect)
RETURN 0

*------------------------
PROCEDURE WaitClear
* clears wait windows probably generated by Rebuild - may not interact correctly with Recover wait windows.
PRIVATE CurAlias
CurAlias = ALIAS()
SELECT 0
IF !USED("_RebMssgs")
  USE TempFile("_RebMssgs")
ENDIF
IF _RebMssgs.Progress
  WAIT CLEAR
ENDIF
IF !EMPTY(CurAlias)
  SELECT (CurAlias)
ELSE
  SELECT 0
ENDIF

*============================================
PROCEDURE CreateTable
* Copyright 2002 Abri Technologies, www.abri.com
* Creates a new empty table from .def file - both vfp and fox2x type
* - using .def definition file info.
* AND adjusts size and writes EofMark
PARAMETERS DBFxName, NoCdxDbc
PRIVATE ALL
OmitCdxDbc = PARAMETERS() > 1 && temporary table name with field changes for storing current data - to be renamed to new
FileHandle = FCREATE(DBFxName)
ActRecords = 0

SELECT 0
DefFileName = LEFT(DBFxName, RAT('.', DBFxName)) + 'DEF'
USE (DefFileName) ALIAS RecoverDef

COUNT TO MemoCount FOR;
  LEFT(RecoverDef.TYPE, 1) = "M" OR LEFT(RecoverDef.TYPE, 1) = "G" OR LEFT(RecoverDef.TYPE, 1) = "P";

SUM VAL(WIDTH) TO RecordLen FOR RECNO()<RECCOUNT()
RecordLen=RecordLen+1

GO BOTTOM
FirstRecPos = VAL(RecoverDef.Dec)
TempS = LEFT(RecoverDef.Field_name, 2)
VFP = .F.
lAutoIncDBF = .F.
Alpha5  = LEFT(Field_name, 4) = 'ALP5' && alpha five file - similar to fox2x.
mBsize = VAL(RecoverDef.WIDTH)
DO CASE && following case order is important - otherwise messup
CASE LEFT(Field_name, 4) = 'VF31'
  FileType = 49
  lAutoIncDBF = .T.
  VFP = .T.
CASE LEFT(Field_name, 2) = 'VF'
  FileType = 48
  VFP = .T.
CASE MemoCount = 0 AND (TempS = 'FP' OR TempS = 'AL')
  FileType = 3
CASE TempS = 'FP' OR TempS = 'AL'
  FileType = 245
CASE TempS = 'DB' && DB3 with memo
  FileType = 131
ENDCASE
TableFlags = VAL(SUBSTR(Field_name,5,3))
IF OmitCdxDbc
  TableFlags = SetBit(0, TableFlags, .F.) && remove cdx flag from temporary table name
ENDIF
CODEPAGE   = VAL(SUBSTR(Field_name,8,3))

* get DBC link path name if exists
DBCfilePath = ''
SCAN FOR !EMPTY(RecoverDef.DBCPath) AND !OmitCdxDbc
  DBCFilePath = DBCfilePath + ALLT(RecoverDef.DBCPath)
ENDSCAN

*----- the following is essentially from Recover WriteHeader procedure
* Empty header first 33 bytes with nulls
=FSEEK(FileHandle, 0)
=FWRITE(FileHandle, REPLICATE(CHR(0),33))
=FSEEK(FileHandle, 32) && backup one byte

* Write type of file (memo or no memo) : 0
=PutValue(FileHandle, 0, FileType, 1, 1)

* Write last update date (today!) : 1-3
=FSEEK(FileHandle, 1)
=FWRITE(FileHandle,CHR(YEAR(DATE())-INT(YEAR(DATE())/100)*100);
  +CHR(MONTH(DATE()))+CHR(DAY(DATE())))

* Write actual number of Records in file : 4-7
EofMark = 0 && ^Z not used for empty files

=PutValue(FileHandle, 4, 0, 4, 1)

* above may affect FileLen
FileLen = EofMark + FirstRecPos

* Write Position of first data record : 8-9
=PutValue(FileHandle, 8, FirstRecPos, 2,1)

* Write Length of data record : 10-11
=PutValue(FileHandle, 10, RecordLen, 2, 1)

* write cdx/(VFP memo/DCB) flags : 28
=PutValue(FileHandle, 28, TableFlags, 1, 1)

* write code page mark : 29
=PutValue(FileHandle, 29, CODEPAGE, 1, 1)

* Rewrite Field definition subRecords
=FSEEK(FileHandle, 32)

* Reconstruct field subRecords in header
TempNo=1
SELECT RecoverDef
SCAN FOR RECNO()<RECCOUNT()
  TempS=PADR(ALLT(RecoverDef.Field_name),11,CHR(0))+LEFT(LEFT(RecoverDef.TYPE,1),1) && name and type
  TempS=TempS+IIF(Alpha5, PictType, Int2Byte(TempNo,4,1)) && displacement of field in rec or 0000 if Alpha5
  TempS=TempS+Int2Byte(VAL(RecoverDef.WIDTH),1,1)           && width
  TempS=TempS+Int2Byte(VAL(RecoverDef.Dec),1,1)             && decimals
  TempS=TempS+Int2Byte(VAL(SUBSTR(RecoverDef.TYPE, 2, 3)), 1, 1) && VFP field flags - 0 otherwise
  IF lAutoIncDBF AND SUBSTR(RecoverDef.TYPE, 5, 1) = 'a'
    * an autoinc field
    TempS = TempS + SUBSTR(RecoverDef.TYPE, 6, 5) + REPLICATE(CHR(0), 8) && autoinc bytes + trailing 0's
  ELSE && not an autoinc
    TempS = TempS + REPLICATE(CHR(0), 13) && just 0's
  ENDIF

  =FWRITE(FileHandle, TempS , 32)
  TempNo=TempNo+VAL(RecoverDef.WIDTH)
ENDSCAN
USE IN RecoverDef
=FWRITE(FileHandle, CHR(13), 1)  && header record terminator

* IF VFP write database back-links info (263 bytes, 0+262 spaces or FilePath)
IF VFP
  TempNo = FSEEK(FileHandle, 0, 1) && save current position
  =FWRITE(FileHandle, REPLICATE(CHR(0), 263))
  =FSEEK(FileHandle, TempNo)
  IF !EMPTY(DBCFilePath)
    =FWRITE(FileHandle, DBCFilePath)
  ENDIF
ENDIF

IF FileLen != FirstRecPos AND !Alpha5
  =FSEEK(FileHandle, FileLen-1)
  =FWRITE(FileHandle, CHR(26), 1) && eof mark
ENDIF
=FCHSIZE(FileHandle, FileLen)

FCLOSE(FileHandle)

**---- create memo file if needed
IF MemoCount > 0
  MemoFileName   = LEFT(DBFxName, RAT('.', DBFxName) - 1) + IIF(FileType=131, '.DBT', '.FPT') && memo file name
  MHandle=FCREATE(MemoFileName)
  mBsize = IIF(FileType=131, 512, mBsize) && use default 64 memo block size for FoxPro files (only)
  FirstBlock = CEILING(512/mBSize)
  MemoEnd=511 && file size should be at least 512 bytes long
  NextFreeBlock = CEILING((MemoEnd+1)/mBSize)
  TempS=Int2Byte(NextFreeBlock, 4, IIF(FileType=131,1,-1));
    +CHR(0)+CHR(0);
    +Int2Byte(mBSize, 2, -1);
    +REPLICATE(CHR(0), FirstBlock*mBSize-8)
  =PutString(MHandle, 0, TempS)
  =FCHSIZE(MHandle, NextFreeBlock*mBSize)
  FCLOSE(MHandle)
ENDIF

********************
PROCEDURE PutValue
* Converts 'Intgr' value to N bytes and writes it at location FileLoc
* Returns number of bytes written
PARAMETER FileHandle, fileloc, Intgr, nbytes, dirn
=FSEEK(FileHandle, fileloc)
RETURN FWRITE(FileHandle, Int2Byte(Intgr, nbytes, dirn))

****************
PROCEDURE Int2Byte
PARAMETER decm, N, dirn
* Converts an integer number 'Decm', into a Byte string, N digits long
* Left to right if Dirn = -1 and right to left if Dirn = 1
* Returns: the Byte String
PRIVATE num, rem, retval
retval=''
num = decm
rem=0
DO WHILE num>255
  rem=num%16
  retval = IIF(dirn>0, retval+CHR(num%256), CHR(num%256)+retval)
  num=INT(num/256)
ENDDO
retval=IIF(dirn>0, retval+CHR(num), CHR(num)+retval)
* Now make sure its N long by padding on left or right
retval=IIF(dirn>0, PADR(retval,N,CHR(0)), PADL(retval,N,CHR(0)))
RETURN retval

************
PROCEDURE PutString
* Writes xString at FileLoc
PARAMETERS FileHandle, Fileloc, xString
=FSEEK(FileHandle, Fileloc)
RETURN FWRITE(FileHandle, xString) && returns number of bytes writen

***************
FUNCTION Bit
PARAMETER BITNO, A
* Returns .T. if BitNo of A is set
* Example: =Bit(0, 4)
RETURN INT(MOD(A/2^BITNO,2))=1

FUNCTION SetBit
PARAMETER BITNO, A, BSet
* Sets BitNo of A if bSet = .T. and resets it if .F.
* Returns A with bit set/reset
RETURN IIF(Bit(BITNO, A), IIF(BSet, A, A - 2^BITNO), IIF(BSet, A + 2^BITNO, A))

**************
PROCEDURE GetValue
* Gets integer value from N bytes at file location FileLoc
PARAMETER FileHandle, fileloc, nBytes, dirn
=FSEEK(FileHandle, fileloc)
RETURN Byte2Int(FREAD(FileHandle, nBytes), dirn)

*************
PROCEDURE Byte2Int
PARAMETER STRING, dirn
* converts Bytes string to decimal value
* If Dirn = -1 : standard calculator left to right digit significance
* If Dirn = +1 : assembler memory addressing right to left significance
PRIVATE strlen, A, B, retval, i, j
retval=0
j=0
A=IIF(dirn>0, 0, LEN(STRING)-1)
B=IIF(dirn>0, LEN(STRING)-1, 0)
FOR i=A TO B STEP dirn
  j=j+1
  retval = ASC(SUBSTR(STRING, j, 1))*256^i + retval
ENDFOR
RETURN retval


*****************************************************************************
*
*  RECOVER.PRG -3/16/05 revision - V4.0b
*
*****************************************************************************
*  ErrorScans, Recovers/repairs database table and memo files.
************************************************************************
* Copyright 1995
* Paul Lee, author,
* Abri Technologies, www.abri.com
************************************************************************
* Notes: Recover uses its own version of MessageBox for messages.
*       Its the same format as Visual Fox. It looks for Prodecure Messagebox for FPD & FPW
************************************************************************
PARAMETERS DBFnm, FPTnm, RecovOpts, Dext
PRIVATE ALL
#DEFINE demo .F.

* Save/setup envoronment conditions
OldArea = SELECT()
SELECT 0
Parms = PARAMETERS()

OnError = ON("ERROR")

ON ERROR * && FPD/FPW < 2.6 do not have CpDialog SETs
SetCPDialog = SET("CPDIALOG")
SET CPDIALOG OFF && prevents VFP5 codepage dialog poping up
SetExact = SET("Exact") && otherwise duplicate checking, or other seeks may be off
SET EXACT ON
SetCompat = SET("Compatible")
SET COMPATIBLE OFF && prevents subscript out of range error
ON ERROR

SetSafety = SET("SAFETY")
SetTalk = SET("TALK")
sSetProc = SET("Procedure")
SET PROCEDURE TO
SET SAFETY OFF
SET TALK OFF && prevents writing extra stuff to screen and slowing down
PUSH KEY

Default0 = SYS(5)+CURDIR() && save default directory
nFoxVersion = VAL(SUBSTR(VERSION(), AT('.', VERSION()) -2, 4)) && current version of foxpro running - NUMERIC

VFP = .F. && required if file not selected
lAutoIncErr = .F. && flag when errors found
lAutoIncDBF = .F. && File type reference
sAutoInc = "" && **Array** stores autoinc field names & next/step values
sAutoIncWrngs = "" && stores autoinc warnings if any
sAIerrFlds = "" && stores autoinc field names having errors

* check if BrowsFil form request
IF Parms > 2 AND "BROWS" $ UPPER(RecovOpts)
  =BrowsFil(DBFnm, FPTnm, demo) && FPTnm is used as ScanLevel argument
  =RestoreDefs()
  RETURN 0
ENDIF

* check if autoinc form request
IF Parms > 1 AND "AUTOINC" $ UPPER(FPTnm)
  IF nFoxVersion < 8 && reject if not at least V8
    =MESSAGEBOX("Incorrect Foxpro version for Autoinc editing!", 0, "Recover Autoinc.")
    =RestoreDefs()
    RETURN -1
  ENDIF
  =AutoIncrm(DBFnm)
  =RestoreDefs()
  RETURN 0
ENDIF

CpRt = IIF(ATC("Visual", VERSION())>0, "VFP ", "") + "Recover - Copyright 1995 (C) Abri Technologies - Decompiling Illegal"

MsgFont = IIF(_WINDOWS,"MS Sans Serif", "Geneva") && default font

#DEFINE OptCodeN 22
DIMENSION OptCode[OptCodeN] && 04-10-1997
OptCode = .T. && default for most
* standard options
OptCode[3] = .F. && do not check field in record scan
OptCode[4] = .F. && do not use warnings in field check
OptCode[14] = .F. && do not use VFPs as default
OptCode[17] = .F. && do not extract extraneous memos
OptCode[22] = .F. && do not fix autoinc fields

IF Parms > 2 AND !EMPTY(RecovOpts) && if empty use standard options
  FOR i = 1 TO MIN(LEN(RecovOpts), OptCodeN)
    OptCode[i] = IIF(SUBSTR(RecovOpts, i, 1) = 'T', .T., .F.)
  ENDFOR
ENDIF

* Option Code variables - easier to change
CheckRhdr  = OptCode[1]
RScanLevel = 0
DO CASE
CASE OptCode[2] AND OptCode[3] AND OptCode[4]
  RScanLevel = 3
CASE OptCode[2] AND OptCode[3]
  RScanLevel = 2
CASE OptCode[2]
  RScanLevel = 1 && check delete flag or trace code at least
ENDCASE

RepRHeadM  = OptCode[5] && repair record header method
rTraceM    = OptCode[6]
LFSm       = OptCode[7] && LFSm turns .F. if RecVal returns non delete flag or Trace code error
vFPSM      = OptCode[8]

CheckMhdr  = OptCode[9]
MScanLevel = 0
DO CASE
CASE OptCode[11] AND OptCode[10]
  MScanLevel = 2
CASE OptCode[10]
  MScanLevel = 1
ENDCASE

RepMHead   = OptCode[12]
mTraceM    = OptCode[13]
SPMm       = OptCode[14]
RepMptrsM  = OptCode[15]
EmptyMemoM = OptCode[16]

SaveExtraM = OptCode[17]
ShowProgrM = OptCode[18]
ShowMsgBox = OptCode[19]
SaveOldRM  = OptCode[20]
DefWarn    = OptCode[21]
lFixAutoInc= OptCode[22]
RELEASE OptCode

TimeElapsed = SECONDS()

TempNo = 0

* check for international settings
* test only = .F.
IF FILE("RecovMsg.dbf")
  IF USED("RecovMsg")
    SELECT RecovMsg
  ELSE
    SELECT 0
    USE RecovMsg.DBF ALIAS RecovMsg
  ENDIF
  GO TOP
  IF NOT EMPTY(RecovMsg.Msg)
    MsgFont = ALLT(RecovMsg.Msg)
  ENDIF
ENDIF
IF Parms=0
  RETURN MB(;
    GM( 5, "Usage: =RECOVER(Recfile.ext [, Memofile.ext [, OptionCodes [, DefExtOpt]]])"),;
    GM( 4, "Notice!"),;
    0, -1, .T.)
ENDIF

* OK 2.0
DBFfile = FULLPATH(DBFnm) && needed for set default temporary path
MemoFile = IIF(Parms<2 OR EMPTY(FPTnm), '', FULLPATH(FPTnm))
DO CASE
CASE LEFT(RIGHT(DBFfile,4), 1)!='.'
  RETURN MB(;
    UPPER(DBFfile)+" "+GM( 6, "Filename extension (.DBF, .SCX, ...) missing!"),;
    GM( 4, "Notice!"),;
    0, -2, .T.)
CASE !FILE(DBFfile)
  RETURN MB(;
    UPPER(DBFfile)+" "+GM( 7, "File not found!"),;
    GM( 4, "Notice!"),;
    0, -3, .T.)
ENDCASE
* set default to where the file is
SET DEFAULT TO LEFT(FULLPATH(DBFfile), RAT('\',FULLPATH(DBFfile)))

* Must have exclusive low level use - check if file is in use
IF !FCLOSE(FOPEN(FULLPATH(DBFfile), 2)) && , 2 corrected 12/30/97 - to test for excl correctly
  RETURN MB(;
    GM( 8, "RECOVER requires exclusive use of '") + UPPER(DBFfile);
    +GM( 9, "' file. Please close file before using RECOVER."),;
    GM( 4, "Notice!"), 0, -4, .T.)
ENDIF

* OK 2.0
IF Parms > 3 && different def extension specified
  TempNo = RAT('.',Dext)
  DefExt = '.'+RIGHT( IIF(TempNo>0, SUBSTR(Dext,TempNo), Dext) ,3)
  De_Ext = LEFT(DefExt,3)+'_'
ELSE
  DefExt = '.DEF'
  De_Ext = '.DE_'
ENDIF

CRLF = CHR(13) + CHR(10)
RecMsg = "" && brief message at end of recover
DBFleft = UPPER(IIF(RAT('.',DBFfile)>0, LEFT(DBFfile, RAT('.',DBFfile)-1), DBFfile))
DefFile = DBFleft+DefExt && field definition file

DBCFilePath = '' && the dbc path extracted from .def file or oldstyle .de_ file - may not be correct if .def out of date
IF FILE(DBFleft + De_Ext) && old style .de_ file - get dbc path
  TempNo2 = FOPEN(DBFleft+De_Ext)
  DBCFilePath = FREAD(TempNo2,263)
  =FCLOSE(TempNo2)
ENDIF

* String for storing final message in file RECOVREP.TXT
ErrFixes =;
  "****************************" + CRLF;
  + DBFleft+" "+ GM(11, "Recover report -")+ " " + DTOC(DATE())+' '+ TIME()+CRLF+CRLF

#IF demo
  IF !DemoChk(DBFfile)
    SET DEFAULT TO (Default0)
    RETURN 0
  ENDIF
#ENDIF

************** General variables
** misc etc.
* PRIVATE RepMsg1, RepMsg2, PrevSec, TempNo2, TempNo3 && TempNo already declared private
TempS  = ""
TempNo  = 0
TempNo2 = 0
TempNo3 = 0
* PRIVATE MemProp, FldProp, NullFlagCeil
DIMENSION MemProp[256,4], FldProp[1,5]
MemProp = 0 && pascal may need separate MemProp[x,4] => string type.
FldProp = .F. &&
NullFlagCeil = 1
* PRIVATE PictType, TextType, GenType && memo type indicators
PictType = CHR(0)+CHR(0)+CHR(0)+CHR(0)
TextType = CHR(0)+CHR(0)+CHR(0)+CHR(1)
GenType  = CHR(0)+CHR(0)+CHR(0)+CHR(2)
PrevSec = 0 && used for user report
RepMsg1 = ''
RepMsg2 = ''

RecovVal = 0 && assume file OK initially

** flags
MemoCount    = 0 && # of memo or general fields in record
RtraceFlag = .F. && indicates if trace used in record
MtraceFlag = .F. && indicates if traces used in memos
MemoTypes   = '' && types of memos in table '012' - '0' for PICT, '1' for text, '2' for gen
RheaderOK    =.T. && record fileheader error flag
MheaderOK    =.T. && memo fileheader error flag
RecordOK = .T. && used for trace record scanning
MemoOk = .T. && used for memo data region checking
LFoffset = 0 && assume no offset

** raw file variables
TempFile    = '' && temporary file name (first part)
TDBFHandle  = 0 && temporary file handle for DBF
TmemoFile   = '' && temp. memo file name (first part)
TMemoHandle = 0 && temporary memo file handle if needed
MemoHandle  = 0 && memo file handle
MemoLen     = 0 && memo file length - initialization
CdxName     = DBFleft + IIF(ATC('.DBC', DBFnm)>0, 'DCX', '.CDX')

DBFHandle  = FOPEN(DBFfile, 2) && .DBF filehandle
TempNo = OK2GB(DBFfile, DBFHandle, Default0, " DBF file '" + DBFfile + "' ")
DO CASE
CASE TempNo = 1 && over 2gb fixed here
  * now remove all scan/repair options except header repair
  CheckRhdr  = .T. && check header
  RScanLevel = 0 && do not scan records
  RepRHeadM  = .T. && repair record header method
  rTraceM    = .F.
  LFSm       = .F.
  vFPSM      = .F.
  CheckMhdr  = .F.
  MScanLevel = 0
  RepMHead  = .F.
  mTraceM    = .F.
  SPMm       = .F.
  RepMptrsM  = .F.
  EmptyMemoM = .F.
  =PutValue(DBFHandle, 4, GetValue(DBFHandle, 4, 4,1) + 1, 4, 1) && just set counter off to report an error - otherwise it will report OK
CASE TempNo = 2 && over 2gb not fixed
  RETURN -10*EndRecover(GM(28, "File not recovered!"))
ENDCASE && = 0 no need fixing
FileLen = FSEEK(DBFHandle, -1, 2)+1
RheaderOK = FileLen >= 64

**------ 2GB file size check - this section only works for VFP5+
* For 2GB+ files except for FCHSIZE() some Fxxxx() low level file functions will not work
*   must change size before continuing.

RELEASE OptCode

FileType    = GetValue(DBFHandle, 0, 1, 1)
VFP         = INLIST(FileType, 48, 49, 50)
lAutoIncDBF	= INLIST(FileType, 49, 50)
*Alpha5     = GetValue(DBFhandle, 44, 4, 1) = 0 && "Alpha five software" modified FoxPro file.
Alpha5      = .F. && identify Alpha5 files only from .def file
DelChar     = '* ' && IIF(Alpha5, '*- ', '* ')
MemoFile    = IIF(Parms>1 AND LEN(MemoFile)>0, MemoFile, DBFleft + IIF(FileType=131, '.DBT', '.FPT')) && memo file name
TableFlags  = GetValue(DBFHandle, 28, 1, 1)
nCodePage    = GetValue(DBFHandle, 29, 1, 1)
IndRecords  = 0 && indicated file records
ActRecords  = 0 && actual file records
MBlockSize  = IIF(FileType = 131, 512, 64) && Memo block size - use default to start with
FirstBlock  = 0 && to be recalculated when needed
FirstRecPos = GetValue(DBFHandle, 8, 2, 1)
RecordLen   = GetValue(DBFHandle, 10, 2,1)
EofMark     = IIF(GetValue(DBFHandle, FileLen-1, 1, 1)=26,1,0) && check if ^Z at end of file
FileEnd     = FileLen-EofMark-1 && -1 => position values are counted from 0

ErrFixes = Wmsg(1, ErrFixes,  GM(12, "** DBF file:") + " " + CRLF)
DuplicateFN = .F. && duplicate field name error check - initialize

*********** *.dbf header error detection **************
ErrMsg = GM(25, "DBF header OK! ") && "."+GM(13, "No DBF errors found!")
IndRecords = GetValue(DBFHandle, 4, 4,1) && Records shown in header

* Calculated records - without .DEF file
IF (FileType=3 OR FileType=131) AND GetValue(DBFHandle, FirstRecPos + IndRecords*RecordLen, 1, 1)=26
  * Old dBaseIII files may use EofMark after last record instead of just exact recordlength boundaries like in VFP
  ActRecords = IndRecords
ELSE
  ActRecords = INT((FileLen - EofMark - FirstRecPos)/RecordLen) && should be - but ignores extra few bytes beyond last record
ENDIF

* Header checking w/o .def file
IF CheckRhdr AND RheaderOK
  RheaderOK = FileLen > 63
  RheaderOK = RheaderOK AND FirstRecPos < FileLen+1 AND FirstRecPos > 63

  IF RheaderOK
    ** Check FieldCount, FieldName and FieldType
    i=1
    TempNo = GetValue(DBFHandle, i*32, 1, 1)
    DO WHILE (i*32<FileLen+1) AND i<256 AND TempNo!=13 AND RheaderOK
      TempS=CHR(GetValue(DBFHandle, i*32+11, 1, 1))
      RheaderOK = (VFP AND TempS $ 'WCYBDTFGILMNPQV0');
        OR ((FileType=3 OR FileType = 245) AND TempS $ 'CDFGLMNP');
        OR (FileType=131 AND TempS $ 'CDFLMN')
      * check for memo/general fields
      IF TempS $ 'GMPW' && if a General, Picture (Mac only?) other Memo or Blob
        MemoCount=MemoCount+1
      ENDIF
      * check fieldname
      RheaderOK = RheaderOK AND FieldNOK(Rtrim0(GetString(DBFHandle, i*32, 10)), .T., !VFP) && allow for lower case in non-VFPtype
      RheaderOK = RheaderOK AND 0<i AND i<256 && fieldcount
      i=i+1
      TempNo = GetValue(DBFHandle, i*32, 1, 1)
    ENDDO
    IF USED("_RecoverFN") && used to check fieldname duplication
      USE IN _RecoverFN
    ENDIF
  ENDIF

  IF RheaderOK
    * crosscheck MemoCount count with file memo indicator.
    RheaderOK = (MemoCount>0) = ((FileType = 131) OR (FileType = 245) OR (VFP AND Bit(1,TableFlags)))
  ENDIF
  * check indicated and calculated record count
  IF RheaderOK && so far
    RheaderOK = IndRecords = ActRecords
    IF !FILE(DefFile) AND !RheaderOK && incorrect record counter
      IF RepRHeadM && fix the record count for no def file.
        ErrMsg = GM(15, "Record counter adjusted!")
        =PutValue(DBFHandle, 4, ActRecords, 4, 1)
        RecovVal = 1 && counter was repaired
        RheaderOK = .T. && back to OK for record counter
      ELSE && repair not permitted
        RecovVal = -10
        RheaderOK = .F.
      ENDIF
    ENDIF
  ENDIF

  * check exact filelen for VFP8+ requirements
  IF RheaderOK AND (lAutoIncDBF OR nFoxVersion > 7)
    CalcFLen =  FirstRecPos + ActRecords*RecordLen + EofMark
    RheaderOK = (FileLen = CalcFLen)
    IF !FILE(DefFile) AND !RheaderOK && invalid EOF position for VFP8+
      IF RepRHeadM && fix the file-end tail for no def file
        ErrMsg = GM(37, "File EOF mark adjusted! (VFP8+)")
        =FCHSIZE(DBFHandle, ActRecords*RecordLen + FirstRecPos)
        =FSEEK(DBFHandle, 0, 2) && eof
        IF FileLen > FirstRecPos + 1
          =FWRITE(DBFHandle, CHR(26), 1) && EOF mark only for > 0 records
        ENDIF
        RecovVal = 1 && EOF adjusted
        RheaderOK = .T. && actually eof was adjusted but same result
        FileLen = FSEEK(DBFHandle, 0, 2) + 1
      ELSE
        RecovVal = -10
        RheaderOK = .F.
      ENDIF
    ENDIF
  ENDIF
ENDIF

* check File/.DEF match
IF GetFileDefs(.F.) = -2
  RETURN -6*EndRecover(DefFile+"' "+GM(91, "appears incorrect!")) && .DEF file incorrect
ENDIF

* Using RecoverDef: Crossckeck header fieldnames with def file,
* Check first record position - it must be after opening .def file - 9-16-02
* VFP .dbc links, etc.
IF USED("RecoverDef")
  SELECT RecoverDef

  * Crossckeck header fieldnames with def file
  SCAN FOR RECNO("RecoverDef") < RECCOUNT("RecoverDef") && scan to last line to check if extra fields added after def file
    i = RECNO("RecoverDef")
    TempS = Rtrim0(GetString(DBFHandle, i*32, 10)) && file fieldname string
    TempC = GetString(DBFHandle, i*32+11, 1) && field type
    IF TempS != RTRIM(RecoverDef.Field_name) OR TempC != LEFT(RecoverDef.TYPE, 1)
      RheaderOK = .F.
      EXIT && terminate scan loop
    ENDIF
  ENDSCAN

  IF RheaderOK && check FirstRecPos
    GO BOTTOM
    IF GetValue(DBFHandle, 8, 2, 1) != VAL(RecoverDef.Dec)
      RheaderOK = .F.
    ENDIF
  ENDIF

  IF RheaderOK AND VFP AND !EMPTY(DBCFilePath) && check VFP attachment to .dbc
    * DBCFilePath was obtained from GetFileDefs()
    IF UPPER(DBCFilePath) != UPPER(GetString(DBFHandle, RECCOUNT("RecoverDef")*32+1, LEN(DBCFilePath)))
      RheaderOK = .F.
    ENDIF
  ENDIF

  * collect current autoinc info into sAutoInc
  DIMENSION sAutoInc[Reccount('RecoverDef') - 1, 2] && holds the autoinc info for each autoinc field - unless empty
  sAutoInc = ''
  TempNo2 = 0
  IF lAutoIncDBF && vfp8+ file with possible autoinc fields
    SCAN FOR SUBSTR(RecoverDef.TYPE, 5, 1) == 'a'
      *     sAutoInc[Recno('RecoverDef')]
      TempS=ALLT(RecoverDef.Field_name) + CHR(0) && + LEFT(UPPER(RecoverDef.TYPE),1) && Fieldname + FieldType
      TempS = IIF(LEN(TempS) > 10, LEFT(TempS, 10), TempS) && the 11th position for DB3M types is not allways CHR(0)
      TempNo = SrchFile(DBFHandle, TempNo2, RECCOUNT('RecoverDef')*32, TempS) && TempNo2 => must search sequentially
      IF TempNo > -1;
          AND GetString(DBFHandle, TempNo + 11, 1) = 'I';
          AND ANDD(ASC(GetString(DBFHandle, TempNo + 18, 1)), 12) = 12
        sAutoInc[Recno('RecoverDef'), 1] = GetString(DBFHandle, TempNo + 19, 5)
        sAutoInc[Recno('RecoverDef'), 2] = '12' && has correct field flag value
        TempNo2 = TempNo + 32 && start searching after this one
      ENDIF
      = CheckAutoInc(.T., .T.) && no errors/warnings yet
    ENDSCAN

    RheaderOK = RheaderOK AND (EMPTY(sAIerrFlds) OR !lFixAutoInc)

  ENDIF

ENDIF

ErrMsg = IIF(RheaderOK, ErrMsg, GM(14, "DBF header Error(s)!")+CRLF)

************* .DBF record error scan ********************
* Check record file data region corruption by scanning through
* records for 'ReCoVeR' or for proper delete mark OR field checks
* IF any record does not have 'ReCoVeR' in correct position, set RecordOK to .F.
PRIVATE i, N, TempS2, TempS3, RecErr, RecStr
TempS3 = ''
IF RScanLevel>0 AND GetFileDefs(.F.) = 0 AND LFoffset = 0
  PrevSec = SECONDS()
  RepMsg1 = GM(20, "Checking DBF file: record") + " "
  RepMsg2=''
  N = ActRecords && INT((FileLen-FirstRecPos)/RecordLen)
  RecErr=0
  LFSm = IIF(RtraceFlag AND rTraceM, .F., LFSm)
  =waitwin(GM(20, "Checking DBF file: record") + " 1")
  FOR i = 1 TO N
    =UserReport(i)
    RecStr = GetString(DBFHandle, FirstRecPos + (i-1)*RecordLen, RecordLen)
    TempS2 = RecVal(RecStr, .T., RScanLevel, .F.)
    IF LEN(TempS2) > 0 && at least an invalid delete flag
      RecordOK = .F.   && Eg TEMPS2 = "'CUSTOMER' field error."
      RecErr = RecErr+1
      * grab first error message only
      TempS3 = IIF(RecErr=1, GM(90, "Record") +" "+ ALLTR(STR(i)) +" "+TempS2 + CRLF, TempS3) && the error message
      *If only invalid delete flag, check if any bad fields
      IF LFSm AND RScanLevel<2
        LFSm = EMPTY(RecVal(STUFF(RecStr, 1, 1, ' '), .T., IIF(RScanLevel=3,3,2), .F.))
      ENDIF
      IF !LFSm OR (N<100 OR (N>99 AND RecErr/N>.01))
        * do not exit early if LFS possible - must check if more records allow LFSm
        LFSm = IIF((N>99 AND RecErr/N>0.01) OR (N<100 AND RecErr>1), .F., LFSm)
        EXIT
      ENDIF
    ENDIF
  ENDFOR
ENDIF
IF (LFoffset!=0 AND RScanLevel > 0) OR (!RepRHeadM AND !rTraceM AND !LFSm AND vFPSM)
  RecordOK = .F.
  TempS3 = GM(90, "Record") +" 1 " + GM(23, "field error") + "." + CRLF
ENDIF
IF !EMPTY(TempS3)
  ErrMsg = IIF(LEFT(ErrMsg, 1)=='.', TempS3, ErrMsg + TempS3)
ELSE
  IF USED("RecoverDef")
    ErrMsg = ErrMsg + GM(27, "DBF records appear OK! ")
  ENDIF
ENDIF
RELEASE i, N, TempS2, TempS3, RecStr
ErrFixes = Wmsg(1,ErrFixes, ErrMsg)
RecMsg = Wmsg(2, RecMsg, ErrMsg)
=waitwin("")

************** .DBF repair ******************
IF (!RheaderOK OR !RecordOK)
  RecovVal = -10 && this will change below if repaired
  IF (RepRHeadM OR rTraceM OR LFSm OR vFPSM) && header repair or salvage required/needed
    *** Get correct table definitions
    * Must be done before any repair/salvage called
    IF GetFileDefs(.T.) < 0
      RETURN -5*EndRecover(CRLF+GM(28, "File not recovered!")) && .DEF file not found
    ENDIF
    * repair header or salvage corrupted .dbf file
    RecovVal = IIF(!Rsalvage() AND !RepairH(), -10, +1)
  ELSE
  ENDIF
  * At this point its repaired or not repaired
  IF  RecovVal < 0 && return if not repaired but defective
    RecMsg = Wmsg(2,RecMsg,  GM(28, "File not recovered!"))
    RETURN RecovVal*EndRecover(CRLF+GM(28, "File not recovered!")) && File not recovered - see RECOVREP.TXT details
  ENDIF
ENDIF
* Note: At this point any rewrite salvage repairs are in (TempFile) - but original is in DBFfile

* remove cdx flag if no .cdx file - so at least it can be accessed
IF !FILE(CdxName) AND Bit(0,TableFlags)
  TableFlags = SetBit(0, TableFlags, .F.)
  =PutValue(IIF(TDBFHandle>0, TDBFHandle, DBFHandle), 28, TableFlags, 1, 1)
  ErrFixes=Wmsg(1,ErrFixes, CdxName+" " + GM(29, "not found - .CDX header flag reset!"))
ENDIF

*=FCLOSE(DBFHandle)
IF !EMPTY(TempFile) AND FILE(TempFile)
  =FCLOSE(DBFHandle)
  =FCLOSE(TDBFHandle)
  IF Parms>4 AND SaveOldRM
    ERASE ('RecovOld.dbf')
    RENAME (DBFfile) TO ('RecovOld.dbf')
    ErrFixes = Wmsg(1, ErrFixes, DBFfile + " " + GM(45, "saved as") + " "+FULLPATH("RecovOld.dbf")+".")
  ELSE
    ERASE (DBFfile)
  ENDIF
  RENAME (TempFile+'.') TO (DBFfile)
  DBFHandle = FOPEN(DBFfile,2)
ENDIF
*DBFHandle = FOPEN(DBFfile,2)

IF MemoCount = 0 && Memofile should not exist
  RecovVal = IIF(lAutoIncErr AND !lFixAutoInc AND RecovVal > -1, RecovVal - 0.5, RecovVal)&& reduce RecovVal if AI not fixed
  RETURN RecovVal*EndRecover('') && return here otherwise it might run into SaveExtraM below w/o memo file existing
ENDIF

***** Check/fix memo integrity, IF DBF header & records fixed and memo file exists
IF FILE(MemoFile) && memofile exists - moved here 03/04/04 - needed by SaveExtraM if only choice.
  MemoHandle = FOPEN(MemoFile, 2)
  TempNo = OK2GB(MemoFile, MemoHandle, Default0, " memo file '" + MemoFile + "' ")
  DO CASE
  CASE TempNo = 1 && over 2gb fixed here
    * do not scan memos first time
    MScanLevel = 0
    CheckMhdr  = .T.
    MScanLevel = 0
    RepMHead  = .T.
    mTraceM    = .F.
    SPMm       = .F.
    RepMptrsM  = .F.
    EmptyMemoM = .F.
    MheaderOK  = .F.
  CASE TempNo = 2 && over 2gb not fixed
    RETURN -11*EndRecover(GM(28, "File not recovered!"))
  ENDCASE && = 0 no fixing needed
  TMemoHandle = MemoHandle && set to 0 (as flag) if any memo not on mBlockSize bdry
  MemoLen=FSEEK(MemoHandle, -1, 2)+1
  IF !USED("RecoverDef") && extract mblocksize if no def file
    IF FileType = 131
      MBlockSize = 512
    ELSE
      MBlockSize = GetValue(MemoHandle, 6, 2, -1)
      MBlockSize = IIF(MBlockSize > 512 OR MBlockSize = 0 OR (MBlockSize < 33 AND !(MBlockSize = 1 AND VFP)), 64, MBlockSize) && use default 64 for very unusual block sizes
    ENDIF
  ENDIF
ENDIF

IF (CheckMhdr OR MScanLevel>0) AND RheaderOK AND RecordOK AND MemoCount>0 && memo file should exist
  ErrFixes = Wmsg(1, ErrFixes, CRLF + GM(47, "** Memofile:") + " " + CRLF)
  * check if memo file exists
  IF !FILE(MemoFile) && missing memo file - create one if permitted.
    MemoHandle=FCREATE(MemoFile)
    =WriteMemoH(MemoHandle, MBlockSize)
    IF !ResetMPointers()
      RETURN -5*EndRecover('')
    ENDIF
    ErrFixes=Wmsg(1, ErrFixes, GM(49, "Missing memofile replaced with empty."))
    RecMsg = Wmsg(2,   RecMsg, GM(49, "Missing memofile replaced with empty."))
    RETURN EndRecover('')
  ENDIF

  ************** memo header error detection **************
  ErrMsg = GM(50, "No memo errors found!")
  IF CheckMhdr && do memo header checks if allowed
    IF !FileType=131 && for foxpro files - not for DB3 memo file partial check
      * a.) check memo blocksize from memo file header
      TempNo3 = GetValue(MemoHandle, 6, 2, -1) && memo blocksize from file header
      IF USED("RecoverDef")
        MheaderOK = TempNo3=MBlockSize
      ELSE
        * requiring blocksize <=512 forces getting .DEF
        MheaderOK = (TempNo3>32 OR (VFP AND TempNo3=1)) AND TempNo3 < 513
      ENDIF
      * b.) check first block location
      IF MheaderOK AND !Alpha5
        MBlockSize = IIF(USED("RecoverDef"), MBlockSize, TempNo3)
        * first block number should be
        FirstBlock = CEILING(512/MBlockSize)

        IF MemoLen>FirstBlock*MBlockSize+8 && If there is at least one memo
          TempNo2=GetValue(MemoHandle, FirstBlock*MBlockSize, 4,-1)
          * first block loc must have  0<value<3 && 0=picture, 1=text, 2=general (but picture not used)
          MheaderOK = 0<TempNo2 AND TempNo2<3
        ENDIF
      ENDIF
    ENDIF
    * c) Checkif memolen size limits
    *-- check if at least 512 bytes long
    MheaderOK = MheaderOK AND MemoLen > 511

    TempNo3 = CEILING((MemoLen)/MBlockSize) && ideal NextFreeBlock number
    * get proper MemoLen
    IF TempNo3 > FirstBlock
      TempNo3 = TempNo3*MBlockSize
    ELSE
      TempNo3 = 512
    ENDIF

    MheaderOK = MheaderOK AND MemoLen == TempNo3
    MheaderOK = MheaderOK AND MemoLen + MBlockSize < 2^31

    * d.) check/adjust next free block location IF MheaderOK sofar
    =IIF(MheaderOK, NextBlockLoc(), .T.) && NextB.... adjusts MHeaderOk, and near 2GB, etc.
    ErrMsg = IIF(MheaderOK, ErrMsg, GM(51, "MemoHeader Error(s)!"))
  ENDIF

  ****************** Memo pointer error detection **********
  * check memo pointers - Sets MemoOk = .F. on first bad pointer
  IF MScanLevel>0 AND GetFileDefs(.F.) = 0 && DefFile must be open/exist for memoscans
    IF FileType=131 OR Alpha5
      MemoOk = MemoScan35()
    ELSE
      MemoOk = MemoScan(.T.) && MemoScan creates memolist info and checks for errors
    ENDIF
  ENDIF
  ErrFixes = Wmsg(1, ErrFixes, ErrMsg)
  RecMsg = Wmsg(2, RecMsg, ErrMsg)

ENDIF && IF MemoCount - end checking memofile

****************** Memo File repair ***************

IF !MheaderOK && memoheader errors
  RepairMH()
  RecovVal = 1
ENDIF

IF !MemoOk && Memofile pointer errors
  =waitwin(GM(54, "Repairing memo file!"))
  RecovVal = -11
  * attempt rebuild temp.fpt by
  * 1) finding first 0001 or 0002 and adding header.
  * 2) (a) trace memo salvage if used (b) SPM salvage
  * 3) creating an empty memo file so that .dbf can be accessed

  IF (mTraceM OR SPMm OR RepMptrsM OR EmptyMemoM OR SaveExtraM) AND GetFileDefs(.T.) < 0
    RETURN -5*EndRecover('')
  ENDIF

  IF mTraceM OR SPMm OR RepMptrsM OR EmptyMemoM OR SaveExtraM
    IF MSalv35() OR Msalvage(DBFHandle) OR EmptyMemo(MemoHandle, .T.)>0 && not repaired if one of them called
      RecovVal = 1
    ELSE
      RecovVal = -11
    ENDIF
    * At this point its repaired or not repaired
    IF RecovVal < 0
      RecMsg = Wmsg(2,RecMsg, GM(86, "MemoFile not recovered!"))
      RETURN RecovVal*EndRecover(CRLF+GM(86, "MemoFile not recovered!")) && Memo File not recovered - see RECOVREP.TXT details
    ENDIF
  ENDIF
ELSE
  IF SaveExtraM && allows extracting memos w/o SPM
    IF GetFileDefs(.T.) < 0
      RETURN -5*EndRecover('')
    ENDIF
    =Msalvage(DBFHandle)
  ENDIF
ENDIF

* reduce RecovVal if AI not fixed
RecovVal = IIF(lAutoIncErr AND !lFixAutoInc AND RecovVal > -1, RecovVal - 0.5, RecovVal)
RETURN RecovVal*EndRecover('')

*************
PROCEDURE NextBlockLoc
* checks/adjusts memofile next free block location
PRIVATE ActNextBloc, IndNextBloc, TempNo3, EofMark
*EofMark=IIF(GetValue(MemoHandle, MemoLen-1,1,1) = 26, 1, 0) && check if ^Z at end of file - 10/31/06 ^Z is only inside old type 131 file memos.

IndNextBloc = GetValue(MemoHandle, 0, 4, IIF(FileType=131, 1,-1))

ActNextBloc = CEILING((MemoLen)/MBlockSize)

IF (!USED("RecoverDef") OR FileType=131 OR Alpha5) AND (IndNextBloc!=ActNextBloc)
  IF RepMHead
    * fix the memo count for no def file or DB3 file with memos.
    ErrMsg = GM(56, "Memo file counter adjusted!")+CRLF
    =PutValue(MemoHandle, 0, ActNextBloc, 4, IIF(FileType=131, 1, -1))
    RecovVal = 1
    MheaderOK = .T. && no def file used - only simple repairs
  ELSE && memoheader repair not permitted
    RecovVal = -11
    MheaderOK = .F.
  ENDIF
ELSE
  MheaderOK = IndNextBloc=ActNextBloc && otherwise corruption requires .def file
ENDIF

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

****************
PROCEDURE Int2Byte
PARAMETER decm, nBytes, dirn
* Converts an integer number 'Decm', into a byte string, nBytes digits long
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
retval=IIF(dirn>0, PADR(retval, nBytes, CHR(0)), PADL(retval, nBytes, CHR(0)))
RETURN retval

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

FUNCTION ANDD
PARAMETERS A, B
* bitwise AND of numbers A and B
* Equivalent to VFP BITAND() - but used here for diff Recover editions.
PRIVATE ALL
IF INT(A)!=A OR INT(B)!=B
  =MESSAGEBOX("Binary ANDd error: arguments must be integers!", 0, "Recover Notice!")
  CANCEL
ENDIF
PRIVATE retval, HighOrd, i
retval = 0
HighOrd = MAX(INT(IIF(A>1, LOG(A)*1.442695041, 0)), INT(IIF(B>1, LOG(B)*1.442695041, 0)))
FOR i=0 TO HighOrd
  retval= retval+IIF(Bit(i, A) AND Bit(i,B), 2^i, 0)
ENDFOR
RETURN retval


**************
PROCEDURE GetValue
* Gets integer value from N bytes at file location FileLoc
PARAMETER FileHandle, fileloc, nBytes, dirn
=FSEEK(FileHandle, fileloc)
RETURN Byte2Int(FREAD(FileHandle, nBytes), dirn)

**************
PROCEDURE PutValue
* Converts 'Intgr' value to N bytes and writes it at location FileLoc
* Returns number of bytes written
PARAMETER FileHandle, fileloc, Intgr, nBytes, dirn
=FSEEK(FileHandle, fileloc)
RETURN FWRITE(FileHandle, Int2Byte(Intgr, nBytes, dirn))

*-------------------
PROCEDURE GetSValue
* Gets numeric signed integer value from nBytes at FileLoc
PARAMETER FileHandle, fileloc, nBytes, dirn
PRIVATE ALL
=FSEEK(FileHandle, fileloc)
*Intgr = Byte2Int(FREAD(FileHandle, nBytes), dirn)
*Return IIF(Intgr > 256^nBytes/2 - 1, Intgr - 256^nBytes, Intgr)
RETURN SByte2Int(FREAD(FileHandle, nBytes), nBytes, dirn)

PROCEDURE SByte2Int
* converts a signed byte string to integer
PARAMETER ByteString, nBytes, dirn
PRIVATE ALL
Intgr = Byte2Int(ByteString, dirn)
RETURN IIF(Intgr > 256^nBytes/2 - 1, Intgr - 256^nBytes, Intgr)

*------------------
PROCEDURE PutSValue
* Converts Intgr value to nBytes signed bytes and writes it to FileLoc
* signature calculated using nBytes count
PARAMETER FileHandle, fileloc, Intgr, nBytes, dirn
=FSEEK(FileHandle, fileloc)
RETURN FWRITE(FileHandle, Int2SByte(Intgr, nBytes, dirn))

PROCEDURE Int2SByte
* converts an integer to a signed byte string
* signature calculated using nBytes count
PARAMETERS Intgr, nBytes, dirn
PRIVATE ALL
IF ABS(Intgr) > 256^nBytes / 2 - 1
  =MESSAGEBOX("Int2SByte invalid integer error - Quiting.", 0, "Recover error.")
  CANCEL
ENDIF
Intgr = IIF(Intgr < 0, 256^nBytes + Intgr, Intgr)
RETURN Int2Byte(Intgr, nBytes, dirn)

*************
PROCEDURE GetString
* reads Nbytes long string at FileLoc
PARAMETERS FileHandle, fileloc, nBytes
=FSEEK(FileHandle, fileloc)
RETURN FREAD(FileHandle, nBytes)

************
PROCEDURE PutString
* Writes xString at FileLoc
PARAMETERS FileHandle, fileloc, xString
=FSEEK(FileHandle, fileloc)
RETURN FWRITE(FileHandle, xString) && returns number of bytes writen

********************
PROCEDURE WriteHeader
PARAMETER FileHandle
* Writes a .dbf header to FileHandle file using .def definition file info.
* AND adjusts size and writes EofMark

PRIVATE TempNo, TempS
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
EofMark = IIF(FileLen > FirstRecPos + 1, 1, 0) && ^Z not used for empty files

=PutValue(FileHandle, 4, ActRecords, 4,1)

* above may affect FileLen
FileLen = ActRecords*RecordLen + EofMark + FirstRecPos

* Write Position of first data record : 8-9
=PutValue(FileHandle, 8, FirstRecPos, 2,1)

* Write Length of data record : 10-11
=PutValue(FileHandle, 10, RecordLen, 2, 1)

* write cdx/(VFP memo/DCB) flags : 28
=PutValue(FileHandle, 28, TableFlags, 1, 1)

* write code page mark : 29
=PutValue(FileHandle, 29, nCodePage, 1, 1)

* Rewrite Field definition subRecords
=FSEEK(FileHandle, 32)

* Reconstruct field subRecords in header
TempNo=1
SELECT RecoverDef
PRIVATE EmptyAImsgs
EmptyAImsgs = EMPTY(sAutoIncWrngs + sAIerrFlds) && if no wargnings or error messages
SCAN FOR RECNO()<RECCOUNT()
  TempS=PADR(ALLT(RecoverDef.Field_name),11,CHR(0))+LEFT(LEFT(RecoverDef.TYPE,1),1) && name and type
  TempS=TempS+IIF(Alpha5, PictType, Int2Byte(TempNo,4,1)) && displacement of field in rec or 0000 if Alpha5
  TempS=TempS+Int2Byte(VAL(RecoverDef.WIDTH),1,1)           && width
  TempS=TempS+Int2Byte(VAL(RecoverDef.Dec),1,1)             && decimals
  TempS=TempS+Int2Byte(VAL(SUBSTR(RecoverDef.TYPE, 2, 3)), 1, 1) && VFP field flags - 0 otherwise
  IF lAutoIncDBF AND SUBSTR(RecoverDef.TYPE, 5, 1) = 'a' && an autoinc field
    TempS = TempS + CheckAutoInc(.F., EmptyAImsgs) + REPLICATE(CHR(0), 8) && autoinc bytes + trailing 0's
  ELSE && not an autoinc field
    TempS = TempS + REPLICATE(CHR(0), 13) && just 0's
  ENDIF

  =FWRITE(FileHandle, TempS , 32)
  TempNo=TempNo+VAL(RecoverDef.WIDTH)
ENDSCAN

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
RheaderOK = .T. && now fixed

*****************
PROCEDURE RepairH
* Repairs the table header by re-writing over it
* LFOK Requires definition file
TempS = ''
IF RheaderOK OR !RepRHeadM OR (LFoffset!=0 AND RScanLevel > 0) && do not repair header if records are offset.
  RETURN .F.
ENDIF

** header repair permitted, last field definition is in place - now rewrite header to normal
=WriteHeader(DBFHandle)
ErrFixes = Wmsg(1,ErrFixes, GM(19, "Header repaired!"))
RecMsg   = Wmsg(2,RecMsg,   GM(19, "Header repaired!"))

*------------
PROCEDURE CheckAutoInc
* checks and/or repairs an autoinc field (pointed to by RecoverDef)
* returns sCurNextVal + sCurStep for header reconstruction
* or ignored for initial check
PARAMETER lCheckOnly, MTErrMsg && T, T for initial check, F, T/F in header reconstruction

PRIVATE  sCurNextVal, nCurNextVal, sCurStep, nCurStep, sOldNextVal, nOldNextVal, sOldStep, nOldStep
sCurNextVal = SUBSTR(sAutoInc[Recno('RecoverDef'), 1], 1, 4) && current next value string
nCurNextVal = SByte2Int(sCurNextVal, 4, 1) && its numeric value
sCurStep = SUBSTR(sAutoInc[Recno('RecoverDef'), 1], 5, 1) && current step value string
nCurStep = ASC(sCurStep) && its numeric value
sOldNextVal = SUBSTR(RecoverDef.TYPE, 6, 4) && archived next value string
nOldNextVal = SByte2Int(sOldNextVal, 4, 1)
sOldStep = SUBSTR(RecoverDef.TYPE, 10, 1) && archived next value step
nOldStep = ASC(sOldStep)
DO CASE
CASE sAutoInc[Recno('RecoverDef'), 2] != '12' OR nCurStep = 0;
    OR nCurNextVal < nOldNextVal OR nCurStep != nOldStep
  * this is probably a corrupt or invalid field subrecord - replace with archived values
  * generate "Invalid or corrupt autoinc values" message - return RecovVal = +2
  IF lFixAutoInc AND !lCheckOnly && replace bad values
    sCurStep = sOldStep
    sCurNextVal = sBestAInext(FileHandle, FirstRecPos, RecordLen)
    IF SByte2Int(sCurNextVal, 4, 1) < SByte2Int(SUBSTR(RecoverDef.TYPE, 6, 4), 4, 1)
      * if the scanned sBestAInext... is less than archived use archived
      sCurNextVal = SUBSTR(RecoverDef.TYPE, 6, 4)
    ENDIF
    nCurNextVal = SByte2Int(sCurNextVal, 4, 1)
    nCurStep = ASC(sCurStep)
    DO WHILE nCurNextVal + 2*nCurStep > 256^4/2 -1 && reduce to at least readable current NextVal
      nCurNextVal = nCurNextVal - nCurStep
    ENDDO
    sCurNextVal = Int2SByte(nCurNextVal, 4, 1)
    IF nCurNextVal + nCurStep => 256^4/2 -1 && the correction may have reached NextVal limit
      sAutoIncWrngs = sAutoIncWrngs + CRLF + ALLT(RecoverDef.Field_name) + " " + GM(94, "field autoinc NextVal limit reached! <= Warning")
    ENDIF
  ENDIF
  lAutoIncErr = .T.
  IF MTErrMsg
    sAIerrFlds = sAIerrFlds + ALLT(RecoverDef.Field_name) + " "
  ENDIF
CASE nCurNextVal + nCurStep => 256^4/2 -1
  * generate "FieldName autoinc limit reached" warning message - return RecovVal = +2
  IF MTErrMsg
    sAutoIncWrngs = sAutoIncWrngs + CRLF + ALLT(RecoverDef.Field_name) + " " + GM(94, "field autoinc NextVal limit reached! <= Warning")
  ENDIF
ENDCASE

RETURN sCurNextVal + sCurStep

*------------
PROCEDURE sBestAInext
* searches the data file for best autoinc NextVal
PARAMETERS FileHandle, FirstRecPos, RecordLen
PRIVATE OriginalPos, CurRec, nPosInRec, sNewNextVal, sBestNextVal, i

OriginalPos = FSEEK(FileHandle, 0, 1) && save current file pointer
CurRec = RECNO() && alias should be RecoverDef
SUM VAL(WIDTH) FOR RECNO() < CurRec TO nPosInRec
nPosInRec = nPosInRec + 1
GO CurRec

= FSEEK(FileHandle, FirstRecPos + nPosInRec)
sNewNextVal = LEFT(FREAD(FileHandle, RecordLen), 4)
sBestNextVal = sNewNextVal
i = 0
RepMsg1 = "AutoInc +?- "
RepMsg2 = ""

DO WHILE LEN(sNewNextVal) = 4 && !FEOF(FileHandle) and
  sBestNextVal = IIF(SByte2Int(sNewNextVal, 4, 1) => SByte2Int(sBestNextVal, 4, 1),;
    Int2SByte(SByte2Int(sNewNextVal, 4, 1) + nOldStep, 4, 1),;
    sBestNextVal)
  sNewNextVal = LEFT(FREAD(FileHandle, RecordLen), 4)
  i = i + 1
  =UserReport(i)
ENDDO
=waitwin()
* Return to original file pointers
GO CurRec && alias is RecoverDef
=FSEEK(FileHandle, OriginalPos)

RETURN sBestNextVal

*--------------------
PROCEDURE OK2GB
PARAMETERS FileName, FileHandle, Default0, RecMemFile
PRIVATE FileArr, CRLF, xFileLen
CRLF = CHR(13) + CHR(10)
DIMENSION FileArr[1,5]
=ADIR(FileArr, FileName) && get file details to FileArr
xFileLen=FileArr[1,2]
RELEASE FileArr
xFileLen = IIF (xFileLen < 0, 2^32 + xFileLen, xFileLen) && ADIR may indicate -ve FileLen in older fox versions for 2gb+ files
DO CASE
CASE xFileLen > 2147483647 AND "Visual" $ VERSION()
  IF MESSAGEBOX("The" + RecMemFile + "size is beyond 2GB limit. ";
      + "It can be fixed by trimming size to below 2GB and correcting header counter bytes. ";
      + "After size/counter adjustment you can try to view the file and then error-scan/repair if needed (may take long time).";
      + CHR(13) + CHR(10) + CHR(13) + CHR(10) + " Do you want to trim the file now?", 4, "2GB+ file size warning.") = 6 && yes
    xFileLen=FCHSIZE(FileHandle, 2^31 - 1) && this will change to -1 byte below limit (and allow EOF mark - skip)
    =FFLUSH(FileHandle) && make sure of proper access after mods
    RETURN 1
  ELSE && exit requested
    RETURN 2
  ENDIF
CASE  xFileLen > 2147483647 && Fox2.X editions
  =MESSAGEBOX("The" + RecMemFile + "is beyond 2GB limit.";
    + " You first need to trim the file size to below 2GB with" + CHR(13) + CHR(10);
    + "RECOVLCK " + FileName + CHR(13) + CHR(10);
    + "in DOS or in Windows RUN and then run repair again.", 0, "Foxpro 2.X, 2GB+ file size warning.")
  RETURN 2
ENDCASE

RETURN 0 && no adjustments needed

********************
PROCEDURE Rsalvage
* salvages Records from a fragmented file by:
* 1) last field definition subrecord can be found and file reconstruced from rest
* 2) uses tracers to locate records
* 3) calls locatef browsing screen for user locating good file blocks

IF RecordOK OR (!rTraceM AND !LFSm AND !vFPSM)  && No salvage option
  RETURN .F.
ENDIF

PRIVATE i, TempS, TempNo, TempNo2, recnum, SalvageMsg, SalvageFlag
SalvageFlag = .F.
SELECT RecoverDef
GO TOP

SalvageMsg = GM(42, "No .DBF salvage methods used!")+CRLF
* Check for trace method if allowed
IF rTraceM AND FldProp[1,1] == 'R_TRACE_  '
  SalvageFlag = .T.
  ** trace method  - Does not use _RecoverPc
  SalvageMsg = GM(31, "Trace method")+':'+CRLF
  PrevSec = SECONDS()
  RepMsg1 = GM(31, "Trace method")+" " +GM(30, "recovering records")+ " - "
  RepMsg2 = ""

  TempNo = SrchFile(DBFHandle, 0, FileLen, 'ReCoVeR')
  IF TempNo > -1
    i=0
    =SalvInit()
    DO WHILE TempNo>-1
      i = i + 1
      =FSEEK(DBFHandle, TempNo-1)
      TempS = FREAD(DBFHandle, RecordLen)
      * check delete flag - replace with space if not * or ' '
      TempS = IIF(AT(LEFT(TempS, 1), DelChar)==0, STUFF(TempS, 1, 1, ' '), TempS)
      =FWRITE(TDBFHandle, TempS)
      TempNo=SrchFile(DBFHandle, TempNo+RecordLen, FileLen, 'ReCoVeR')
    ENDDO
    =SalvTerm(i)
  ENDIF
ENDIF

* Use LastFielDefSearch method if allowed
IF LFSm AND !RecordOK
  SalvageFlag = .T.
  SalvageMsg = GM(32, "Last field def search")+":"+CRLF
  * Use (unique name) cursor for salvaged pieces start/ends - needed for VFP
  CREATE CURSOR _RecoverPc (xFrom N(10), xTo N(10))
  TempNo = FirstRecPos + LFoffset && assumed starting pos of actual first record.
  IF FileLen - (TempNo +1) > .5*RecordLen && salvage at least half record
    * Write location of first and last complete record to _RecoverPc
    INSERT INTO _RecoverPc VALUES(TempNo, TempNo+(INT((FileEnd+1 - TempNo)/RecordLen) -1)*RecordLen)
    IF !SalvPieces(.F.) && .F. => not vFPS
      =FCLOSE(TDBFHandle)
      ERASE (TempFile)
      TDBFHandle = 0
    ENDIF
  ELSE && no records exist - just empty damaged file
    =SalvInit()
    =SalvTerm(0)
    vFPSM = .F. && fixed but 0 records salvaged - do not continue into BrowseM
  ENDIF
  USE IN _RecoverPc
ENDIF

* Use vFPS (visual File Salvage Screen) if allowed
IF vFPSM AND !RecordOK
  ?? CHR(7)
  WAIT WINDOW ErrMsg + "Press any key/mouse to continue..."
  ** vFPS
  CREATE CURSOR _RecoverPc (xFrom N(10), xTo N(10))
  SalvageMsg = GM(35, "vFPS method")+":"+CRLF
  IF VFP AND ATC("VFP", CpRt)=0
    =MESSAGEBOX("Visual file pieces salvage screen on Visual FoxPro files requires the VFP edition of Recover.", 0, "Notice")
  ELSE
    IF WEXIST("Recovers")
      HIDE WINDOW Recovers
    ENDIF
    =Bsalvage()
    IF WEXIST("Recovers")
      SHOW WINDOW Recovers
    ENDIF
  ENDIF
  TimeElapsed = -1 && turn off elapsed time indicator for browse screen
  SalvageFlag = SalvPieces(.T.) && vFPS signal
  USE IN _RecoverPc
ENDIF

ErrFixes = Wmsg(1, ErrFixes, SalvageMsg)

RETURN SalvageFlag && RecordOK except possibly from vFPS

*************
PROCEDURE SalvInit
* create temporary filename to hold recovered pieces
IF TDBFHandle == 0
  TempFile   = SYS(3)
  TDBFHandle = FCREATE(TempFile)
ELSE
  =FSEEK(TDBFHandle, 0)
ENDIF
* Leave HEADER-SPACE for tempfile
TempS = REPLICATE(CHR(0), 32*RECCOUNT('RecoverDef')) + CHR(13) +IIF(VFP, REPLICATE(CHR(0), 263), '')
* make sure that header space is correct for extra Clipper/dbase/alpha5 files.
IF LEN(TempS) < FirstRecPos
  TempS = TempS + REPLICATE(CHR(0), FirstRecPos-LEN(TempS))
ENDIF
=FWRITE(TDBFHandle, TempS)
* chr(13) = header record terminator

*******************
PROCEDURE SalvTerm
PARAMETER i, SetToZeroRecs
SalvageMsg=SalvageMsg+ALLT(STR(i))+' ' + GM(38, "records recovered.")+CRLF+'Please inspect records!'+CRLF
RecMsg = Wmsg(2,RecMsg, ALLT(STR(i))+' '+GM(38, "records recovered."))
IF i>0
  * write header
  ActRecords = i
  EofMark=1
  FileLen = FirstRecPos + ActRecords*RecordLen + EofMark && needed for WriteHeader
  =WriteHeader(TDBFHandle)
  RecordOK = .T. && fixed what can be fixed
ELSE && no records recovered in current salvage method
  SalvageMsg = GM(33, "No records exist - header reconstructed!") + CRLF
  =FCLOSE(TDBFHandle)
  ERASE (TempFile)
  TDBFHandle = 0
  ActRecords = 0
  FileLen = FirstRecPos
  =WriteHeader(DBFHandle)
ENDIF
=waitwin()
RETURN i>0

*******************
PROCEDURE SalvPieces
* recover records from LastFieldDefSearch or vFPS
PARAMETER vFPSFlag
PrevSec = SECONDS()
RepMsg1 =;
  IIF(vFPSFlag, GM(35, "vFPS method"), GM(32, "Last field def search"));
  +" " +GM(30, "recovering records")+ " - "
RepMsg2 = ""
=waitwin(RepMsg1)
IF RECCOUNT("_RecoverPc") > 0
  PRIVATE i, TempNo, TempS, recnum,  FilePos
  i=0 && recovered record counter
  SELECT _RecoverPc && recover pieces if any.
  =SalvInit()
  SCAN && get each good block
    FilePos = xFrom
    =FSEEK(DBFHandle, FilePos)
    DO WHILE FilePos <= xTo
      TempS=FREAD(DBFHandle, RecordLen)
      i = i + 1
      =UserReport(i)
      * remove any illegal delete flags IF LFOK() and rest of record OK
      IF AT(LEFT(TempS, 1), DelChar)==0 && illegal delete flag
        IF EMPTY(RecVal(STUFF(TempS, 1, 1, ' '), .T., RScanLevel, .F.)) && rest of record OK
          TempS = STUFF(TempS, 1, 1, ' ')
        ELSE && bad rest of record - stop if LFS method
          IF !vFPSFlag && LFS method
            RETURN .F.
          ENDIF
        ENDIF
      ENDIF
      =FWRITE(TDBFHandle, TempS) && write the record to new file
      FilePos = FilePos + RecordLen
    ENDDO
  ENDSCAN
  RETURN SalvTerm(i)
ELSE
  SalvageMsg = SalvageMsg + IIF(vFPSFlag, GM(36, "vFPS method cancel requested!") + CRLF,"")
  RecMsg = IIF( vFPSFlag, Wmsg(2,RecMsg, GM(36, "vFPS method cancel requested!")), RecMsg)
  RETURN .F. && nothing salvaged
ENDIF
*************
PROCEDURE EndRecover
PARAMETER ErrMsgs
* closes files, cleanup, etc before exit.
=waitwin()
=FCLOSE(DBFHandle)
=FCLOSE(MemoHandle)
* SET SAFETY OFF
IF !EMPTY(TmemoFile) AND FILE(TmemoFile)
  =FCLOSE(TMemoHandle)
  IF Parms>4 AND SaveOldRM
    ERASE (IIF(FileType=131,'RecovOld.dbt','RecovOld.fpt'))
    RENAME (MemoFile) TO (IIF(FileType=131,'RecovOld.dbt','RecovOld.fpt'))
    ErrFixes = Wmsg(1, ErrFixes, MemoFile + " "+GM(45, "saved as")+" "+FULLPATH("RecovOld.fpt")+".")
  ELSE && do not save old memo file in copy type salvage
    ERASE (MemoFile)
  ENDIF
  RENAME (TmemoFile+'.') TO (MemoFile)
ENDIF

*------ AutoInc messages composition (AMC)
*Warnings
IF !EMPTY(sAutoIncWrngs)
  ErrFixes = Wmsg(1, ErrFixes, sAutoIncWrngs + CRLF) && sAutoIncWrngs generated in WriteHeader
  RecMsg   = Wmsg(2, RecMsg,   sAutoIncWrngs + CRLF)
ENDIF

* Errors or fixed
IF lAutoIncErr AND !EMPTY(sAIerrFlds)
  ErrFixes = Wmsg(1, ErrFixes, sAIerrFlds;
    + IIF(lFixAutoInc, GM(95, "AutoInc fields header adjusted!"),GM(96, "AutoInc fields header errors!")) + CRLF )
  RecMsg   = Wmsg(2, RecMsg,   ;
    + IIF(lFixAutoInc, GM(95, "AutoInc fields header adjusted!"),GM(96, "AutoInc fields header errors!")) + CRLF )
ENDIF
*------ (AMC)

* SET SAFETY ON
TempS=ErrFixes+ErrMsgs
RecMsg = Wmsg(2, RecMsg, GM(88, "Further details in text file RECOVREP.TXT."))
RecMsg = Wmsg(2, RecMsg, IIF(TimeElapsed>-1,"("+ALLT(STR(SECONDS()-TimeElapsed,10,2)) + " seconds!)",""))
TempS = TempS;
  + IIF(TimeElapsed>-1, + CRLF+ALLT(STR(SECONDS()-TimeElapsed,10,2)) + " "+"seconds.","")
=MB(RecMsg, "Recover: "+ DBFleft+".DBF/.FPT", 0, 0) && final message

* write final report piece to RECOVREP.TXT
=Append2Log(TempS+CRLF, .T.)
=RestoreDefs() && restore default environment
RETURN 1

***************
PROCEDURE RepairMH
* Repairs Memo header by rewriting a new one over it
* This uses original memo
IF !RepMHead && repair memo header if allowed and bad
  RETURN .F.
ENDIF
=WriteMemoH(MemoHandle, MBlockSize)
ErrFixes = Wmsg(1, ErrFixes, GM(85, "MemoHeader repaired!")+CRLF)
RecMsg   = Wmsg(2, RecMsg,   GM(85, "MemoHeader repaired!"))
MheaderOK = .T. && should be OK now

****************
PROCEDURE GetRec
PARAMETER Thandle, recnum
* Retrieves record Recnum RecordLen bytes (string)
=FSEEK(Thandle, FirstRecPos + (recnum-1)*RecordLen)

RETURN FREAD(Thandle, RecordLen)

*********
PROCEDURE PutRec
PARAMETER Thandle, recnum, RString
* Writes Rstring to record Recnum
=FSEEK(Thandle, FirstRecPos + (recnum-1)*RecordLen)
RETURN FWRITE(Thandle, RString, RecordLen)

****************
PROCEDURE WriteMemoH
PARAMETER MHandle, MBlockSize
* Writes a memo header
* Calculates next block pos from file size - use after creating block
PRIVATE TempS, FirstBlock, NextFreeBlock, MemoEnd, mBSize, TempNo2
mBSize = IIF(FileType=131, 512, MBlockSize)
FirstBlock = CEILING(512/mBSize)
MemoEnd=FSEEK(MHandle, -1, 2) && check if memofile has any size now - memoend counted from byte 0
MemoEnd=IIF(MemoEnd < 511, 511, MemoEnd) && should be at least 512 bytes long

*TempNo2 = MAX(INT((MemoEnd+1)/MBlockSize)*MBlockSize, 512) && the ideal memolen
TempNo2 = MAX(Ceiling((MemoEnd+1)/MBlockSize)*MBlockSize, 512) && the ideal memolen - changed 2008/02/25 - for possible partial eof memoblock

IF MemoEnd+1 + MBlockSize > 2^31 - 1 && check for near 2GB limit - need room for nextfreeblock
  TempNo2 = TempNo2 - MBlockSize
ENDIF
MemoEnd = TempNo2 - 1

NextFreeBlock = CEILING((MemoEnd+1)/mBSize)

* Write mheader contents - BlockSize & FirstBlockAddress & binary 0's for rest
TempS=Int2Byte(NextFreeBlock, 4, IIF(FileType=131,1,-1));
  +CHR(0)+CHR(0);
  +Int2Byte(mBSize, 2, -1);
  +REPLICATE(CHR(0), FirstBlock*mBSize-8)
=PutString(MHandle, 0, TempS)

IF NextFreeBlock > FirstBlock
  MemoLen = NextFreeBlock*mBSize
ELSE
  MemoLen = 512
ENDIF

=FCHSIZE(MHandle, MemoLen) &&

IF FileType!=131 AND NextFreeBlock > FirstBlock && this should have a memo
  * check if first block has valid 8 bytes and change to 1 byte memo signal if not
  * else it will give false signal next time and force memo salvage
  TempNo2=GetValue(MHandle, FirstBlock*MBlockSize, 4, -1)
  IF TempNo2 =0 OR TempNo2 > 2
    =PutValue(MHandle, FirstBlock*mBSize, 1, 4, -1)
    =PutValue(MHandle, FirstBlock*mBSize+4, 1, 4, -1)
  ENDIF
ENDIF
RETURN NextFreeBlock

************
PROCEDURE EmptyMemo
* Replaces memo file with one with 0 memos
PARAMETER MHandle, EMmsg
IF PARAMETERS()>1
  IF !EmptyMemoM && memo emptying excluded (no memo pointer repair)
    RETURN 0
  ENDIF
  ErrFixes = Wmsg(1, ErrFixes, GM(83, "Memo file set to 0 memos!")+CRLF)
  =ResetMPointers() && this requires .DEF but which should be open by now
ENDIF

=FCHSIZE(MHandle,0)

RETURN WriteMemoH(MHandle, MBlockSize) && returns the next free block number

*****************************
PROCEDURE waitwin
* General 'Wait message....' window
* wmsg contents prints the message
* Window is released if wmsg is empty
PARAMETER Wmsg
IF !ShowProgrM
  RETURN
ENDIF
IF NOT WEXIST("waitwin")
  IF EMPTY(Wmsg)
    RETURN
  ENDIF
  DEFINE WINDOW waitwin ;
    AT  0.000, 0.000  ;
    SIZE IIF(_DOS, 3.00, 4.154),IIF(_DOS, 75, 90.00) ;
    FONT "MS Sans Serif", 8 ;
    NOFLOAT ;
    NOCLOSE ;
    NOMINIMIZE
  MOVE WINDOW waitwin CENTER
ELSE	&& already exists
  IF EMPTY(Wmsg)
    RELEASE WINDOW waitwin
    RETURN
  ENDIF
ENDIF
ACTIVATE WINDOW waitwin

IF _DOS
  @ 1,2 SAY Wmsg ;
    SIZE 1.000,65.000 ;
    STYLE "B" ;
    PICTURE "@I"
ELSE
  @ 1.462,0.200 SAY Wmsg ;
    SIZE 1.000,IIF(_MAC, 64.0, 56.0) ;
    FONT (MsgFont), 10 ;
    STYLE "B" ;
    PICTURE "@I" ;
    COLOR RGB(,,,255,255,255)
ENDIF
RETURN

*******************
PROCEDURE ResetMPointers
* reset all memo flags in main file or just illegal ones.
* Requires DEF file - or will just return
IF !RepMptrsM && exclude repairing pointers (=>removing bad pointers)
  RETURN .T.
ENDIF
IF GetFileDefs(.F.) < 0
  RETURN .F.
ENDIF
PRIVATE i, j, TempNo, MPerror

=waitwin(GM(48, "Removing invalid memo pointers. Please Wait..."))

FOR i = 1 TO ActRecords
  FOR j = 1 TO MemoCount
    =SetMPointer(DBFHandle, i, MemProp[j, 1], 0)
  ENDFOR
ENDFOR
RETURN

********************
PROCEDURE MemoScan35
* detects DB3 & Alpha5 invalid memo pointer errors.
PRIVATE TempNo, PrevBlock, PrevSpan, Block1, Fname1, PrevRec, CurRec, TempS, Recn1

SELECT 0
CREATE CURSOR _RecoverTf (RECN N(10), MemNo N(3), BlockNo N(10), Span N(10), STATUS C(1))
INDEX ON BlockNo TAG BlockNo
* check for illegal pointers
=waitwin(GM(52, "Memo scan level") +" 1")
FOR i = 1 TO ActRecords
  FOR j = 1 TO MemoCount
    TempNo = GetMPointer(DBFHandle, i, MemProp[j, 1])
    IF TempNo > 0 && non-zero pointer
      INSERT INTO _RecoverTf VALUES(i, j, TempNo, 0, '')
      IF Alpha5
        TempNo2 = GetValue(MemoHandle, TempNo*MBlockSize, 4, -1)
        REPLACE _RecoverTf.Span WITH TempNo2
      ELSE && DB3
        TempNo2 = SrchFile(MemoHandle, TempNo*MBlockSize, MemoLen, CHR(26)) && look for end of text marker
        REPLACE _RecoverTf.Span WITH CEILING(TempNo2/MBlockSize) - TempNo
      ENDIF
      IF TempNo2 < 0 OR TempNo < 1;
          OR TempNo*MBlockSize < 512;
          OR TempNo*MBlockSize + _RecoverTf.Span*MBlockSize > MemoLen && illegal pointer
        IF !RepMptrsM && scan allowed but memo pointer repair not allowed - return error message
          RETURN ErrMsgDB3(i,j)
        ENDIF
        REPLACE _RecoverTf.STATUS WITH 'I' && 'I'llegal
      ENDIF
    ENDIF
  ENDFOR
ENDFOR

IF MScanLevel>1 && check for crosslinked and overlaping pointers
  COUNT FOR EMPTY(_RecoverTf.STATUS) TO TempNo
  IF TempNo > 1
    =waitwin(GM(52, "Memo scan level") +" 2 - A")
    GO TOP
    Block1 = _RecoverTf.BlockNo
    PrevBlock = _RecoverTf.BlockNo
    Recn1 = RECNO()
    PrevRec = _RecoverTf.RECN
    Fname1 = MemProp[_RecoverTf.MemNo,3]
    SCAN FOR EMPTY(_RecoverTf.STATUS) AND RECNO()!=Recn1
      IF BlockNo = PrevBlock && crosslink exists
        IF !RepMptrsM
          RETURN ErrMsgDB3(_RecoverTf.RECN,_RecoverTf.MemoNo)
        ENDIF
        REPLACE _RecoverTf.STATUS WITH 'C' && 'C'rosslinked
      ELSE
        PrevBlock = _RecoverTf.BlockNo
        PrevRec = _RecoverTf.RECN
        Fname1 = MemProp[_RecoverTf.MemNo,3]
      ENDIF
    ENDSCAN
  ENDIF

  * check for overlaping pointers
  COUNT FOR EMPTY(STATUS) TO TempNo
  IF TempNo > 1
    =waitwin(GM(52, "Memo scan level") +" 2 - A")
    GO TOP
    Recn1 = RECNO()
    Block1 = _RecoverTf.BlockNo
    PrevBlock = _RecoverTf.BlockNo
    PrevRec = RECNO()
    PrevSpan = _RecoverTf.Span
    SCAN FOR EMPTY(STATUS) AND RECNO()!=Recn1
      IF PrevBlock+PrevSpan > BlockNo
        IF !RepMptrsM
          RETURN ErrMsgDB3(_RecoverTf.RECN, _RecoverTf.MemoNo)
        ENDIF
        CurRec = RECNO()
        GO PrevRec
        REPLACE _RecoverTf.STATUS WITH 'I' && overlaping is illegal
        GO CurRec
      ENDIF
      PrevBlock = _RecoverTf.BlockNo
      PrevRec = RECNO()
      PrevSpan = _RecoverTf.Span
    ENDSCAN
    * check last span if over file length
    GO BOTTOM
    IF (_RecoverTf.BlockNo+_RecoverTf.Span)*MBlockSize > MemoLen
      IF !RepMptrsM
        RETURN ErrMsgDB3(_RecoverTf.RECN,_RecoverTf.MemoNo)
      ENDIF
      REPLACE _RecoverTf.STATUS WITH 'I'
    ENDIF
  ENDIF
ENDIF
retval = .T. && no errors
IF RepMptrsM && if to be fixed
  COUNT FOR EMPTY(_RecoverTf.STATUS) TO TempNo
  IF TempNo = RECCOUNT() && nothing to fix
    USE IN _RecoverTf
  ELSE
    ErrMsg = GM(53, "Memo pointer error!")
    GO TOP IN _RecoverTf
    retval = .F.
  ENDIF
ELSE && no repairs done
  USE IN _RecoverTf
ENDIF
=waitwin()
RETURN retval

***
PROCEDURE ErrMsgDB3
PARAMETER RecNm, MemNm
ErrMsg = GM(90, "Record")+" " + ALLT(STR(RecNm))+ ", '" + ALLT(MemProp[MemNm, 3]) + "' " + GM(53, "memo pointer error!") +CRLF
USE IN _RecoverTf
=waitwin()
RETURN .F.

****
PROCEDURE MSalv35
* corrects DB3 & Alpha5 invalid memo pointers. _RecoverTf already has relevant memo/pointer info
IF (FileType!=131 AND !Alpha5) OR !USED("_RecoverTf") OR !RepMptrsM OR MScanLevel=0
  RETURN .F.
ENDIF
PRIVATE FirstMis, LastMis, FirstLink, TempNo, Fname1, PrevRec, TempS
FirstMis = .T.
LastMis = .F.
FirstLink = .T.

=waitwin(GM(54, "Repairing memo file!") + "......." )
* remove/report invalid pointers
SELECT _RecoverTf
SCAN FOR _RecoverTf.STATUS = 'I' && invalid
  =RepMissing(MemProp[_RecoverTf.MemNo, 3], _RecoverTf.RECN) && report invalid
  =SetMPointer(DBFHandle, _RecoverTf.RECN, MemProp[_RecoverTf.MemNo, 1], 0) && set memo pointer to 0
ENDSCAN

* remove/report crosslinked
GO TOP
PrevRec = _RecoverTf.RECN
Fname1 = MemProp[_RecoverTf.MemNo,3]
SCAN
  IF _RecoverTf.STATUS = 'C' && crosslinked
    =RepCrossLink(Fname1, PrevRec, MemProp[_RecoverTf.MemNo,3], _RecoverTf.RECN) && report crosslink
    =SetMPointer(DBFHandle, _RecoverTf.RECN, MemProp[_RecoverTf.MemNo, 1], 0) && set memo pointer to 0
  ENDIF
  IF _RecoverTf.STATUS != 'C'
    PrevRec = _RecoverTf.RECN
    Fname1 = MemProp[_RecoverTf.MemNo,3]
  ENDIF
ENDSCAN

* report tally
COUNT FOR EMPTY(_RecoverTf.STATUS) TO TempNo
IF TempNo = RECCOUNT()
  TempS = GM(50, "No memo errors found!")
ELSE
  ErrMsg = ''
  TempS = ALLT(STR(TempNo)) + "/" +ALLT(STR(RECCOUNT()))+" "+ GM(80, "memos recovered!")
ENDIF
ErrFixes = Wmsg(1, ErrFixes, TempS)
RecMsg   = Wmsg(2, RecMsg,   TempS)

=waitwin()
USE IN _RecoverTf

**********
PROCEDURE GetMPointer
PARAMETERS Thandle, recnum, DISPL
* gets numeric value of memopointer in DBF at displacement Displ
PRIVATE TempS
=FSEEK(Thandle, FirstRecPos + (recnum-1)*RecordLen+DISPL)
TempS = FREAD(Thandle, IIF(VFP, 4, 10))
RETURN IIF(VFP, Byte2Int(TempS, 1), VAL(TempS))

**********
PROCEDURE SetMPointer
PARAMETERS Thandle, recnum, DISPL, VALUE
* sets numeric value of memopointer in DBF at record displacement Displ to Value
=FSEEK(Thandle, FirstRecPos + (recnum-1)*RecordLen+DISPL) && '<-SMPtr seek'
RETURN FWRITE(Thandle, IIF(VFP, Int2Byte(VALUE ,4, 1), STR(VALUE,10) ))

*************************
PROCEDURE RepMissing
PARAMETER mName1, Rec1
* generates Recover.rep report string part for invalid memo pointers
* (illegal or no memo there)
DO CASE
CASE LastMis && generated by overflow CASE below
  RETURN
CASE LEN(ErrFixes)>5000
  ErrFixes = ErrFixes;
    + GM(74, "Too many invalid memo pointers for report....") + CRLF
  LastMis = .T.
CASE FirstMis
  ErrFixes = ErrFixes + CRLF;
    + GM(75, "Deleted invalid memo pointers:") + CRLF;
    + GM(77, "(Memo/Record)")+ CRLF;
    + ALLT(LEFT(mName1,10)) +"/"+ALLT(STR(Rec1)) + CRLF
  FirstMis = .F.
OTHERWISE
  ErrFixes = ErrFixes;
    + ALLT(LEFT(mName1,10)) +"/"+ALLT(STR(Rec1)) + CRLF
ENDCASE
=Append2Log(ErrFixes,.F.)

*************************
PROCEDURE RepCrossLink
PARAMETER mName1, Rec1, mName2, Rec2
* generates Recover.rep report string part for memo cross links
IF FirstLink
  ErrFixes = ErrFixes + CRLF;
    + GM(76, "Memo crosslinks existed between:")+CRLF;
    + GM(77, "(Memo/Record)")+ CRLF
  FirstLink = .F.
ENDIF
ErrFixes = ErrFixes;
  + ALLT(mName1) +"/"+ALLT(STR(Rec1)) + " & " + ALLT(mName2) +"/"+ALLT(STR(Rec2)) + CRLF

*************
PROCEDURE UserReport
* User progress report
PARAMETER Countdig
IF !ShowProgrM
  RETURN
ENDIF
PRIVATE Parms
Parms = PARAMETERS()
IF SECONDS() > PrevSec+2.0
  =waitwin(RepMsg1 + IIF(Parms>0, ALLT(STR(INT(Countdig))) ,'') + RepMsg2)
  PrevSec = SECONDS()
ENDIF

PROCEDURE Wmsg
PARAMETER MsgNo, MsgStr0, MsgStr && MsgNo=1 => ErrFixes / MsgNo=2 => ErrMsg, MsgStr0 = PreviousMsgPart, MsgStr = NewMsgPart
* adds new message parts and organizes progress messages
PRIVATE LastLineNo, LineLen, MsgLen, retval
LastLineNo = MEMLINES(MsgStr0)
LineLen = LEN(MLINE(MsgStr0, LastLineNo))
MsgLen = LEN(MsgStr)
DO CASE
CASE MsgNo = 1
  IF LineLen + MsgLen > 40 && otherwise
    retval = MsgStr0 + CHR(13) + MsgStr
  ELSE
    retval = MsgStr0 + ' ' + MsgStr
  ENDIF
CASE LastLineNo = 0
  retval = MsgStr
  *Otherwise if MsgNo=2
CASE LineLen + MsgLen < 41
  retval = MsgStr0 + ' ' + MsgStr
CASE LineLen + MsgLen > 40 AND MsgNo = 2 && otherwise
  retval = MsgStr0 + CHR(13) + MsgStr
ENDCASE

RETURN IIF(MsgNo = 1, Append2Log(retval, .F.), retval)

PROCEDURE Append2Log
PARAMETER Astring, TheLastPart
* writes ErrFixes to end of closed file RECOVREP.TXT
IF LEN(Astring) < 2048 AND !TheLastPart
  RETURN Astring
ENDIF
PRIVATE FileHandle, FileName
FileName = 'RECOVREP.TXT'
IF FILE(FileName)
  FileHandle = FOPEN(FileName, 1)
ELSE
  FileHandle = FCREATE(FileName)
ENDIF
=FSEEK(FileHandle, 0, 2)
=FWRITE(FileHandle, Astring)
=FCLOSE(FileHandle)
ErrFixes = '' && reset ErrFixes lines.
RETURN ErrFixes

PROCEDURE GM
*GetMessage
* IF RecovMsg.dbf exists THEN returns RecovMsg.msg from record MsgNms ELSE MsgString
PARAMETERS MsgNm, MsgString
IF USED("RecovMsg")
  GO MsgNm IN RecovMsg
  PRIVATE RightS
  RightS = RIGHT(ALLT(RecovMsg.Msg), 1)
  IF !EMPTY(RecovMsg.Msg)
    RETURN ALLT(RecovMsg.Msg) + IIF(RightS $ '.!', ' ', '' ) && add extra space if . or ! at end of line
  ENDIF
ENDIF
RETURN MsgString

****
PROCEDURE MB
* Returns error code and/or message
* and closes any opened files and returns to Default0
PARAMETERS xMsg, MTitle, CodeNo, retval, Ending
PRIVATE Parms, MboxVal
Parms = PARAMETERS()
=IIF(Parms > 4, waitwin(), .T.)
IF ShowMsgBox
  MboxVal=MESSAGEBOX(xMsg, CodeNo, MTitle)
ENDIF
=IIF(Parms > 4, RestoreDefs(), .T.) && restore defaults if quiting
RETURN IIF(Parms > 3, retval, MboxVal)

***
PROCEDURE RestoreDefs
* closes some files - restores default environment
*=WaitWin()
IF USED('RecoverDef')
  USE IN RecoverDef
ENDIF
IF USED("RecovMsg")
  USE IN RecovMsg
ENDIF
IF !EMPTY(Default0)
  SET DEFAULT TO (Default0)
ENDIF
IF SetSafety = 'ON'
  SET SAFETY ON
ENDIF
IF SetTalk = 'ON'
  SET TALK ON
ENDIF
IF SetExact = 'OFF'
  SET EXACT OFF
ENDIF

* Restore prior procedures
IF NOT EMPTY(sSetProc)
  IF ATC("Visual", VERSION())>0 && VFP
    *-- Restore procedures one at a time since VFP cannot
    *-- restore multiple procedures in a name expression
    sSetProc = ',' + ALLTRIM(sSetProc) + ','
    FOR nI = 1 TO OCCURS(',', sSetProc) - 1
      SET PROC TO (SUBSTR(sSetProc, AT(',', sSetProc, nI) + 1,;
        AT(',', sSetProc, nI + 1) - AT(',', sSetProc, nI) - 1)) ADDITIVE
    ENDFOR
  ELSE && 2.x FoxDos or FoxWin
    SET PROC TO (sSetProc)
  ENDIF
ENDIF

SELECT (OldArea)

POP KEY

ON ERROR * && in case this is a FPW or FPD edition
IF VFP AND SetCPDialog = 'ON'
  SET CPDIALOG ON
ENDIF
IF SetCompat = 'ON'
  SET COMPATIBLE ON
ENDIF

ON ERROR &OnError

************* specific to GetFileDefs

PROCEDURE Rtrim0
PARAMETER STRING
* Returns String with trailing zeroes removed
IF LEN(STRING) = 0
  RETURN ""
ENDIF
PRIVATE TempNo
TempNo = AT(CHR(0), STRING)
RETURN IIF( TempNo > 0, LEFT(STRING, TempNo-1), STRING)

*************************
PROCEDURE GetFileDefs
* Should be first to open .def file
* extracts file definitions
PARAMETERS EndMsg

PRIVATE TempS, TempS2
IF USED("RecoverDef")
  RETURN 0
ENDIF
IF !FILE(DefFile)
  IF EndMsg
    RecMsg   = "'"+DefFile+"' "+GM(16, "Definition file not found!")+CRLF
    ErrFixes = Wmsg(1, ErrFixes, "'"+DefFile+"' "+GM(16, "Definition file not found!")+CRLF)
  ENDIF
  RETURN -1
ENDIF

PRIVATE DefOK, TempNo, TempNo2, TempS, TempC, i
DefOK = .T.
ON ERROR DefOK=.F.
SELECT 0
USE (DefFile) ALIAS RecoverDef
ON ERROR
IF !DefOK && corrupt .def file structure
  ErrFixes = Wmsg(1, ErrFixes,   GM(17, "Definition file error!")+CRLF)
  RecMsg   = Wmsg(2, RecMsg, " "+GM(17, "Definition file error!"))
  RETURN -1
ENDIF
PRIVATE OldFirstRecPos, OldRecordLen
OldFirstRecPos = FirstRecPos
OldRecordLen = RecordLen

GO BOTTOM
Alpha5  = LEFT(Field_name, 4) = 'ALP5' && alpha five file
DelChar = IIF(Alpha5, '*- ', '* ')
VFP = LEFT(Field_name, 2) = 'VF'

IF !EMPTY(Dec)
  * this helps with DB3/memo files - only use this in future versions
  FirstRecPos = VAL(Dec)
ELSE && version 1.0 assumption
  FirstRecPos = (RECCOUNT('RecoverDef'))*32 + 1 + IIF(VFP, 263, 0) && 1 for header terminator (x0D)
ENDIF
SUM VAL(WIDTH) TO RecordLen FOR RECNO()<RECCOUNT()
RecordLen=RecordLen+1
* Calculate new record count if FirstRecPos or RecordLen are diff from original
IF OldFirstRecPos!=FirstRecPos OR OldRecordLen != RecordLen
  ActRecords = INT((FileLen - EofMark - FirstRecPos)/RecordLen) && should be
ENDIF

* Find LF position in terms of its displacement from correct position
* Test if last field exists for LFS method
SELECT RecoverDef
GO RECCOUNT() -1

**-- LFoffset calc ( Last field offset calculation
* Check last field def position
* Locate first record if it exists - by finding last record definition string main parts
*TempS=PADR(ALLT(RecoverDef.field_name), 10, CHR(0)) && + LEFT(UPPER(RecoverDef.TYPE),1) && Fieldname + FieldType
TempS=ALLT(RecoverDef.Field_name) + CHR(0) && + LEFT(UPPER(RecoverDef.TYPE),1) && Fieldname + FieldType
TempS = IIF(LEN(TempS) > 10, LEFT(TempS, 10), TempS) && the 11th position for DB3M types is not allways CHR(0)
TempNo = SrchFile(DBFHandle, 0, MIN(FileEnd,1048576), TempS)

* Check FieldType - but make sure not to grab first partial similar field name
TempNo2 = TempNo && save in case false partial name found
TempNo = IIF(TempNo > -1 AND GetString(DBFHandle, TempNo + 11, 1) == LEFT(UPPER(RecoverDef.TYPE),1), TempNo, -1)
DO WHILE TempNo < 0 AND TempNo2 > 32 AND TempNo2 < MIN(FileEnd,1048576)
  IF TempNo < 0
    TempNo = SrchFile(DBFHandle, TempNo2 + 1, MIN(FileEnd,1048576), TempS)
    TempNo2 = TempNo && save in case false partial name found
    TempNo = IIF(TempNo > -1 AND GetString(DBFHandle, TempNo + 11, 1) == LEFT(UPPER(RecoverDef.TYPE),1), TempNo, -1)
  ENDIF
ENDDO
* Check if width and decimal correct
TempNo = IIF(TempNo > -1 AND (GetString(DBFHandle, TempNo + 16, 2)==Int2Byte(VAL(RecoverDef.WIDTH),1,1)+Int2Byte(VAL(RecoverDef.Dec),1,1)), TempNo, -1)

* Check for header record terminator chr(13)
IF TempNo != -1
  TempNo = IIF(GetString(DBFHandle, TempNo+32, 1)==CHR(13), TempNo, -1)
ENDIF

**** zzzz
LFoffset = IIF(TempNo =-1, -FirstRecPos, TempNo - (RECCOUNT() -1)*32) && last field. def. offset if found
**-- end LFoffset calc

LFSm = LFSm AND LFoffset > -FirstRecPos && Last Field Search method can be used

* Check for suspicious .DEF file from .DBF header info
IF !DuplicateFN && (DefWarn AND !DuplicateFN) But do not check if duplicate is confirmed in header check
  * Check .DBF if fields match .DEF - & mBlockSize in .FPT (if in range) matches .DEF
  * Give Continue Yes/No warning or return -2 if DefWarn option on
  * IF .DBF field has UPPER(fieldname)?? _NullFlags?? and CMNF... for type
  SCAN && scan to last line to check if extra fields added after def file
    i = RECNO()
    TempS = Rtrim0(GetString(DBFHandle, i*32, 10)) && file fieldname string
    TempC = GetString(DBFHandle, i*32+11, 1)
    * return error or checkbox if file field name ok and doesn't match .DEF file
    IF (FieldNOK(TempS, .F.) AND TempS != RTRIM(RecoverDef.Field_name));
        AND TempC $ '0BCDFGILMNPTY' && AND TempC != LEFT(RecoverDef.type, 1))
      IF !DefWarn OR (DefWarn AND ShowMsgBox AND MB("'"+DefFile+"' "+GM(91, "appears incorrect!") + CRLF + GM(92, "Continue anyway?"), GM( 4,"Notice!"), 4) != 7)
        RheaderOK = .F. && fix it...
        EXIT && terminate loop
      ELSE
        ErrFixes = ErrFixes+"'"+DefFile+"' "+GM(91, "appears incorrect!")+CRLF
        RecMsg   = RecMsg + "'"+DefFile+"' "+GM(91, "appears incorrect!")+CRLF
        USE IN RecoverDef
        RETURN -2
      ENDIF
    ENDIF
  ENDSCAN

  IF EMPTY(DBCFilePath) AND "DBCPATH" $ FIELD(5, "RecoverDef") && DBCFilePath was not read from oldstyle DBFleft+De_Ext file
    SCAN FOR !EMPTY(RecoverDef.DBCPath)
      DBCFilePath = DBCFilePath + ALLT(RecoverDef.DBCPath)
    ENDSCAN
  ENDIF

  IF RheaderOK AND VFP && Header OK so far compare VFP .dbc link correspondence
    TempC = STRTRAN(GetString(DBFHandle, RECCOUNT("RecoverDef")*32+1, 263), CHR(0)) && actual DBCpath in .dbf header
    * compare it to what it should be
    IF (LEN(DBCFilePath) > 4 AND ".DBC" $ UPPER(DBCFilePath) AND UPPER(DBCFilePath) != UPPER(TempC)) OR;
        (EMPTY(DBCFilePath) AND LEN(TempC) > 4 AND ".DBC" $ UPPER(TempC))
      IF !DefWarn OR (DefWarn AND ShowMsgBox AND MB("'"+DBFleft+"' "+GM(93, ".def file .dbc link is different from table header!") + CRLF + GM(92, "Continue anyway?"), GM( 4,"Notice!"), 4) != 7)
        RheaderOK = .F.
      ELSE
        ErrFixes = ErrFixes+"'"+DBFleft+"' "+GM(93, ".def file .dbc link is different from table header!")+CRLF
        RecMsg   = RecMsg + "'"+DBFleft+"' "+GM(93, ".def file .dbc link is different from table header!")+CRLF
        USE IN RecoverDef
        RETURN -2
      ENDIF
    ENDIF
  ENDIF
ENDIF

GO BOTTOM
TableFlags = VAL(SUBSTR(Field_name,5,3))
nCodePage   = VAL(SUBSTR(Field_name,8,3))
MBlockSize = VAL(RecoverDef.WIDTH)

* get MemoCount, classify each memo and get MemoTypes
SELECT RecoverDef
GO TOP
RtraceFlag = ALLT(Field_name)='R_TRACE_' && indicates if trace used
MtraceFlag = RtraceFlag AND VAL(WIDTH) = 16 && indicates if traces used in memos
COUNT FOR LEFT(RecoverDef.TYPE, 1) $ "MGPW" TO TempNo2
*  LEFT(RecoverDef.TYPE, 1) = "M" OR LEFT(RecoverDef.TYPE, 1) = "G" OR LEFT(RecoverDef.TYPE, 1) = "P"
DIMENSION MemProp[TempNo2+1, 4]
MemoCount=0

* MemProp[MemNo, 1]: memo field position in record
* MemProp[MemNo, 2]: memo type: 1 = 'M' or 'W', 2 = 'G', 0 = 'P'
* MemProp[MemNo, 3]: memo field name
* MemProp[MemNo, 4]: field number in record - 3/11/05 - needed because of "W" type in Memoscan.prg needs to know to skip "W"s with trace code
FOR i = 1 TO RECCOUNT() -1
  GO i
  TempNo = RECNO()
  IF AT(LEFT(RecoverDef.TYPE, 1), "MGPW")>0
    MemoCount = MemoCount + 1
    * get field number in record
    MemProp[MemoCount,4] = RECNO("RecoverDef")
    * get fieldname into [MemoCount,3]
    MemProp[MemoCount,3] = Field_name
    * get field displ in record - first pos is 0
    SUM VAL(WIDTH) TO TempNo2 FOR RECNO() < TempNo
    MemProp[MemoCount,1] = INT(TempNo2 + 1)
    * get fieldtype & update MemoTypes
    GO i
    DO CASE
    CASE LEFT(RecoverDef.TYPE, 1) $ 'MW'
      MemProp[MemoCount,2] = 1
      MemoTypes = IIF(AT('1',MemoTypes)>0, MemoTypes, MemoTypes + '1')
    CASE LEFT(RecoverDef.TYPE, 1)='G'
      MemProp[MemoCount,2] = 2
      MemoTypes = IIF(AT('2',MemoTypes)>0, MemoTypes, MemoTypes + '2')
    CASE LEFT(RecoverDef.TYPE, 1)='P'
      MemProp[MemoCount,2] = 0
      MemoTypes = IIF(AT('0',MemoTypes)>0, MemoTypes, MemoTypes + '0')
    ENDCASE
  ENDIF
ENDFOR

* Field properties
PRIVATE PrevWidth, NullCount

DIMENSION FldProp[RECCOUNT()-1, 5]

*=== copy following code into browsfil.prg
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
*=== end copy

GO BOTTOM
TempS = LEFT(Field_name, 2)
DO CASE && following case order is important - otherwise messup
CASE LEFT(Field_name, 4) = 'VF32'
  FileType = 50
  lAutoIncDBF = .T.
  VFP = .T.
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
MemoFile   = IIF(EMPTY(MemoFile), DBFleft + IIF(FileType=131, '.DBT', '.FPT'), MemoFile) && memo file name
FirstBlock = CEILING(512/MBlockSize)
GO TOP

RETURN 0 && no apparent DefFile problems

**--------------
PROCEDURE MESSAGEBOX
* This will be ignored by VFP
PARAMETERS Msg, Msgtype, MsgTitle
PRIVATE MacroStr
MacroStr = "rMsgBox(Msg, MsgType, MsgTitle)"
* use macro to avoid getting error message in VFP - project manager looking for rMsgBox
RETURN &MacroStr

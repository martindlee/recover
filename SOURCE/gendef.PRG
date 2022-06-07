********************************************************************
* Gendef.Prg
* Required for generating .def file for DBFfile file for RECOVER.PRG
* Copyright 1995
* Author: Paul Lee
* Abri Technologies, www.abri.com
********************************************************************

PARAMETERS DBFfile, FPTfile, GenDefOpts, Dext
PRIVATE ALL
* GenDefOpts:
* Option codes:
* 1 => insert R_TRACE_ record field codes
* 2 =>    AND insert memo trace codes too.
* 3 => treat character fields as text only.
* 4 => use dialogs.
* 5 => try get def in case of imperfect DBF/FPT ?????
* 6 => This is an Alpha5 file

* Return values:
*  0 = successfull
* -1 = missing parameters
* -2 = file(s) not found
* -3 = File not accessible, shared or corrupt or VFP file in FP2.X
* -4 = Exclusive use of file required
* -5 = Not a FoxPro, dBaseIII or FoxBase file.
* -6 = Missing memofile
* -7 = DBC DataBase file not found
* -8 = Exclusive access to a good copy of DBC file required
* -9 = GenDef attempt from bad file failure
* -10 = field count = 255. Cannot insert r_trace_ field
* -20 = Warning - strange memo block size.

Parms = PARAMETERS()
MainRetVal = 0 && used with warning return
OnError = ON("ERROR")

Default0 = ''
DefFile = ''
FileHandle = -1
MemoHandle = -1

* environment parameters
OldSelect = ALIAS()
SELECT 0
SetExcl = SET("Exclusive")
SET EXCLUSIVE ON
SetTalk = SET("TALK")
SET TALK OFF
ON ERROR *
SetCPD = SET("CPDIALOG")
SET CPDIALOG OFF
ON ERROR

#DEFINE DOptN 6
PRIVATE DOpt
DIMENSION DOpt[DOptN]
DOpt = .F.
VFP = .F.
DOpt[4] = .T. && show messages - Default

IF Parms > 2 AND !EMPTY(GenDefOpts)
  FOR i = 1 TO MIN(LEN(GenDefOpts), DOptN)
    DOpt[i] = IIF(SUBSTR(GenDefOpts,i,1) = 'T', .T., .F.)
  ENDFOR
ENDIF

DO CASE
CASE Parms=0
  RETURN MB("GenDef missing parameters!", "Gendef notice:", 0, -1)
CASE !FILE(DBFfile)
  RETURN MB("'"+DBFfile+"' file not found", "Gendef notice:", 0, -2)
ENDCASE

* correct for relative path
DBFfl = FULLPATH(DBFfile)
FPTfl = IIF(Parms < 2 OR EMPTY(FPTfile), '', FULLPATH(FPTfile))

FileHandle = FOPEN(DBFfl)
IF FileHandle = -1
  RETURN MB("Exclusive use of "+DBFfl+" required!", "GenDef Notice:", 0, -4)
ENDIF
=FCLOSE(FileHandle)

* Must access good DBF copy
*DbfAlias = 'R'+RIGHT(SYS(2015), 9)
DbfAlias = '' && 4/26/05 mod to prevent error message in case of alias name in CDX
UseError = 0
ON ERROR UseError = ERROR()
USE (DBFfl) && ALIAS (DbfAlias) EXCLUSIVE .... 4/26/05 mod....
DbfAlias = ALIAS() && 4/26/05 mod....
ON ERROR

IF UseError>0 AND UseError!=13 AND !DOpt[5]
  RETURN MB("File "+DBFfl+" is not accessible, shared or corrupt";
    +IIF(AT('Visual FoxPro', VERSION()) = 0, " or Visual FoxPro file","")+".",;
    "Notice:", 0, -3)
ENDIF
FieldCount = 0
IF USED (DbfAlias)
  FieldCount = FCOUNT()
  FirstField = ALLT(UPPER(FIELD(1)))
  USE IN (DbfAlias)
  IF DOpt[1] AND FieldCount = 255 AND !("R_TRACE_" == FirstField)
    RETURN MB("FieldCount = 255. Cannot insert R_TRACE_ field!", "Gendef notice:", 0, -10)
  ENDIF
ENDIF
RELEASE DbfAlias

* PRIVATE TempNo, TempS, i, DBFleft
DBFleft = UPPER(IIF(RAT('.',DBFfl)>0, LEFT(DBFfl, RAT('.',DBFfl)-1), DBFfl))
IF Parms = 4 && non-standard def extension specified
  TempS  = RIGHT(UPPER(Dext), 3)
  DefExt = '.'+TempS
  De_Ext = '.'+LEFT(TempS,2)+'_'
ELSE
  DefExt = '.DEF'
  De_Ext = '.DE_'
ENDIF

DefFile = DBFleft + DefExt
ERASE (DefFile)
* FileHandle = FOPEN(DBFfl) && standard edition
FileHandle = FOPEN(DBFfl, 2) && UBS edition for correcting lower case field names

DIMENSION FileProp[9]
* general table properties
Default0 = SYS(5)+CURDIR()
SET DEFAULT TO LEFT(FULLPATH(DBFfl), RAT('\',FULLPATH(DBFfl)))
FileType   = GetValue(FileHandle, 0, 1, 1)
IF !INLIST(FileType, 3, 131, 48, 49, 50, 245)
  RETURN MB("No FoxPro, dBaseIII or FoxBase file flag found.", "Notice:", 0, -5)
ENDIF

VFP = INLIST(FileType, 48, 49, 50)
lAutoInc = INLIST(FileType, 49, 50) && autoinc not in VFP7 or less
Alpha5 = DOpt[6]
RecordLen  = GetValue(FileHandle, 10, 2, 1)
TableFlags = GetValue(FileHandle, 28, 1, 1)
nCodePage   = GetValue(FileHandle, 29, 1, 1)
FirstRecPos= GetValue(FileHandle, 8, 2, 1)
FieldCount = (FirstRecPos -32 + IIF(VFP, -263, 0))/32
MemoSignal = (FileType = 131) OR (FileType = 245) OR (VFP AND Bit(1, TableFlags))
mBlockSize = 0
DBC = ''
IF VFP
  * check for proper VFP .DBC access
  = FSEEK(FileHandle, FirstRecPos-263)
  DBC = FREAD(FileHandle, 263)
  DBCname = Rtrim0(DBC)
  IF !EMPTY(DBCname) AND !FILE(DBCname)
    RETURN MB("'"+DBCname+"' database for table '"+DBFfl+"' not found","Notice:",0, -7)
  ENDIF
  IF FILE(DBCname)
    DBCerror = 0
    ON ERROR DBCerror = ERROR()
    SELECT 0
    OPEN DATABASE (DBCname) EXCLUSIVE
    CLOSE DATABASE
    USE (DBCname) ALIAS _RecoverDC EXCLUSIVE
    IF DBCerror>0
      ON ERROR
      RETURN MB("Exclusive access to a good copy of '"+DBCname;
        +"' database file is required!","VFP Gendef notice:", 0, -8)
    ENDIF
    ON ERROR
    USE IN _RecoverDC
    RELEASE DBCerror
  ENDIF
ENDIF
FileProp[9] = DBC && the DBC pathname

* memo file must be accessible
IF MemoSignal
  IF Parms > 1 AND !EMPTY(FPTfl)
    MemoName = ALLT(FPTfl)
  ELSE
    MemoName=DBFleft+IIF(FileType=131,'.DBT','.FPT')
  ENDIF
  IF !FILE(MemoName) && general field treated as memo now
    RETURN MB('Missing memofile!', "Notice:", 0, -6)
  ENDIF
  IF FileType==131
    mBlockSize = 512 && DB3 memotype
  ELSE && FP/VF
    MemoHandle=FOPEN(MemoName)
    IF MemoHandle<0 && unsuccessful file access, probably due to filesharing.
      RETURN MB('ERROR: Exclusive access to memofile required!', "Notice:", 0, -4)
    ENDIF
    mBlockSize = GetValue(MemoHandle, 6, 2, -1)
    IF mBlockSize<33 AND !VFP
      MainRetVal = -20 && this is a warning - FoxPro can work with non-Fox block size
    ENDIF
    * mBlockSize = IIF(mBlockSize<33 AND !VFP, 64, mBlockSize) && use default if bad value
    =FCLOSE(MemoHandle)
  ENDIF
ENDIF

=CreateDefFile()
USE (DefFile) ALIAS RecoverDef
=FSEEK(FileHandle, 32 , 0)
* generate field definitions
DIMENSION FieldProp[255, 6]
* FieldProp[i, 1] = field name
* FieldProp[i, 2] = Field type 1 character
* FieldProp[i, 3] = field width - numeric
* FieldProp[i, 4] = decimal count - numeric
* FieldProp[i, 5] = FieldFlags 3 spaces
* FieldProp[i, 6] = FieldFlags 5 characters

i=0
DO WHILE !FEOF(FileHandle) AND i<255 && i<=FieldCount AND i<255
  TempS = FREAD(FileHandle, 32) && read a header sub record
  sField_Name = Rtrim0(LEFT(TempS, 10))
  IF !FieldNOK(sField_Name, .F., !VFP) OR LEFT(TempS,1)=CHR(13) && (UBS) allows lower case for non VFP
    EXIT && this is the last field
  ENDIF
  IF !VFP && (UBS) some odd ball old data files (non-VFP) have lower case field names
    IF !LIKE(sField_Name, UPPER(sField_Name)) && Change to upper case
      OldSeekPos = SaveFSEEK(FileHandle)
      FSEEK(FileHandle, -32, 1)
      FWRITE(FileHandle, UPPER(sField_Name))
      RestoreFSEEK(FileHandle, OldSeekPos)
    ENDIF
    sField_Name = UPPER(sField_Name)
  ENDIF
  i=i+1
  FieldProp[i, 1] = sField_Name && field name
  TempNo = IIF(VFP, ASC(SUBSTR(TempS, 18+1, 1)), 0)
  FieldProp[i, 5] = TempNo && FieldFlags
  FieldProp[i, 2] = SUBSTR(TempS, 11+1, 1) && type
  FieldProp[i, 6] = IIF( TempNo = 12 AND lAutoInc, "a" + SUBSTR(TempS, 20, 5), "     ") && autoinc NextVal (4bytes), Step(1byte)
  TempNo = IIF(TempNo = 12 AND !lAutoInc, 0, TempNo) && do not record stray autoinc flag
  sType = FieldProp[i, 2] + IIF(TempNo>0, STR(TempNo, 3 ,0), "   ") + FieldProp[i, 6]
  sWidth = ALLT(STR(Byte2Int(SUBSTR(TempS, 16+1, 1), 1), 3, 0))
  FieldProp[i, 3] = VAL(sWidth)
  sDec   = IIF(LEFT(FieldProp[i, 2],1)='C' AND DOpt[3] AND FieldProp[i, 1]!='R_TRACE_', 'TEXT',;
    ALLT(STR(Byte2Int(SUBSTR(TempS, 17+1, 1), 1), 10,0)))
  FieldProp[i, 4] = VAL(sDec)
  TempS = "" && IIF(TempS = "_NullFlags", "", sField_Name) && VFP hidden NullFlag field
  INSERT INTO RecoverDef VALUES(sField_Name, sType, sWidth, sDec, "")
ENDDO

* check for field duplicates
DuplicateFN = .F.
SCAN FOR !FieldNOK(Field_Name, .T.)
  DuplicateFN = .T.
ENDSCAN
IF USED("_RecoverFN") && used to check fieldname duplication
  USE IN _RecoverFN
ENDIF
* Exit if 1. no fields found or 2. duplicates or 3. invalid FirstRecPos
IF i=0 OR DuplicateFN;
    OR (RECCOUNT('RecoverDef')+1)*32 + 1 + IIF(VFP, 263, 0) > GetValue(FileHandle, 8, 2, 1) && Last rec not created yet & 1 for header terminator (x0D)
  USE IN RecoverDef
  ERASE (DefFile)
  RETURN MB("Gen .DEF attempt from bad file failed!", "GenDef Notice:", 0, -9)
ENDIF

SUM VAL(WIDTH) TO TempNo && double check RecordLen
RecordLen=IIF(RecordLen!=TempNo+1, TempNo+1, RecordLen)

TempNo = 32*(1 + RECCOUNT("RecoverDef")) + IIF(VFP, 263, 0)

IF FirstRecPos > TempNo + 16 OR FirstRecPos < TempNo
  FirstRecPos = TempNo + 1 + IIF(FileType=131,1,0)
  * 1 for header terminator (x0D) & dBase+/Clipper often add 1 for displ.
ENDIF

* Write last info record

DO CASE
CASE Alpha5
  sField_Name = 'ALP5'
CASE INLIST(FileType, 48, 49, 50) && regular VFP, with autoinc, with autoinc & VarChar & blob
  sField_Name = 'VF' + ALLT(STR(30 + FileType - 48)) && hex 30, 31 or 32
CASE FileType = 131 && DBASEIII/Clipper with memo
  sField_Name = 'DB3M'
OTHERWISE && FP2x with memo
  sField_Name = 'FP2X'
ENDCASE
sField_Name = sField_Name + STR(TableFlags, 3, 0) + STR(nCodePage,3,0)
sDec   = ALLT(STR(FirstRecPos)) && use for first rec pos.
INSERT INTO RecoverDef VALUES( sField_Name, '', ALLT(STR(IIF(mBlockSize=0, 64, mBlockSize) )), sDec, '')
RELEASE sField_Name, sType, sWidth, sDec

*---
* if R_TRACE_ already exists - insert proper flags and correct fields
SELECT RecoverDef
GO TOP

* erase old .DE_ if exists
ERASE (DBFleft+De_Ext)
=FCLOSE(FileHandle)

* optionally write trace field and memotraces - but not to DBASEIII/Alpha5 files and not for badfiles
SELECT RecoverDef
GO TOP

* add R_TRACE_ field to the .dbf file if requested and "not already there"
IF !Alpha5 AND !FileType=131 AND !ALLT(Field_Name) = "R_TRACE_" AND DOpt[1] AND (UseError==0 OR UseError = 13)
  PRIVATE MemoTrace
  MemoTrace = ""


  DIMENSION FieldProp[FieldCount+1, 6]
  FOR i=FieldCount TO 1 STEP -1
    FOR j=1 TO 6
      FieldProp[i+1,j] = FieldProp[i,j]
    ENDFOR
  ENDFOR
  FieldProp[1,1]="R_TRACE_"
  FieldProp[1,2]="C"
  FieldProp[1,3]=IIF(DOpt[2] AND MemoSignal, 16, 7) && 7 spaces without memotracing, 16 with memotracing
  FieldProp[1,4]=0
  FieldProp[1,5]=0
  FieldProp[1,6] = "     "

  * create revised DBF table with R_TRACE_ field
  FileProp[8] = FieldCount+1 && one more field added here
  FileProp[1] = 'Recovert.dbf' && temporary table name
  FileProp[2] = FileType	&&  0:
  FileProp[3] = 32+FileProp[8]*32 + IIF(VFP, 263, 0) && FirstRecPos 8:
  FileProp[4] = RecordLen + IIF(DOpt[2] AND MemoSignal, 16, 7)	&& 10:
  FileProp[5] = TableFlags	&& 28:
  FileProp[6] = nCodePage	&& 29:
  FileProp[7] = mBlockSize	&& 06: of memofile
  ERASE Recovert.DBF
  =CreateDBF(@FileProp, @FieldProp)

  =MoveData(DBFfl, "Recovert.dbf") && save data with added new r_trace_ field at beginning

  * DBFfl is closed at this point

  * IF VFP add R_TRACE_ to DBC
  IF VFP AND !EMPTY(DBCname)
    IF MemoSignal
      * rename original memofile to temp/fpt
      ERASE Recovert.fpt
      RENAME (MemoName) TO Recovert.fpt
      * create empty fpt for orig name
      FileHandle = FCREATE(MemoName)
      =FWRITE(FileHandle, REPLICATE(CHR(0),3) + CHR(8) + REPLICATE(CHR(0),3) + CHR(64) + REPLICATE(CHR(0),512 - 8))
      =FCLOSE(FileHandle)
    ENDIF
    * zap DBF contents
    FileHandle = FOPEN(DBFfl, 2)
    =PutValue(FileHandle, 4, 0, 4, 1)
    =FCHSIZE(FileHandle, FirstRecPos)
    =FCLOSE(FileHandle)
    * add R_TRACE_ field & move to # 1 pos
    IF DOpt[2] AND MemoSignal && VFP with memo file
      ALTER TABLE (DBFfl) ADD R_TRACE_ C(16)
    ELSE && no-memo VFP file
      ALTER TABLE (DBFfl) ADD R_TRACE_ C(7)
    ENDIF
    =DBCRtrace(DBCname, DBFfl) && move R_TRACE_ field to 1st position
    IF MemoSignal
      * restore original DBFfl/fpt memo file
      ERASE (MemoName)
      RENAME Recovert.fpt TO (MemoName)
    ENDIF
  ENDIF

  ERASE (DBFfl)
  RENAME Recovert.DBF TO (DBFfl)

  * add trace codes to first field
  SELECT 0
  USE (DBFfl) ALIAS _RecoverDb && at this point there is no dbc link or .cdx file assoc.
  REPLACE R_TRACE_ WITH IIF(DOpt[2] AND MemoSignal, RTrace(1) , RTrace()) ALL
  SELECT RecoverDef
  IF DOpt[2] AND MemoSignal
    SCAN FOR LEFT(TYPE,1) = 'M'
      TempS = ALLT(Field_Name)
      TempS2 = Field_Name
      SELECT _RecoverDb
      LOCATE FOR !EMPTY(&TempS)
      IF FOUND() AND LEFT(&TempS,10) = TempS2
        REPLACE &TempS WITH TempS2 + RIGHT(R_TRACE_,9) + SUBSTR(&TempS, 20) FOR !EMPTY(&TempS)
      ELSE
        REPLACE &TempS WITH TempS2 + RIGHT(R_TRACE_,9) + &TempS FOR !EMPTY(&TempS)
      ENDIF
      SELECT RecoverDef
    ENDSCAN
  ENDIF

  * reindex .cdx file if exists
  IF FILE(DBFleft+'.CDX')
    SELECT _RecoverDb
    REINDEX
    SELECT RecoverDef
  ENDIF
  USE IN _RecoverDb

  * add DBC backlink for VFP if any
  IF VFP AND !EMPTY(Rtrim0(FileProp[9]))
    FileHandle=FOPEN(DBFfl,2)
    =FSEEK(FileHandle, FileProp[3]-263)
    =FWRITE(FileHandle, FileProp[9])
    =FCLOSE(FileHandle)
  ENDIF

  * reasociate .cdx file if exists
  IF Bit(0,TableFlags) AND FILE(DBFleft+'.CDX')
    FileHandle=FOPEN(DBFfl,2)
    =PutValue(FileHandle, 28, TableFlags, 1, 1)
    =FCLOSE(FileHandle)
  ENDIF

  * alter .def to show R_TRACE_ field
  SELECT RecoverDef
  PRIVATE N, XX
  DIMENSION XX[10]
  N = RECCOUNT()
  * move all data one record down to make room fo the R_TRACE_ field
  APPEND BLANK
  FOR i = N TO 1 STEP -1
    GO i
    SCATTER TO XX
    SKIP
    GATHER FROM XX
  ENDFOR
  RELEASE N, XX
  * Write R_TRACE_ field
  GO TOP
  REPLACE Field_Name WITH 'R_TRACE_';
    TYPE WITH 'C' + IIF(VFP, '  4','');
    WIDTH WITH IIF(DOpt[2] AND MemoSignal,'16','7');
    DEC WITH '0'
  *    FIELDALIAS WITH 'R_TRACE'
  GO BOTTOM
  REPLACE DEC WITH ALLT(STR(VAL(DEC)+32)) && an extra field definition was added
ENDIF

* write DBC path to DefFile if needed
IF VFP
  SELECT RecoverDef
  ERASE (DBFleft+De_Ext) && may exist from old edition.
  TempS = Rtrim0(FileProp[9])
  IF !EMPTY(TempS) && some characters exist
    GO TOP IN RecoverDef
    DO WHILE LEN(TempS) > 1
      REPLACE DBCPath WITH LEFT(TempS, 60)
      SKIP
      TempS = SUBSTR(TempS, 61)
    ENDDO
  ENDIF
ENDIF

DO CASE
CASE MainRetVal = -20
  RETURN MB(DefFile + ' Definition file created.' + CHR(13) + CHR(13) + 'WARNING: strange ' + ALLT(STR(mBlockSize)) + ' byte memo block size!', "Notice:", 0, -20)
OTHERWISE
  RETURN MB(DefFile + ' Definition file created!', "Notice:", 0, 0)
ENDCASE

******************
* Gendef Procedures
******************
PROCEDURE GetValue
* Gets numeric value from N bytes at file location FileLoc
PARAMETER FileHandle, FileLoc, NBytes, Dirn
PRIVATE CurrentPos, RetVal
CurrentPos =FSEEK(FileHandle, 0)
=FSEEK(FileHandle, FileLoc)
RetVal = Byte2Int(FREAD(FileHandle, NBytes), Dirn)
=FSEEK(FileHandle, CurrentPos) && restore prior pos.
RETURN RetVal

***
PROCEDURE PutValue
* Writes N bytes from value Decm at location FileLoc
* Returns number of bytes written
PARAMETER FileHandle, FileLoc, decm, NBytes, Dirn
=FSEEK(FileHandle, FileLoc)
RETURN FWRITE(FileHandle, Int2Byte(decm, NBytes, Dirn))

***
FUNCTION Bit
PARAMETER BITNO, A
* Returns .T. if BitNo of A is set
* Example: =Bit(0, 4)
RETURN INT(MOD(A/2^BITNO,2))=1

***
PROCEDURE Int2Byte
PARAMETER Intgr, N, Dirn
* Converts integer 'Intgr', into a Byte string, N bytes long
* Left to right if Dirn = -1 and right to left if Dirn = 1
* Returns: the Byte String
PRIVATE num, RetVal
RetVal=''
num = Intgr
DO WHILE num>255
  rem=num%16
  RetVal = IIF(Dirn>0, RetVal+CHR(num%256), CHR(num%256)+RetVal)
  num=INT(num/256)
ENDDO
RetVal=IIF(Dirn>0, RetVal+CHR(num), CHR(num)+RetVal)
* Now make sure its N long by padding on left or right
RetVal=IIF(Dirn>0, PADR(RetVal,N,CHR(0)), PADL(RetVal,N,CHR(0)))
RETURN RetVal

***
PROCEDURE Byte2Int
PARAMETER STRING, Dirn
* converts Bytes string to integer value
* If Dirn = -1 : normal calculator left to right digit significance
* If Dirn = +1 : assembler memory addressing right to left significance
PRIVATE strlen, A, B, RetVal, i, j
RetVal=0
j=0
A=IIF(Dirn>0, 0, LEN(STRING)-1)
B=IIF(Dirn>0, LEN(STRING)-1, 0)
FOR i=A TO B STEP Dirn
  j=j+1
  RetVal = ASC(SUBSTR(STRING, j, 1))*256^i + RetVal
ENDFOR
RETURN RetVal

******************

PROCEDURE Rtrim0
PARAMETER STRING
* Returns String with trailing binary zeroes removed
IF LEN(STRING) = 0
  RETURN ""
ENDIF
PRIVATE TempNo
TempNo = AT(CHR(0), STRING)
RETURN IIF( TempNo > 0, LEFT(STRING, TempNo-1), STRING)

*****************************
PROCEDURE RTrace
* Returns 15 byte string to be placed into first field for file recovery tracing
PARAMETER MEMOS && any character or numeric value IF memotracing is required
MemoTrace = IIF(PARAMETERS()>0, RIGHT(SYS(2015),9), "") && memotrace is a public variable
RETURN "ReCoVeR"+MemoTrace

***********************
PROCEDURE CreateDBF
PARAMETER FileProp, FieldProp
* Creates an empty table from arrays FileProp, FieldProp
* does not open it
PRIVATE TempNo, TempNo2, TempS, i, FileHandle, FieldCount, VFP, FileName, FileType
FileName   = FileProp[1]
FileName   = IIF(AT('.',FileProp[1])>0, FileProp[1], LEFT(FileProp[1],8)+'.DBF')
FileHandle = FCREATE(FileName)
FieldCount = FileProp[8]
FileType   = FileProp[2]
VFP        = INLIST(FileProp[2], 48, 49, 50)

* Empty header first with nulls
=FSEEK(FileHandle, 0)
=FWRITE(FileHandle, REPLICATE(CHR(0),33))
=FSEEK(FileHandle, 32) && backup one byte

* Write type of file : 0
=PutValue(FileHandle, 0, FileType, 1, 1)
*=IIF(VFP, PutValue(FileHandle, 0, 48, 1, 1),;
*  PutValue(FileHandle, 0, IIF(FileProp[7]>0, 245, 3), 1, 1))

* Write last update date (today!) : 1-3
=FSEEK(FileHandle, 1)
=FWRITE(FileHandle,CHR(YEAR(DATE())-INT(YEAR(DATE())/100)*100);
  +CHR(MONTH(DATE()))+CHR(DAY(DATE())))

* Set record counter to 0
=PutValue(FileHandle, 4, 0, 4, 1)

* Write Position of first data record : 8-9
=PutValue(FileHandle, 8, FileProp[3], 2,1)

* Write Length of data record : 10-11
=PutValue(FileHandle, 10, FileProp[4], 2, 1)

* write cdx/(VFP memo/DCB) flags : 28
TempNo = FileProp[5]
TempNo = IIF(Bit(0,TempNo), TempNo-1, TempNo)
=PutValue(FileHandle, 28, TempNo, 1, 1)

* write code page mark : 29
=PutValue(FileHandle, 29, FileProp[6], 1, 1)

* write Field definition subRecords
=FSEEK(FileHandle, 32)

* Reconstruct field subRecords in header
TempNo=1
FOR i = 1 TO FileProp[8]
  TempS=PADR(FieldProp[i,1],11,CHR(0))+ FieldProp[i,2] && 0-11: name and type
  TempS=TempS+Int2Byte(TempNo,4,1)                   && 12-15: displacement of field in rec
  TempS=TempS+Int2Byte(FieldProp[i,3],1,1)           && 16: width
  TempS=TempS+Int2Byte(FieldProp[i,4],1,1)           && 17: decimals
  TempS=TempS+Int2Byte(FieldProp[i,5],1,1)           && 18: VFP field flags - 0 otherwise
  TempS=TempS+ IIF('a' $ LEFT(FieldProp[i,6], 1),;
    SUBSTR(FieldProp[i,6], 2, 5) +  REPLICATE(CHR(0),8),;
    REPLICATE(CHR(0),13))                   && extra 0's
  =FWRITE(FileHandle, TempS , 32)
  TempNo=TempNo+FieldProp[i,3]
ENDFOR
=FWRITE(FileHandle, CHR(13), 1)                      && header record terminator

IF VFP && write VFP backlink space (only)
  =FSEEK(FileHandle, FileProp[3]-263)
  =FWRITE(FileHandle, REPLICATE(CHR(0), 263))
ENDIF
=FCLOSE(FileHandle)

******************
PROCEDURE DBCRtrace
PARAMETER DBCname, DBname
* modifies database DBCname to include Moves r_trace_ field in database DBCname to in DBFfl table
PRIVATE i, mParentId, DBFfl, TempNo, X, BestMatch, ThisMatch, BestRec
OPEN DATABASE (DBCname)
CLOSE DATABASE
SELECT 0
USE (DBCname)
* DBname may have full path
TempNo = RAT('\', DBname)
DBFfl = IIF(TempNo > 0, SUBSTR(DBname, TempNo+1), DBname)

BestMatch = 0
BestRec = 0
* scan through property memo looking for filename.dbf pathname
SCAN FOR ATC(DBFfl+CHR(0), property) > 0;
    AND ALLT(UPPER(ObjectType)) = 'TABLE';
    AND !DELETED()
  ThisMatch = PathMatch(DBFfl, DBname, property)
  IF ThisMatch > 0 AND ThisMatch > BestMatch
    BestMatch = ThisMatch
    BestRec = RECNO()
  ENDIF
ENDSCAN

GO BestRec
mParentId = ObjectId

* move r_trace_ field to top of field list
SET FILTER TO (ObjectId = mParentId OR ParentId = mParentId) AND !DELETED()
LOCATE FOR ParentId = mParentId AND UPPER(ALLT(ObjectName))=='R_TRACE_'
SCATTER MEMO TO X
SKIP -1
DO WHILE ALLT(UPPER(ObjectType)) == 'FIELD' AND !DELETED()
  SCATTER MEMVAR MEMO
  SKIP
  TempNo = ObjectId
  GATHER MEMVAR MEMO
  REPLACE ObjectId WITH TempNo
  SKIP -2
ENDDO
SKIP
TempNo = ObjectId
GATHER MEMO FROM X
REPLACE ObjectId WITH TempNo
REINDEX
FLUSH
USE
***

PROCEDURE PathMatch
* to make sure path & filename match in property.
PARAMETERS FileName, PathName, PropStr
PRIVATE FNamePos, TempC, PathPos
FNamePos = ATC(DBFfl, PropStr)
TempC = SUBSTR(PropStr, FNamePos-1, 1)
IF TempC != '\' AND TempC != CHR(1)
  RETURN 0
ENDIF

* Find beginning of relative (?) pathname
PathPos=FNamePos-1
DO WHILE TempC != CHR(1)
  PathPos = PathPos - 1
  TempC = SUBSTR(PropStr, PathPos, 1)
ENDDO

IF !UPPER(SUBSTR(PropStr, PathPos+1, FNamePos - PathPos + LEN(FileName)-1)) $ PathName
  RETURN 0
ELSE
  RETURN FNamePos - PathPos + LEN(FileName)-1
ENDIF

**************************
PROCEDURE MoveData
PARAMETERS DBFfl, TempName
* copies records from DBFfl to empty file TempName - except to the r_trace_ field
PRIVATE RecLen1, RecLen2, FirstPos1, FirstPos2, RECORDS
PRIVATE Handle1, Handle2, i, TempS
Handle1 = FOPEN(DBFfl)
Handle2 = FOPEN(TempName,2)
FirstPos1= GetValue(Handle1, 8, 2, 1)
FirstPos2= GetValue(Handle2, 8, 2, 1)
RecLen1  = GetValue(Handle1, 10, 2, 1)
RecLen2  = GetValue(Handle2, 10, 2, 1)

RECORDS  = GetValue(Handle1, 4, 4, 1)
=FSEEK(Handle1, FirstPos1)
=FSEEK(Handle2, FirstPos2)
FOR i=1 TO RECORDS
  * get delete flag and rest of record
  TempS = FREAD(Handle1, 1) + PADL( RIGHT(FREAD(Handle1, RecLen1-1), RecLen1-1),RecLen2-1)
  =FWRITE(Handle2,TempS)
ENDFOR
=FWRITE(Handle2,CHR(26)) && EOF mark
=PutValue(Handle2, 4, RECORDS, 4, 1)
=FCLOSE(Handle1)
=FCLOSE(Handle2)

****************************
PROCEDURE CreateDefFile
* creates .DEF file.
PRIVATE FP, XX
DIMENSION FP[9], XX[5,6]
FP[1] = DefFile
FP[2] = 3 && FileType = FP2X
FP[3] = 193 && IIF(VFP, 456, 193)	&& FirstRecPos
FP[4] = 96			&& RecordLen
FP[5] = 0			&& TableFlags
FP[6] = 0 && IIF(VFP,3,0)		&& nCodePage
FP[7] = 0			&& MblockSize
FP[8] = 5			&& Field count
FP[9] = '' && not a VFP file  - no DBC path
XX[1,1] = 'FIELD_NAME'
XX[1,3] = 10
XX[2,1] = 'TYPE'
XX[2,3] = 10
XX[3,1] = 'WIDTH'
XX[3,3] = 5
XX[4,1] = 'DEC'
XX[4,3] = 10
XX[5,1] = 'DBCPATH'
XX[5,3] = 60
STORE 'C' TO XX[1,2], XX[2,2], XX[3,2], XX[4,2], XX[5,2] && type
STORE 0   TO XX[1,4], XX[2,4], XX[3,4], XX[4,4], XX[5,4] && decimals
STORE 0   TO XX[1,5], XX[2,5], XX[3,5], XX[4,5], XX[5,5] && FieldFlags
STORE '      '   TO XX[1,6], XX[2,6], XX[3,6], XX[4,6], XX[5,6] && autoinc property - none
=CreateDBF(@FP, @XX)
RELEASE XX

*------------
PROCEDURE MB
* Returns error code and/or message, default settings, and closes any opened files
PARAMETERS Msg, TITLE, CodeNo, RetVal

IF !EMPTY(Default0)
  SET DEFAULT TO (Default0)
ENDIF
IF USED ("_RecoverDC")
  USE IN _RecoverDC
ENDIF
IF USED ("RecoverDef")
  USE IN RecoverDef
ENDIF
IF FileHandle > -1
  =FCLOSE(FileHandle)
ENDIF
IF MemoHandle > -1
  =FCLOSE(MemoHandle)
ENDIF
IF SetExcl = 'OFF'
  SET EXCLUSIVE OFF
ENDIF
IF SetTalk = 'ON'
  SET TALK ON
ENDIF

ON ERROR *
IF VFP AND SetCPD = 'ON'
  SET CPDIALOG ON
ENDIF

IF DOpt[4]
  =MESSAGEBOX(Msg, CodeNo, TITLE)
ENDIF

IF !EMPTY(OldSelect)
  SELECT ALLT(OldSelect)
ENDIF

ON ERROR &OnError

RETURN RetVal

*----------
PROCEDURE MESSAGEBOX
* This will be ignored by VFP
PARAMETERS Msg, Msgtype, MsgTitle
PRIVATE MacroStr
MacroStr = "rMsgBox(Msg, MsgType, MsgTitle)"
RETURN &MacroStr

*------------------ created 7/5/05 for UBS edition
PROCEDURE SaveFSEEK
PARAMETER FileHandle
RETURN FSEEK(FileHandle, 0, 1)

PROCEDURE RestoreFSEEK
PARAMETER FileHandle, nBytePos
RETURN FSEEK(FileHandle, nBytePos, 0)

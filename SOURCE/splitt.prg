************ not used
* splits large files - mainly for the 2gb limit
* into 2 pieces.
PARAMETER DBFnm, FPTnm, StartCopyRec
SET TALK OFF
* Splits either at record percent or record count
* eg: 45% or 1200r
PRIVATE ALL
DBFHandle = -1
Table2Handle = -1
Memo2Handle = -1
Params = PARAMETERS()
IF params < 3
  StartCopyRec = 75 && 75%
ENDIF
SplitHeader = "Abri large file split utility notice:"
IF Params < 1
  =MessageBox("Invalid number of parameters." + CHR(13);
    + "USAGE: DO SPLIT WITH DBFfilePath, FPTfilePath, FilePercent (or FileRecNum)" + CHR(13);
    + "FilePercent can be empty string if DBFfilePath has .DBF extension.", 0, SplitHeader)
  RETURN
ENDIF
DBFfile = FULLPATH(DBFnm)
FileDir = LEFT(DBFfile, RAT('\', DBFfile)) && directory of the file
DBFleft = UPPER(IIF(RAT('.',DBFfile)>0, LEFT(DBFfile, RAT('.',DBFfile)-1), DBFfile))


* def file is required
DefFile = UPPER(IIF(RAT('.',DBFfile)>0, LEFT(DBFfile, RAT('.',DBFfile)-1), DBFfile)) + ".DEF" && field definition file
DO CASE
CASE LEFT(RIGHT(DBFfile,4), 1)!='.'
  =MessageBox ("Filename extension (.DBF) missing!", 0, SplitHeader)
  RETURN
CASE !FILE(DBFfile)
  =MessageBox("File '" + DBFfile + "' not found", 0, SplitHeader)
  RETURN
ENDCASE

* check if demo
#DEFINE demo .F.
#IF demo
  IF !DemoChk(DBFnm)
    RETURN
  ENDIF
#ENDIF

* check if file length is OK.
DIMENSION FileArr[1,5]
=ADIR(FileArr, DBFfile) && get file details to FileArr
FileLen=FileArr[1,2]
FileLen = IIF (FileLen < 0, 2^32 + FileLen, FileLen)
RELEASE FileArr
IF FileLen < 1073741824 && 1 GB
  =MessageBox("File size is not beyond limit. You can copy last number of records to another file and then 'delete/pack' this file or scan/repair first if necessary.", 0, SplitHeader)
  RETURN
ENDIF

* Must have exclusive low level use - check if file is in use
IF !FCLOSE(FOPEN(DBFfile, 2)) && , 2 corrected 12/30/97 - to test for excl correctly
  =MessageBox("File access error! Split utility requires exclusive use of '" + UPPER(DBFfile) + "' file.", 0, SplitHeader)
  RETURN Cleanup()
ENDIF

Default0 = SYS(5)+CURDIR()
* set default to where the file is
SET DEFAULT TO LEFT(DBFfile, RAT('\',DBFfile))
SET CPDIALOG OFF
* general variables
MsgFont = IIF(_WINDOWS,"MS Sans Serif", "Geneva") && default font

DBFHandle = FOPEN(DBFfile, 2)
FileType = GetValue(DBFhandle, 0, 1, 1)
EofMark=IIF(GetValue(DBFHandle, FileLen-1, 1, 1)=26,1,0) && check if ^Z at end of file

* TableFlags to be used only in writing the RecPart2.DBF
TableFlags  = GetValue(DBFhandle, 28, 1, 1)
TableFlags = SetBit(0, TableFlags, .F.) && remove CDX flag
TableFlags = SetBit(3, TableFlags, .F.) && remove DBC connection flag

nCodePage    = GetValue(DBFhandle, 29, 1, 1)

MemoFile = IIF(EMPTY(FPTnm), '', FULLPATH(FPTnm))
MemoFile = IIF(LEN(MemoFile)>0, MemoFile, DBFleft + IIF(FileType=131, '.DBT', '.FPT')) && memo file name

USE (DefFile) IN 0 ALIAS RecoverDef
MemoCount=0
COUNT TO MemoCount FOR LEFT(RecoverDef.TYPE, 1) $ "MGP"

IF MemoCount > 0 AND !FILE(MemoFile) && supposed to be a memo file - write one if not
  MemoHandle=FCREATE(MemoFile)
  =WriteMemoH(MemoHandle, 64)
  =FCLOSE(MemoHandle)
ENDIF
SELECT RecoverDef
GO BOTTOM
VFP = LEFT(Field_name, 2) = 'VF'
Alpha5  = LEFT(Field_name, 4) = 'ALP5' && alpha five file
DelChar = IIF(Alpha5, '*- ', '* ')
IF !EMPTY(DEC)
  * this helps with DB3/memo files - only use this in future versions
  FirstRecPos = VAL(DEC)
ELSE && version 1.0 assumption
  FirstRecPos = (RECCOUNT('RecoverDef'))*32 + 1 + IIF(VFP, 263, 0) && 1 for header terminator (x0D)
ENDIF
SUM VAL(WIDTH) TO RecordLen FOR RECNO()<RECCOUNT()
RecordLen=RecordLen+1
ActRecords = INT((FileLen - EofMark - FirstRecPos)/RecordLen) && should be
* copy records to RecPart2.dbf
StartCopyRec = IIF(StartCopyRec < 100, INT(StartCopyRec/100*ActRecords), StartCopyRec)
IF StartCopyRec >= ActRecords
  =MessageBox("Cannot split file at record " + ALLT(STR(StartCopyRec))+ ". There are only " + ALLT(STR(ActRecords)) + " in the table",;
    0, SplitHeader)
  RETURN Cleanup()
ENDIF

WAIT WINDOW "Copying records to RecPart2.DBF... Please Wait..." NOWAIT
CpRecCount = ActRecords - StartCopyRec
PrevSec = SECONDS()
=FSEEK(DBFhandle, FirstRecPos + StartCopyRec*RecordLen, 0)

Table2Handle = FCREATE(FileDir + 'RecPart2.DBF')
=WriteHeader(Table2Handle, CpRecCount)
=FSEEK(Table2Handle, FirstRecPos, 0)
FOR i = 1 TO CpRecCount
  =FWRITE(Table2Handle, FREAD(DBFHandle, RecordLen))
  IF SECONDS() > PrevSec+2.0
    WAIT WINDOW "Copying records to RecPart2.DBF - " + ALLT(STR(INT(i))) NOWAIT
    PrevSec = SECONDS()
  ENDIF
ENDFOR
=FWRITE(Table2Handle, CHR(26)) && eof mark

* change original file record count
=PutValue(DBFhandle, 4, StartCopyRec, 4, 1)
* shorten original file by same amount of records
=FSEEK(DBFhandle, FirstRecPos + StartCopyRec*RecordLen, 0)
=FWRITE(DBFHandle, CHR(26)) && eof mark
DBFCurPos = FSEEK(DBFhandle, 0, 1)
=FCHSIZE(DBFhandle, DBFCurPos)

WAIT CLEAR

* copy memofile if exists
* Memo2Handle = IIF(MemoCount > 0, FCREATE(FileDir + 'RecPart2' + IIF(FileType=131, '.DBT', '.FPT')), -1)
IF MemoCount > 0 && memos exist
  WAIT WINDOW "Copying memo file to RecPart2" + IIF(FileType=131, '.DBT', '.FPT') + " memo file... Please Wait. This may take a while" NOWAIT
  SET SAFETY OFF
  COPY FILE (MemoFile) TO (FileDir + 'RecPart2' + IIF(FileType=131, '.DBT', '.FPT'))
  SET SAFETY ON
ENDIF
WAIT CLEAR

**----- Main Cleanup
DO cleanup
=MessageBox("Table " + DBFfile + " was split into two pieces, the second piece is: " + FileDir + "RecPart2.DBF",;
  0, "Table split:")

*------------------
PROCEDURE Cleanup
SET DEFAULT TO (Default0)
IF USED("RecoverDef")
  USE IN RecoverDef
ENDIF
IF DBFHandle > -1
  =FCLOSE(DBFHandle)
ENDIF
IF Table2Handle > -1
  =FCLOSE(Table2Handle)
ENDIF
IF Memo2Handle > -1
  =FCLOSE(Memo2Handle)
ENDIF


**************
PROCEDURE GetValue
* Gets integer value from N bytes at file location FileLoc
PARAMETER FileHandle, fileloc, nbytes, dirn
=FSEEK(FileHandle, fileloc)
RETURN Byte2Int(FREAD(FileHandle, nbytes), dirn)

********************
PROCEDURE PutValue
* Converts 'Intgr' value to N bytes and writes it at location FileLoc
* Returns number of bytes written
PARAMETER FileHandle, fileloc, Intgr, nbytes, dirn
=FSEEK(FileHandle, fileloc)
RETURN FWRITE(FileHandle, Int2Byte(Intgr, nbytes, dirn))

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

****************
PROCEDURE Int2Byte
PARAMETER decm, N, dirn
* Converts a decimal number 'Decm', into a Byte string, N digits long
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

*************
PROCEDURE Byte2Int
PARAMETER STRING, dirn
* converts Bytes string to decimal value
* If Dirn = -1 : normal calculator left to right digit significance
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

PROCEDURE WriteHeader
PARAMETER FileHandle, ActRecords
* Writes a .dbf header to FileHandle file using .def definition file info.
* AND adjusts size and writes EofMark

PRIVATE TempNo, TempS
* Empty header first with nulls
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
EofMark = IIF(FileLen-1 > FirstRecPos + 2, 1, 0) && ^Z not used for empty files

* 12/22/98 ActRecords = ROUND((FileLen - EofMark - FirstRecPos)/RecordLen, 0)

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
SCAN FOR RECNO()<RECCOUNT()
  TempS=PADR(ALLT(RecoverDef.field_name),11,CHR(0))+LEFT(LEFT(RecoverDef.TYPE,1),1) && name and type
  TempS=TempS+IIF(Alpha5, PictType, Int2Byte(TempNo,4,1)) && displacement of field in rec or 0000 if Alpha5
  TempS=TempS+Int2Byte(VAL(RecoverDef.WIDTH),1,1)           && width
  TempS=TempS+Int2Byte(VAL(RecoverDef.dec),1,1)             && decimals
  TempS=TempS+Int2Byte(VAL(SUBSTR(RecoverDef.TYPE, 2)),1,1) && VFP field flags - 0 otherwise
  TempS=TempS+REPLICATE(CHR(0),13)  && 0's
  =FWRITE(FileHandle, TempS , 32)
  TempNo=TempNo+VAL(RecoverDef.WIDTH)
ENDSCAN
=FWRITE(FileHandle, CHR(13), 1)  && header record terminator

* IF VFP write database back-links info (263 bytes, 0+262 spaces or FilePath)
IF VFP
  TempNo = FSEEK(FileHandle, 0, 1) && save current position
  =FWRITE(FileHandle, REPLICATE(CHR(0),263))
  =FSEEK(FileHandle, TempNo)
  IF .F. && FILE(DBFleft + De_Ext) - not used for RecPart2.dbf
    TempNo2 = FOPEN(DBFleft+De_Ext)
    =FWRITE(FileHandle, FREAD(TempNo2,263))
    =FCLOSE(TempNo2)
  ENDIF
ENDIF

IF FileLen != FirstRecPos AND !Alpha5
  =FSEEK(FileHandle, FileLen-1)
  =FWRITE(FileHandle, CHR(26), 1) && eof mark
ENDIF

=FCHSIZE(FileHandle, FileLen)

*****************************
PROCEDURE WaitWin
* General 'Wait message....' window
* wmsg contents prints the message
* Window is released if wmsg is empty
PARAMETER wmsg
IF NOT WEXIST("waitwin")
  IF EMPTY(wmsg)
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
  IF EMPTY(wmsg)
    RELEASE WINDOW waitwin
    RETURN
  ENDIF
ENDIF
ACTIVATE WINDOW waitwin

IF _DOS
  @ 1,2 SAY wmsg ;
    SIZE 1.000,65.000 ;
    STYLE "B" ;
    PICTURE "@I"
ELSE
  @ 1.462,0.200 SAY wmsg ;
    SIZE 1.000,IIF(_MAC, 64.0, 56.0) ;
    FONT (MsgFont), 10 ;
    STYLE "B" ;
    PICTURE "@I" ;
    COLOR RGB(,,,255,255,255)
ENDIF
RETURN

****************
  PROCEDURE WriteMemoH
  PARAMETER MHandle, mBlockSize
  * Writes a memo header
  * Calculates next block pos from file size - use after creating block
  PRIVATE TempS, FirstBlock, NextFreeBlock, MemoEnd, mBSize
  mBsize = IIF(FileType=131, 512, mBlockSize)
  FirstBlock = CEILING(512/mBSize)
  MemoEnd=FSEEK(MHandle, -1, 2) && check if memofile has any size now
  MemoEnd=IIF(MemoEnd < 511, 511, MemoEnd) && should be at least 512 bytes long
  NextFreeBlock = CEILING((MemoEnd+1)/mBSize)
  TempS=Int2Byte(NextFreeBlock, 4, IIF(FileType=131,1,-1));
    +CHR(0)+CHR(0);
    +Int2Byte(mBSize, 2, -1);
    +REPLICATE(CHR(0), FirstBlock*mBSize-8)
  =PutString(MHandle, 0, TempS)
  =FCHSIZE(MHandle, NextFreeBlock*mBSize)
  IF FileType!=131 AND NextFreeBlock > FirstBlock
    * check if first block has valid 8 bytes and change to 1 byte memo signal if not
    * else it will give false signal next time and force memo salvage
    =IIF(GetValue(MHandle, FirstBlock*mBSize, 4, -1 ) > 2,;
      PutValue(MHandle, FirstBlock*mBSize,   1, 4, -1);
      +PutValue(MHandle, FirstBlock*mBSize+4, 1, 4, -1) , 0)
  ENDIF
  RETURN NextFreeBlock

  ************
  PROCEDURE PutString
  * Writes xString at FileLoc
  PARAMETERS FileHandle, Fileloc, xString
  =FSEEK(FileHandle, Fileloc)
  RETURN FWRITE(FileHandle, xString)

Procedure MessageBox
Parameters Msg, MsgType, MsgTitle
Return rMsgBox(Msg, MsgType, MsgTitle)
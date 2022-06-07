*****************************************************
* Procedure Msalvage
*****************************************************
* Memo salvage routine:
* Places memo pointer info from DBF file into ordered table _RecoverTf
* calls Trace or SPM, or cleanup memo pointers according to option codes
* and completes memo salvage. AND as of 12-3-01 extracts hiden extraneous
* memos from FPT file.
*****************************************************
PARAMETER DBhandle
EXTERNAL ARRAY MemProp
IF FileType=131 OR Alpha5 OR (!mTraceM AND !SPMm AND !RepMptrsM AND !SaveExtraM)
  * Memo is OK or no trace/spm/pointer recovery permitted
  RETURN .F.
ENDIF
IF (MemoOk OR MScanLevel==0) AND !SaveExtraM && This permits Save Extra Memos only even if memoOK or no scan request
  RETURN .F.
ENDIF

PRIVATE SalvageMsg, MFind, TempNo, SPMflag, ExtCount
** Notes: Records are counted from 0 to ActRecords-1
** Blocks are counted from 0 to last - block 8 starts at 8*mBlockSize in memofile
SPMflag = .F.

ExtCount = 0 && the number of extraeous memos found and stored into RecoverM

SELECT RecoverDef
GO TOP

=MemoScan(.F.) && finish creating _RecoverTf if not done.

SELECT _RecoverTf
IF RECCOUNT()=0 AND !SaveExtraM && allow empty memos for saving extraneous ones
  * all record memo pointers are null - just empty memo file
  USE IN _RecoverTf
  =EmptyMemo(MemoHandle, .T.)
  RETURN .T.
ENDIF
INDEX ON memo_at TAG memo_at && needed

MFind = 0 && +1 for successfull FindBlocks(), -1 for unsuccessfull
PrevSec = SECONDS()
RepMsg1 = "Recover - " + GM(57, "Classifying .DBF memos...")
RepMsg2 = ''

* write difference pattern
* INDEX ON RECN TAG RECN && _RecoverTf && ???
SET ORDER TO BlockNo

GO TOP
IF !mTraceM OR !MTraceFlag
  * for non trace methods
  * number ordered records consecutively,
  *  get span's and BlockCounts for SPM or memorepair
  PRIVATE TempNo0, TempNo, TempNo2, i
  TempNo2 = BlockNo
  i=0
  TempNo0= 0
  SCAN && _RecoverTf
    REPLACE ix WITH i
    i=i+1
    =UserReport(i)
    SKIP
    IF !EOF("_RecoverTf")
      TempNo = BlockNo
      SKIP -1
      REPLACE _RecoverTf.span WITH TempNo-BlockNo
      TempNo0 = TempNo0 + _RecoverTf.span
      REPLACE BlockCount WITH TempNo0
    ENDIF
  ENDSCAN && _RecoverTf
  * this doesn't get span/blockcount for last record - length unknown
  RELEASE TempNo0, TempNo, TempNo2, i
  GO TOP
ENDIF
SalvageMsg= ''
IF mTraceM AND MTraceFlag && Trace method
  SalvageMsg = Mtrace()
ENDIF

IF EMPTY(SalvageMsg) AND SPMm && check if SPM
 SalvageMsg = SPM()
ENDIF

IF EMPTY(SalvageMsg) AND RepMptrsM
  SalvageMsg=RepairMemoPs() && corrects overlaping/crosslinked/illegal memos & reports
ENDIF

IF SaveExtraM
  IF !USED("_RecoverMf") && extract extraneous memos
    =StoreExtr()
  ENDIF
  ErrFixes = Wmsg(1, ErrFixes, ALLT(STR(ExtCount)) + " " + GM(79, "extraneous memos extracted!"))
  RecMsg   = Wmsg(2, RecMsg,   ALLT(STR(ExtCount)) + " " + GM(79, "extraneous memos extracted!"))
ENDIF

IF !EMPTY(SalvageMsg)
  ErrFixes = Wmsg(1, ErrFixes, SalvageMsg)
ENDIF

SELECT _RecoverTf
IF RECCOUNT("_RecoverTf") > 0 && matched memos ("f" fitted)
  COUNT FOR _RecoverTf.memo_at > -1 TO TempNo && the number fitted
  ErrFixes = Wmsg(1, ErrFixes, ALLT(STR(TempNo))+"/"+ALLT(STR(RECCOUNT("_RecoverTf"))) + " " + GM(80, "memos recovered!"))
  RecMsg   = Wmsg(2, RecMsg,   ALLT(STR(TempNo))+"/"+ALLT(STR(RECCOUNT("_RecoverTf"))) + " " + GM(80, "memos recovered!"))
ENDIF
IF USED("_RecoverMf")
  USE IN _RecoverMf
ENDIF
IF USED("_RecoverHv")
  USE IN _RecoverHv
ENDIF
USE IN _RecoverTf
RETURN && Msalvage end

**------------------------------
PROCEDURE StoreExtr
* store extraneous memos from SPM method into RecoverM
**** NOTE: store also extraneous gen/pict memos for Trace method - if all not found
IF !SaveExtraM && (MtraceFlag OR !SPMm) AND !SaveExtraM
  RETURN
ENDIF

=WaitWin(GM(78, "Saving extraneous memos to") + " RecoverM.dbf. 1/4")
IF !USED("_RecoverMf") && need to generate _RecoverMf
  =FindBlocks("StoreE: ")
ENDIF
IF !USED("_RecoverMf") && RecoverMf not created according to memofile selected requirements
  RETURN
ENDIF

SELECT _RecoverMf
PRIVATE RecMhndl, FilePos, NoFitCnt, RecMPos, PtrStr
COUNT FOR !_RecoverMf.fitted TO NoFitCnt
COUNT TO TempNo
=WaitWin(GM(78, "Saving extraneous memos to")+ " RecoverM.dbf. 2/4")
IF NoFitCnt = TempNo && probably did not use Matchup() - no pointer matches
  * correct _RecoverMf.fitted
  SET RELATION TO pos INTO _RecoverTf
  REPLACE _RecoverMf.fitted WITH .T. FOR !EOF("_RecoverTf") && normal memos are listed in _RecoverTf memo_at > -10
  SET RELATION TO
  COUNT FOR !_RecoverMf.fitted TO NoFitCnt && now correct it
  IF NoFitCnt = 0
    RETURN && nothing extra found
  ENDIF
ENDIF

IF NoFitCnt > 0 && non matched memos may exist - use or crate RecoverM.dbf/fpt
  *  ErrFixes = Wmsg(1, ErrFixes, ALLT(STR(NoFitCnt)) + GM(68, "Storing old/non-matched memos" ) + " ==> RecoverM.dbf/fpt file!" +CRLF)
  ErrFixes = Wmsg(1, ErrFixes, GM(68, "Storing old/non-matched memos" ) + " ==> RecoverM.dbf/fpt file!" +CRLF)
  PRIVATE Rsize, DispG, DISPP, DBFpath, Fcnt, Rcount
  Rcount = 0
  Rsize = 1+10+10+10+64+20 && these numbers have to be dealt with individually in CreateRecM()
  Fcnt = 5 && RecoverM field count
  DBFpath = ALLT(RIGHT(FULLPATH(DBFfile),64))
  DispG = 10 && displacement of GenMemo field from Text memo
  DISPP = 10+10 && ............ PictMemo ..........

  SELECT 0
  ON ERROR * && it may not exist
  USE RecoverM EXCLUSIVE
  ON ERROR

  IF RECSIZE() != Rsize
    USE
    =CreateRecM(Rsize, Fcnt) && creates FPx type table - so that it can be used with both FPx and VFP
    USE RecoverM EXCLUSIVE
  ELSE
    DELETE FOR ALLT(TableName) = DBFpath
    PACK
  ENDIF
  Rcount = RECCOUNT("RecoverM")

  PrevSec = SECONDS()
  RepMsg1 = GM(78, "Saving extraneous memos to")+ " RecoverM.dbf. - 3/4 "
  RepMsg2 = ''
  
  select _RecoverMf
  replace _RecoverMf.Extr_valid with .F. for fitted && reduces some expressions below - _RecoverMf.FITTED not needed

  *IF !SPMm && skip this in case SMP using this routine - remove 7-15-03 eliminates good displaced memos
  *  * eliminate potential extra memos not starting at block positions
  *  REPLACE _RecoverMf.Extr_valid WITH .F. FOR _RecoverMf.Extr_valid AND (_RecoverMf.pos % mBlockSize) != 0
  *ENDIF

  * eliminate all potential extra memos going beyond file length
  REPLACE _RecoverMf.Extr_valid WITH .F. FOR _RecoverMf.Extr_valid;
    AND _RecoverMf.pos + _RecoverMf.BLOCKS*mBlockSize > memolen

  * eliminate any potential extra memos spanned by fitted (real) memos
  PRIVATE nPos, nBLocks, nRecNo, InvalidMemo
  nPos = 0
  nBLocks = 0
  SCAN && _RecoverMf
    IF _RecoverMf.fitted && this is a real, fitted memo
      nPos = _RecoverMf.pos
      nBLocks = _RecoverMf.BLOCKS
    ENDIF
    IF nBLocks > 0 AND _RecoverMf.Extr_valid AND nPos + nBLocks*mBlockSize > _RecoverMf.pos && overlaped by real memo
      REPLACE _RecoverMf.Extr_valid WITH .F.
    ENDIF
  ENDSCAN

  * Eliminate any potential extra memos overlaping real memos
  nPos = 0
  nBLocks = 0
  nRecNo = 0
  SCAN FOR _RecoverMf.Extr_valid
    nPos = pos
    nBLocks = BLOCKS
    nRecNo = RECNO()
    LOCATE FOR fitted AND Pos > nPos AND nPos + nBLocks*mBlockSize > pos
    InvalidMemo = FOUND()
    GO nRecNo
    IF InvalidMemo
      REPLACE Extr_valid WITH .F.
    ENDIF
  ENDSCAN

  * eliminate any potential extra memos overlaped by previous memos
  * 07/11/03 - skip that - just save all the extra memos as is and let users pick what they want.

  PrevSec = SECONDS()
  RepMsg1 = GM(78, "Saving extraneous memos to")+ " RecoverM.dbf. - 3/4 "
  RepMsg2 = ''

  * store the memos into RecoverM text memos
  SELECT _RecoverMf
  SCAN FOR _RecoverMf.Extr_valid
    ExtCount = ExtCount + 1
    =FSEEK(MemoHandle, _RecoverMf.Pos+8)
    SELECT RecoverM
    APPEND BLANK
    =UserReport(RECNO())
    REPLACE RecoverM.TableName WITH DBFpath;
      RecoverM.Date_Time WITH DTOC(DATE())+' '+TIME();
      RecoverM.Text_Memo WITH FREAD(MemoHandle, _RecoverMf.ByteCount)
    SELECT _RecoverMf
  ENDSCAN
  USE IN RecoverM

  =WaitWin(GM(78, "Saving extraneous memos to")+ " RecoverM.dbf. 4/4")
  * Now check if any are general/picture fields and correct the memo pointers
  RecMhndl = FOPEN("RecoverM.dbf", 2)
  i=Rcount
  SCAN FOR !fitted and Extr_valid
    i=i+1 && RecoverM record number
    IF _RecoverMf.TYPE !=1 && mark appropriate one and unmark the text one
      * Seek record i beginning + 1
      FilePos = FSEEK(RecMhndl, 32+Fcnt*32 + 1 + 1 + (i-1)*Rsize)
      * Get current memo pointer
      PtrStr = FREAD(RecMhndl, 10)
      * replace it with 0 pointer
      = FSEEK(RecMhndl, FilePos)
      = FWRITE(RecMhndl, '         0')
      * Place memo pointer to correct memo type
      RecMPos = IIF(_RecoverMf.TYPE = 2, FilePos + DispG, FilePos + DISPP )
      = FSEEK(RecMhndl, RecMPos)
      = FWRITE(RecMhndl, PtrStr)
    ENDIF
  ENDSCAN
  =FCLOSE(RecMhndl)

ENDIF

*******************
PROCEDURE NewMfile
* rewrites memofile if needed
IF TmemoHandle == MemoHandle && no need to rewrite
  RETURN
ENDIF
PRIVATE NextBlockNo, MemSpan
* write correct memos to TempMemo file
=WaitWin(GM(69, "Copying memos to new file"+"!"))
SELECT _RecoverTf
SET ORDER TO memo_at
PrevSec = SECONDS()
RepMsg1 = GM(69, "Copying memos to new file") +" - "
RepMsg2 = ''
TMemoFile = SYS(3)
TmemoHandle = FCREATE(TMemoFile)
NextBlockNo = EmptyMemo(TmemoHandle) && = first block number
* write blocks found to TMemoFile
SCAN FOR _RecoverTf.memo_at > -10
  =UserReport(_RecoverTf.RECN)
  =FSEEK(MemoHandle, _RecoverTf.memo_at)
  =FSEEK(TmemoHandle, NextBlockNo*mBlockSize)
  MemSpan = IIF(_RecoverTf.msize=0, _RecoverTf.span, CEILING((_RecoverTf.msize+8)/mBlockSize))
  =READWRITE(MemoHandle, TmemoHandle, MemSpan*mBlockSize)
  =SetMPointer(DBhandle, _RecoverTf.RECN, MemProp(_RecoverTf.MemNo, 1), NextBlockNo)
  NextBlockNo = NextBlockNo + MemSpan
ENDSCAN
=WaitWin()

*******************
PROCEDURE READWRITE
* reads Nbytes from Handle1 and
* writes it to Handle2 file
* useful when the Nbytes is large and might exhaust memory.
PARAMETERS Fhandle1, Fhandle2, Nbytes
DO CASE
CASE Fhandle1<0 OR Fhandle2<0
  RETURN 0
CASE Nbytes < 2049 && faster for small writes
  RETURN FWRITE(Fhandle2, FREAD(Fhandle1, Nbytes))
OTHERWISE
  PRIVATE i, TempNo
  i=0
  DO WHILE i<Nbytes AND !FEOF(Fhandle1)
    TempNo = IIF(Nbytes-i>2048, 2048, Nbytes-i)
    i=i+FWRITE(Fhandle2, FREAD(Fhandle1, TempNo))
  ENDDO
  RETURN i
ENDCASE

**************************************
** Trace Method for memos           **
**************************************
* recovers memos with traces
PROCEDURE Mtrace

* note - leave MemoHandle as is unless any found memo_at is not at a mBlockSize boundary -
* then use tMemoHandle - for rewrite.
* correct each memo pointer in DBFhandle as long as new-found-memos are on boundary
* otherwise set flag to write new tMemoHandle

IF !MTraceFlag
  RETURN ''
ENDIF
PRIVATE SrchPos, Mcount, MfileCode, OffSet
PrevSec = SECONDS()

SELECT _RecoverTf
INDEX ON MemProp[MemNo, 3] + MemoCode TAG TotMemCode

* The following reverse search memo method used in order to find the most recent memos
RepMsg1 = GM(31, "Trace method searching memo file -") +" "
RepMsg2 = ''
PRIVATE xi && for user report
SrchPos = memolen
xi=0
DO WHILE SrchPos > -1
  SrchPos = SrchFbak(MemoHandle, SrchPos-4, 0, TextType)
  xi = xi+1
  =UserReport(xi)
  IF SrchPos => 0
    MfileCode = GetString(MemoHandle, SrchPos+8, 19) && possible text memocode
    IF SEEK(MfileCode) AND memo_at < 0
      REPLACE msize WITH GetValue(MemoHandle, SrchPos+4, 4, -1), _RecoverTf.memo_at WITH SrchPos, _RecoverTf.GROUP WITH 1
      =CheckBegin() && check if memo is too close to begin of file - but code still intact
      IF SrchPos%mBlockSize != 0 OR SrchPos < 512
        TmemoHandle = 0 && flag => memo file needs to be rewritten
      ELSE && just correct BlockNo & pointer
        REPLACE BlockNo WITH SrchPos/mBlockSize
        =SetMPointer(DBhandle, _RecoverTf.RECN, MemProp(_RecoverTf.MemNo, 1), SrchPos/mBlockSize)
      ENDIF
    ENDIF
  ENDIF
ENDDO

COUNT FOR MemNo = 1 AND memo_at > -1 TO Mcount

* attempt to assign Memo_at for other memo types
** scan from top end
=WaitWin(GM(59, "Checking for general field memos -")+" 1/2.")
SET ORDER TO BlockNo

=FindOther() && also fixes 0 span

** scan from bottom end
=WaitWin(GM(59, "Checking for general field memos -")+" 2/2.")
SET ORDER TO BlockNo DESCENDING
=FindOther()

SET ORDER TO memo_at

=CheckMemos() && check & fix missing memos, crosslinks, overlaps & spans

* leave order to memo_at when trace method used

=NewMfile()

=WaitWin("")
=WriteMemoH(TmemoHandle, mBlockSize) && fix Memo header - TMemoHandle could be MemoHandle

SET FILTER TO

RETURN GM(60, "Recover memo trace:") + " "

*********
PROCEDURE CheckMemos
* Checks/corrects pointer and memo errors
* Check if:         Action:
* Missing memo      report (RepMissing()) & set pointer to 0
* Overlapping memo 	correct memo size
* crossed memo      move memo to end, report (RepCrossLink()) & correct span if overlaping

** This should be the last action in msalvage - except CopyMemo - since resulting span may not
** be correct for the SPM method

SELECT _RecoverTf
SET ORDER TO memo_at
PRIVATE PrevRec, RecNum, Fname1, Fname2, Rec1, Rec2, NextPos, Rcount
PRIVATE PrevMsize, PrevPos, CurPos, NextRec, FirstRec

PRIVATE FirstLink, FirstMis, LastMis
FirstLink = .T.
FirstMis = .T.
LastMis = .F.
RepMsg1 = "A) " + GM(52, "Memo scan level") +" 2 - "
RepMsg2 = ''
* report/skip all missing memos.
GO TOP
Rcount = RECCOUNT()

DO WHILE memo_at == -10
  =UserReport(_RecoverTf.RECN)
  =RepMissing(MemProp[_RecoverTf.MemNo, 3], _RecoverTf.RECN)
  =SetMPointer(DBhandle, _RecoverTf.RECN, MemProp[_RecoverTf.MemNo, 1], 0)
  Rcount = Rcount - 1 && another record treated
  PrevRec = RECNO()
  SKIP
ENDDO && now its past all missing memos

* Scan for crosslinks && 0 span / same pos.
IF Rcount > 1 && must be at least 2 records left over for crosslink checking
  Fname1 = MemProp[_RecoverTf.MemNo,3]
  Rec1 = _RecoverTf.RECN
  PrevPos = memo_at
  PrevMsize = msize
  PrevRec = RECNO()
  Rcount = Rcount - 1
  SKIP && now it is on 2nd non-missing memo

  DO WHILE Rcount > 0 AND !EOF()
    Rcount = Rcount - 1 && another record checked
    =UserReport(_RecoverTf.RECN)
    RecNum = RECNO()
    SKIP
    NextRec = IIF(EOF(), -1, RECNO()) && need next record in case current is moved to end with memo_at change
    SKIP -1
    CurPos = memo_at

    * correct any crosslinks
    ** if new memo_at is same as prev => crosslinked
    IF memo_at == PrevPos && Crosslinked memo with prev
      Fname2 = MemProp[_RecoverTf.MemNo,3]
      Rec2 = _RecoverTf.RECN
      =RepCrossLink(Fname1, Rec1, Fname2, Rec2)
      * Check/correct memo size (msize)
      ** skip past possible further crosslinked memos
      DO WHILE memo_at == CurPos AND !EOF()
        SKIP
      ENDDO
      ** good way to set msize
      NextPos = IIF(EOF(), CEILING(memolen/mBlockSize)*mBlockSize, memo_at)
      GO PrevRec
      ** if msize is 0 or too big - correct it.
      IF msize = 0 OR msize > NextPos - PrevPos - 8
        REPLACE msize WITH NextPos - PrevPos - 8,;
          span WITH CEILING((NextPos - PrevPos)/mBlockSize)
        * correct the actual msize in memo
        * but this really needs to be done only once
        =PutValue(MemoHandle, memo_at+4, NextPos - PrevPos - 8, 4, -1)
      ENDIF
      ** check/correct 0 span or too large span
      IF span = 0 OR span > (NextPos - PrevPos)/mBlockSize
        REPLACE span WITH CEILING((NextPos - PrevPos)/mBlockSize)
      ENDIF
      ** copy memo to the end of memofile and adjust record pointer
      REPLACE memo_at WITH CopyMemo(MemoHandle, memo_at, CHR(0)+CHR(0)+CHR(0) + CHR(MemProp[MemNo, 2]), msize)
      * CopyMemo returns the start pos of memo written
    ENDIF
    GO RecNum
    PrevRec = RECNO()
    Fname1 = MemProp[_RecoverTf.MemNo,3]
    Rec1 = _RecoverTf.RECN
    PrevPos = memo_at
    PrevMsize = msize
    IF Rcount > 0
      GO NextRec
    ENDIF
  ENDDO
ENDIF

*----------
* CheckFor & correct overlaps
*----------
** skip lost memo pointers
* GO TOP
* DO WHILE Memo_at = -10
*  SKIP
* ENDDO
LOCATE FOR memo_at != -10
PrevRec = RECNO()
PrevPos = memo_at
PrevMsize = msize

RepMsg1 = "B) "+GM(52, "Memo scan level")+" 2 - "

FirstRec = RECNO()
DO WHILE memo_at > -10 AND !EOF("_RecoverTf")
  * if prev memo overlapping - trim it
  RecNum = RECNO()
  =UserReport(_RecoverTf.RECN)
  NextPos = memo_at
  IF RECNO()!=FirstRec AND (PrevPos + PrevMsize + 8 => memo_at OR PrevMsize = 0)
    * if msize is too big - correct it.
    GO PrevRec
    IF msize > NextPos - memo_at - 8 OR msize = 0
      REPLACE msize WITH NextPos - memo_at - 8,;
        span WITH CEILING((NextPos - memo_at)/mBlockSize)
      * correct the actual msize in memo
      =PutValue(MemoHandle, memo_at+4, NextPos - memo_at - 8, 4, -1)
    ENDIF
    GO RecNum && back to current record
  ENDIF
  PrevRec = RECNO()
  PrevPos = memo_at
  PrevMsize = msize
  SKIP
ENDDO

GO BOTTOM
* check last memo memosize - otherwise may get invalid memo file on pack
IF memo_at + msize + 8 > memolen
  REPLACE msize WITH memolen - memo_at - 8,;
    span WITH CEILING((memolen - memo_at)/mBlockSize)
  * correct the actual msize in memo
  =PutValue(MemoHandle, memo_at+4, memolen - memo_at - 8, 4, -1)
ENDIF

*********
PROCEDURE FindOther
* scans to attempt find non-text memos for trace method.
PRIVATE OffSet, TempNo, TempNo1
OffSet = 0

SCAN
  IF memo_at > -10
    OffSet = _RecoverTf.memo_at - _RecoverTf.BlockNo*mBlockSize
    *    =Check0Span()
  ELSE && missing memo - try find at offset.
    TempNo = _RecoverTf.BlockNo*mBlockSize + OffSet && possible new location
    TempNo1 = CEILING((GetValue(MemoHandle, TempNo + 4, 4, -1) + 8)/mBlockSize)*mBlockSize && (its size in integer blocks) x mBlockSize
    IF GetString(MemoHandle, TempNo, 4) = CHR(0)+CHR(0)+CHR(0)+CHR(MemProp[_RecoverTf.MemNo, 2])
      REPLACE msize WITH GetValue(MemoHandle, TempNo+4, 4, -1),;
        _RecoverTf.memo_at WITH TempNo, _RecoverTf.GROUP WITH 1
      OffSet = _RecoverTf.memo_at - _RecoverTf.BlockNo*mBlockSize
      *      IF _RecoverTf.span < TempNo1/mBlockSize
      *        REPLACE _RecoverTf.span WITH TempNo1/mBlockSize
      *      ENDIF
      Mcount = Mcount + 1
      =UserReport(Mcount)
    ENDIF
  ENDIF
ENDSCAN

**
PROCEDURE Check0Span
* checks for tail end 0 span - and corrects it
IF _RecoverTf.span > 0
  RETURN
ENDIF
REPLACE _RecoverTf.span WITH CEILING((GetValue(MemoHandle, _RecoverTf.memo_at + 4, 4, -1) + 8)/mBlockSize)

*********
PROCEDURE CheckBegin
* Check in case memo too close to begin of memofile with missing memoheader
IF _RecoverTf.memo_at => 0
  RETURN
ENDIF
PRIVATE MemoSize
* move the complete memo to end of memo file
** Estimate memo size - from actual or next dif.
=FSEEK(MemoHandle, _RecoverTf.memo_at+8)
MemoSize = IIF(_RecoverTf.memo_at>3, GetValue(MemoHandle, _RecoverTf.memo_at+4, 4, -1 ), 0)
MemoSize = IIF(MemoSize >0 AND MemoSize <= _RecoverTf.span, MemoSize, MAX(_RecoverTf.span*mBlockSize, 1)) && ???
** copy memo to end of memofile and correct pointer in record
REPLACE _RecoverTf.memo_at WITH CopyMemo(MemoHandle, _RecoverTf.memo_at, TextType, MemoSize) && new location of corrected memo

*******
PROCEDURE CopyMemo
* copies memo from Mat1 to MemoLen (end of memofile)
*** TESTED OK 5-15-97
PARAMETER Mhandle, Mat1, MemoType, MemoSize
PRIVATE i, MemStr, MemPos
i = 0 && Bytes of memo written

* new memo must be at integer mBlockSize units - for appending.
MemPos = IIF( memolen%mBlockSize == 0,;
  memolen,;
  FCHSIZE(Mhandle, CEILING(memolen/mBlockSize)*mBlockSize))

* write memo block header
=PutString(MemoHandle, MemPos, MemoType + int2byte(MemoSize, 4, -1))
i = 0 && Bytes of memo written
IF MemoSize <= 2048
  MemStr = GetString(Mhandle, Mat1+8, MemoSize) && read memo contents
  =PutString(Mhandle, MemPos + 8, MemStr)
ELSE && memo too large - might run out of ram
  DO WHILE i != MemoSize
    IF MemoSize > i + 2048
      MemStr = GetString(Mhandle, Mat1 + 8 + i, 2048) && read memo contents
      =PutString(Mhandle, MemPos + 8 + i, MemStr)
      i = i + 2048
    ELSE
      MemStr = GetString(Mhandle, Mat1 + 8 + i, MemoSize-i) && read memo contents
      =PutString(Mhandle, MemPos + 8 + i, MemStr)
      i = MemoSize
    ENDIF
  ENDDO
ENDIF

* now correct pointer in record
=SetMPointer(DBhandle, _RecoverTf.RECN, MemProp(_RecoverTf.MemNo, 1), MemPos/mBlockSize)

memolen = FSEEK(Mhandle, 0, 2) && new memo file length

RETURN MemPos && start position of moved memo

*********
PROCEDURE GetSpan
* gets/estimates memo span (mBlockSize units)
PARAMETER SpanType
PRIVATE TempNo
IF SpanType = 'E' && for end of _RecoverTf with _RecoverTf.span = 0
  IF _RecoverTf.span=0 AND _RecoverTf.memo_at>-1
    TempNo = GetValue(MemoHandle, _RecoverTf.memo_at+4, 4, -1 )
    IF TempNo - _RecoverTf.memo_at < 1.1 * memolen && allow 10% spill over eof
      RETURN CEILING(TempNo/mBlockSize)
    ENDIF
  ENDIF
  RETURN _RecoverTf.span
ELSE && other type
  TempNo = IIF(_RecoverTf.memo_at>3, GetValue(MemoHandle, _RecoverTf.memo_at+4, 4, -1 ), 0)
  RETURN IIF(TempNo >0 AND TempNo <= _RecoverTf.span, TempNo/mBlockSize, MAX(_RecoverTf.span, 1)) && ???
ENDIF

**************************************
** SPM Method                       **
**************************************
PROCEDURE SPM
* (S)tatistical (P)attern (M)atching routine
* Essentially matches DBF specified memo pattern (length & type) with found memo groups
* restores memo file - using correction of memo pointers (if few bad pointers) or statistical pattern matching.
* returns % memo restoration confidence level
PRIVATE TempNo, Ratio, MemosFound
COUNT FOR _RecoverTf.memo_at > -1 TO MemosFound
Ratio = MemosFound/RECCOUNT('_RecoverTf')

* Do not use SPM if 90% memos found for larger memo count
* or for 70% for > 12 memos or for 2 of 3+ memos found.
IF  (Ratio => 0.9 AND RECCOUNT('_RecoverTf')>29);
    OR (Ratio => 0.7 AND MemosFound >12);
    OR (RECCOUNT('_RecoverTf')-MemosFound < 3 AND MemosFound >3);
    OR MemosFound > 5000
  RETURN ''
ENDIF

* get actual memofile patterns
=WaitWin(GM(61, "SPM: Searching memofile for memos.."))
IF !FindBlocks("SPM: ") && too many blocks => incorrect mblocksize
  RETURN '' && cannot recover with SPM': incorrect memo blocksize' + CRLF
ENDIF

* find best matches for found pieces
SPMflag = .T.
=Matchup()

*USE IN _RecoverHv

* Now check if memolocations are on block 'integers'
* flag NewMemoFile required if any not such.
* Otherwise just correct pointer/blockno
SELECT _RecoverTf
SCAN FOR _RecoverTf.memo_at > -10 AND _RecoverTf.BlockNo != _RecoverTf.memo_at/mBlockSize
  IF _RecoverTf.memo_at%mBlockSize != 0 OR _RecoverTf.memo_at < 512
    TmemoHandle = 0 && flag => memo file needs to be rewritten
    EXIT
  ELSE && just correct BlockNo & pointer
    REPLACE BlockNo WITH _RecoverTf.memo_at/mBlockSize
    =SetMPointer(DBhandle, _RecoverTf.RECN, MemProp(_RecoverTf.MemNo, 1), _RecoverTf.memo_at/mBlockSize)
  ENDIF
ENDSCAN

SET ORDER TO memo_at
=CheckMemos() && check & fix missing memos, crosslinks, overlaps & spans
=NewMfile()
=WriteMemoH(TmemoHandle, mBlockSize) && fix Memo header - TMemoHandle could be MemoHandle
=StoreExtr() && store Extraneous memos into RecoverM.dbf/fpt
* USE IN _RecoverMf

* SELECT _RecoverTf

RETURN "SPM: " && leave 'SPM:' as is - no language translation needed

************************
PROCEDURE FindBlocks && SPM
Parameter cOption
** Note: records are counted from 1 to ActRecords, not 0 to ActRecords-1
** Blocks are counted from 0 to last - block 8 starts at 8*mBlockSize in memofile
* create cursor used for SPM - memo group matching
CREATE CURSOR _RecoverHv (VALUE N(10,4), NdMemoCnt N(10), MultiFit N(10),;
  FitProb N(10,4), GROUP N(6), FitAttempt N(5))

* create cursor to store all memo info about all possible memos in memo file.
CREATE CURSOR _RecoverMf (ix N(10), pos N(10), ByteCount N(10), BLOCKS N(10), TYPE N(1), MatchW_i N(6), span N(10), BlockCount N(10), fitted L, Extr_valid L)

* Searches through MemoFile for likely memo positions - for the SPM method
SELECT _RecoverMf
PRIVATE ToSearch, j, imc, N, TempNo, TempNo0, TempNo1, TempNo2, TempS1, TempS2, TempSx LASTM
DIMENSION LASTM[5]
TempS1 = CHR(0)+CHR(0)+CHR(0)
TempS2 = TempS1+CHR(0)

* - search for possible memos locations in memofile
* - store each with sequence number, file pos, indicated block count,
*   memo type, sequence No of block it matches first (first is -ve),
*   block count dif from prev block.
LASTM=-1
N = LEN(MemoTypes)
imc = 0 && memo count
PrevSec = SECONDS()
RepMsg1 = ''
RepMsg2 = " " + GM(62, "memo locations found!")

FOR j=1 TO N
  ToSearch = .T.
  DO WHILE ToSearch
    LASTM[j] = Srchfile(MemoHandle, LASTM[j]+1, memolen, TempS1+CHR(VAL(SUBSTR(MemoTypes, j,1))))
    = FREAD(MemoHandle, 4) && skip 4 bytes
    * get indicated memosize String
    TempSx = FREAD(MemoHandle, 4)
    TempNo2 = byte2int(TempSx, -1)
    * TempNo1 = approx indicated block count (size)
    TempNo1 = (TempNo2+8)/mBlockSize && also good for VFP special mBlockSize = 1
    TempNo1 = IIF(INT(TempNo1)<TempNo1, INT(TempNo1)+1, INT(TempNo1))
    IF LASTM[j] > -1 && something found
      * insert if length > 0000 and length ~ not beyond real file
      IF LASTM[j]+TempNo2 <= memolen +10 AND TempSx > TempS2
        INSERT INTO _RecoverMf VALUES(0, LASTM[j], TempNo2, TempNo1, VAL(SUBSTR(MemoTypes, j, 1)), 0, 0, 0, .F., .T.)
        imc = imc + 1
      ENDIF
      ToSearch = LASTM[j]+8 < memolen
    ELSE && nothing more found - stop searching for this MemoType
      ToSearch = .F.
    ENDIF
    =UserReport(imc)
  ENDDO
ENDFOR

=WaitWin(GM(63, cOption + "Sorting located memos -") +" 1/6")
* write sequential ordering numbers
INDEX ON pos TAG pos
=WriteIx()

=WaitWin(GM(63, cOption + "Sorting located memos -") +" 2/6")
PRIVATE StartPos, PrevPos, PrevByteC, SingleCount
SingleCount = 0
  PrevSec = SECONDS()
  RepMsg1 = GM(63, cOption + "Sorting located memos -") +" 2/6 - "
  RepMsg2 = ''

* Write matching Group numbers "matchw_i"
GO TOP && _recoverMf
i = 0 && group count
LOCATE FOR MatchW_i=0 && all the non group matched memos
DO WHILE FOUND()
  i=i+1
  StartPos = _RecoverMf.pos
  PrevPos = StartPos
  PrevByteC = _RecoverMf.ByteCount
  REPLACE MatchW_i WITH -(i)
  =UserReport(RECNO("_recoverMf"))
  SCAN FOR (_RecoverMf.pos - StartPos) % mBlockSize = 0 AND _RecoverMf.pos != StartPos
    IF PrevPos + 7 + PrevByteC > _RecoverMf.pos && overlaping memo
      SEEK PrevPos
      REPLACE MatchW_i WITH IIF(MatchW_i>-1, 0, MatchW_i)
      EXIT
    ENDIF
    SingleCount = 0 && at least one non single group exists
    REPLACE MatchW_i WITH i
    PrevPos = _RecoverMf.pos
    PrevByteC = _RecoverMf.ByteCount
  ENDSCAN
  SingleCount = SingleCount + 1
  * Check if single group count > 60% of found memos => too many groups => probably wrong mBlockSize in .def file
  IF SPMm AND SingleCount = i AND i > 0.6*RECCOUNT("_RecoverMf") AND RECCOUNT("_RecoverMf") > 5000
    =WaitWin()
    USE IN _RecoverMf
    USE IN _RecoverHv
    MFind = -1
    RETURN .F.
  ENDIF

  GO TOP
  LOCATE FOR MatchW_i=0
ENDDO
WAIT CLEAR
=WaitWin(GM(63, cOption + "Sorting located memos -") +" 3/6")
  PrevSec = SECONDS()
  RepMsg1 = GM(63, cOption + "Sorting located memos -") +" 3/6 - "
  RepMsg2 = ''

* eliminate bogus groups
PRIVATE FirstMatch, FirstRecnum

IF mBlockSize > 1
  * Eliminate smaller overlapped Groups
  * setup temp table for this
  CREATE CURSOR _RecoverTp (MatchW_i N(6), START N(10), END N(10), VALUE N(10))
  INDEX ON START TAG START
  SELECT _RecoverMf
  SCAN FOR MatchW_i < 0 AND !DELETED() && _RecoverMf.
    FirstMatch = MatchW_i
    FirstRecnum = RECNO()
    SET FILTER TO ABS(MatchW_i) = -FirstMatch AND !DELETED()
    GO TOP
    TempNo0 = pos
    COUNT TO TempNo2
    GO BOTTOM
    TempNo1 = pos
    * save matchw_i/first/last pos / width
    INSERT INTO _RecoverTp VALUES( ABS(_RecoverMf.MatchW_i), TempNo0, TempNo1, TempNo2)
    =UserReport(RECCOUNT("_RecoverTp"))
    SET FILTER TO
    GO FirstRecnum && return to origin record in sequence, otherwise scan gets out of sync
  ENDSCAN && _RecoverMf
  WAIT CLEAR

  =WaitWin(GM(63, cOption + "Sorting located memos -") +" 4/6")
  PrevSec = SECONDS()
  RepMsg1 = GM(63, cOption + "Sorting located memos -") +" 4/6 - "
  RepMsg2 = ''
  * now delete overlapped Groups
  SELECT _RecoverTp
  SCAN
    =UserReport(RECNO("_RecoverTp"))
    TempNo = RECNO()
    SCATTER MEMVAR
    LOCATE FOR _RecoverTp.VALUE < m.value*0.67 AND END < m.end AND START > m.START && use two thirds count as criteria
    DO WHILE FOUND()
      SELECT _RecoverMf
      DELETE FOR ABS(_RecoverMf.MatchW_i) = _RecoverTp.MatchW_i
      SELECT _RecoverTp
      CONTINUE
    ENDDO
    GO TempNo
  ENDSCAN
  USE IN _RecoverTp
  SELECT _RecoverMf
ENDIF && eliminate overlapped

WAIT CLEAR
RELEASE FirstMatch, FirstRecnum
=WaitWin(GM(63, cOption + "Sorting located memos -") +" 5/6")
  PrevSec = SECONDS()
  RepMsg1 = GM(63, cOption + "Sorting located memos -") +" 5/6 - "
  RepMsg2 = ''

* eliminate invalid memos - attempt
* Invalid if:
*     Bytecount = 0
*     Bytecount + 8 reaches beyond next starting point
*     10% of Bytecount+8 beyond end of memofile
SELECT _RecoverMf
SET ORDER TO pos DESCENDING
GO TOP
TempNo1 = ix
TempNo = pos
TempNo0 = MatchW_i
SCAN FOR ix!=TempNo1 AND !DELETED() AND mBlockSize > 1 && _RecoverMf.
  =UserReport(RECNO("_RecoverMf"))

  TempNo = TempNo - pos
  IF ((BLOCKS > TempNo/mBlockSize) OR (0.9*BLOCKS*mBlockSize > memolen-pos) OR (ByteCount = 0)) AND MatchW_i = TempNo0
    TempNo2 = RECNO()
    TempNo0 = MatchW_i
    DELETE
    IF TempNo0<0 && -ve start match marker
      TempNo2 = RECNO()
      SET ORDER TO pos ASCENDING
      LOCATE FOR MatchW_i=-TempNo0
      REPLACE MatchW_i WITH -TempNo0
      SET ORDER TO pos DESCENDING
      GO TempNo2
    ENDIF
    SKIP -1
  ENDIF
  TempNo = pos
  TempNo0 = MatchW_i
ENDSCAN && _RecoverMf

WAIT CLEAR
SET ORDER TO pos ASCENDING
=WaitWin(GM(63, cOption + "Sorting located memos -") + " 6/6")
  PrevSec = SECONDS()
  RepMsg1 = GM(63, cOption + "Sorting located memos -") +" 6/6 - "
  RepMsg2 = ''

* write Ix/BlockCount/difference pattern
SELECT _RecoverMf
GO TOP
TempNo = ABS(MatchW_i)
LOCATE FOR ABS(MatchW_i) = TempNo && _RecoverMf
DO WHILE !EOF() && for each matchw_i value
  =UserReport(RECNO("_RecoverMf"))

  SET FILTER TO ABS(MatchW_i) = TempNo AND !DELETED()
  * Now save this Group block info if more than one memo in it
  * (In SPM a single memo is not matched - but just stored into RecoverM.mem)
  COUNT TO TempNo1
  IF TempNo1 > 1
    * Get Group info into _RecoverHv
    INSERT INTO _RecoverHv VALUES(TempNo1, 0, 2, 0, TempNo, 0)
    SET ORDER TO pos DESCENDING
    GO TOP

    *get span
    TempNo2 = pos
    REPLACE span WITH BLOCKS && estimate for last pos
    TempNo0 = ix
    SCAN FOR ix!=TempNo0
      REPLACE span WITH (TempNo2 - pos)/mBlockSize
      TempNo2 = pos
    ENDSCAN
    SET ORDER TO pos ASCENDING

    *Place Ix order numbers and block count
    TempNo2 = 0
    SCAN
      REPLACE BlockCount WITH TempNo2 + span
      TempNo2 = BlockCount
    ENDSCAN

    =WriteIx()
  ENDIF
  SET FILTER TO
  LOCATE FOR ABS(MatchW_i) > TempNo
  TempNo = ABS(MatchW_i)
ENDDO

WAIT CLEAR

SET FILTER TO !DELETED()
MFind = 1

***
PROCEDURE WriteIx
PRIVATE j
GO TOP
j=0
SCAN
  REPLACE ix WITH j
  j=j+1
ENDSCAN

***********************************
PROCEDURE Matchup && SPM
* Locates best relative pos of have memos patterns with need memo patterns (BestI/J/J0)
* Determines for each _RecoverHv record:
*   BestI: The rel. pattern displ. of Have (in have) wrt Need start
*   BestJ0: First memo (Ix) in need for best fit
*   BestJ: Last memo (Ix) in need for best fit
*   MultiCount: No of equivalent fits in pattern - only first fit BestJ/I's are returned

IF RECCOUNT("_RecoverHv")=0 OR MostBlocksFound()
  RETURN
ENDIF

IF RECCOUNT("_RecoverTf") > 5000
  RETURN
ENDIF

SELECT _RecoverTf
REPLACE _RecoverTf.memo_at WITH -1, _RecoverTf.GROUP WITH 0 ALL
SELECT _RecoverMf
GO TOP IN _RecoverMf

PRIVATE HaveLen, NeedLen, FitCount, BestFitCount, BestRelConst, TempConst
PRIVATE MultiCount, IsCount
BestRelConst = 0
BestFitCount = 0
TempConst = 0
PrevSec = SECONDS()

SELECT _RecoverMf
SET FILTER TO !DELETED() AND ABS(_RecoverMf.MatchW_i) = _RecoverHv.GROUP
SET ORDER TO pos
COUNT TO HaveLen

SELECT _RecoverTf
SET FILTER TO memo_at = -1
SET ORDER TO BlockNo
COUNT TO NeedLen


SELECT _RecoverHv
SET FILTER TO MultiFit != 1 && once it is fitted, get it out of the way
INDEX ON MultiFit TAG MultiFit
GO TOP

DO WHILE !EOF("_RecoverHv") && scan all Groups found
  BestRelConst = 0
  BestFitCount = 0
  MultiCount = 0

  SELECT _RecoverMf
  COUNT TO HaveLen

  SELECT _RecoverTf
  COUNT TO NeedLen

  =GetIrange() && get possible _RecoverTf -> _RecoverMf relational constants for this _RecoverHv.Group
  SELECT _RecoverTf
  SET RELATION TO BlockNo*mBlockSize-TempConst INTO _RecoverMf

  RepMsg1 = GM(66, "SPM - Analyzing memo group:")+" "+ ALLT(STR(RECNO("_RecoverHv")))+"/";
    +ALLT(STR(RECCOUNT("_RecoverHv")))+"   Scan: "
  RepMsg2 = "/"+ALLT(STR(RECCOUNT("_RecoverIs")))

  SELECT _RecoverIs
  IsCount = 0 && for user report
  SCAN && scan through all relational constants for best fit of this Group
    IsCount = IsCount + 1
    TempConst = _RecoverIs.Bp
    SELECT _RecoverTf
    FitCount = 0

    SCAN FOR !EOF('_RecoverMf') && scan relation with this rel. const.
      FitCount = FitCount + 1
    ENDSCAN

    MultiCount = IIF(BestRelConst = FitCount, MultiCount+1, MultiCount) && there can be only one bestfitcount found - not multiple times
    IF FitCount > BestFitCount
      BestFitCount = FitCount
      BestRelConst = TempConst
      MultiCount = 1
    ENDIF

    =UserReport(IsCount)

    SELECT _RecoverIs
  ENDSCAN
  SELECT _RecoverTf
  GO TOP

  IF MultiCount = 1 && only one possible fit combination
    TempConst = BestRelConst
    SCAN FOR !EOF('_RecoverMf') && mark found memo locations
      REPLACE _RecoverTf.memo_at WITH _RecoverMf.pos,;
        _RecoverTf.GROUP WITH _RecoverHv.GROUP,;
        _RecoverTf.msize WITH GetValue(MemoHandle, _RecoverMf.pos+4, 4, -1)
      REPLACE _RecoverMf.fitted WITH .T.
    ENDSCAN
    GO TOP
  ENDIF
  SET RELATION OFF INTO _RecoverMf

  SELECT _RecoverHv
  IF MultiCount = 1
    REPLACE _RecoverHv.FitProb WITH BestFitCount/RECCOUNT("_RecoverTf"),;
      _RecoverHv.NdMemoCnt WITH BestFitCount
  ENDIF
  * next will filter out _RecoverHv record if Multicount = 1
  REPLACE _RecoverHv.FitAttempt WITH _RecoverHv.FitAttempt+1,;
    _RecoverHv.MultiFit WITH MultiCount
  SKIP && get next Group

ENDDO
SET FILTER TO
IF USED('_RecoverIs')
  USE IN _RecoverIs
  USE IN _RecoverIc
ENDIF
SELECT _RecoverMf
SET FILTER TO
SELECT _RecoverTf
SET FILTER TO

GO BOTTOM && check last span
REPLACE _RecoverTf.span WITH GetSpan('E')

******

PROCEDURE GetIrange
* get possible _RecoverTf -> _RecoverMf relational constants
IF !USED("_RecoverIs") && first Group to fit
  CREATE CURSOR _RecoverIs (Bp N(11))
  INDEX ON Bp TAG Bp DESCENDING
  CREATE CURSOR _RecoverIc (Bc N(11))
  INDEX ON Bc TAG Bc
ELSE && already created for a previous Group
  SET SAFETY OFF
  SELECT _RecoverIs
  ZAP
  SELECT _RecoverIc
  ZAP
  SET SAFETY ON
ENDIF
PRIVATE TempNo, TempNo2, i, j, Jmax
PrevSec = SECONDS()
RepMsg1 =  GM(67, "SPM: Calculating memo scan range -") + " "
RepMsg2 = ''
i=0
FOR i=HaveLen-NeedLen TO HaveLen-2 && reversed to use increasing i
  GO TOP IN _RecoverTf
  GO TOP IN _RecoverMf
  IF i>0
    SKIP i IN _RecoverMf
  ELSE
    SKIP -i IN _RecoverTf
  ENDIF
  Jmax = HaveLen-IIF(i>0,i,0)-1
  FOR j=0 TO Jmax
    IF (_RecoverTf.span => _RecoverMf.span OR _RecoverTf.span=0);
        AND  MemProp[_RecoverTf.MemNo, 2] = _RecoverMf.TYPE
      TempNo = _RecoverTf.BlockNo*mBlockSize - _RecoverMf.pos
      TempNo2 =  _RecoverTf.BlockCount - _RecoverMf.BlockCount
      IF !SEEK(TempNo, "_RecoverIs") AND !SEEK(TempNo2, "_RecoverIc")
        INSERT INTO _RecoverIs VALUES (TempNo)
        INSERT INTO _RecoverIc VALUES (TempNo2)
      ENDIF
    ENDIF
    SKIP IN _RecoverTf
    SKIP IN _RecoverMf
  ENDFOR
  =UserReport(HaveLen-2-i)
ENDFOR
SELECT _RecoverIs
GO TOP

* Graphical Illustration
*
*      _RecoverTf    _RecoverMf
*                         __
*                        |
*                        |
*                        |
*                        |
*                      N | i
*                      e |
*                      e |
*                      d |
*          ____________L_| __
*         |            e |
*         |            n |
*    H    |              | Jmax
*    a    |              |
*    v    |              |
*    e    |------------------
*    L    |
*    e    |
*    n    |
*         |
*         |
***
PROCEDURE FitCheck
* checks if type could match prior, in case of different types AND spans at current pos
IF  MemProp[_RecoverTf.MemNo, 2] = _RecoverMf.TYPE && obvious match
  RETURN .T.
ELSE
  IF _RecoverTf.span = _RecoverMf.span
    RETURN .F.
  ENDIF
ENDIF
* Types and spans differ
PRIVATE RecnTf, TempNo, RetVal
RecnTf = RECNO("_RecoverTf")
TempNo = _RecoverTf.span
TempNo = TempNo - _RecoverMf.span
SELECT _RecoverTf
SET RELATION OFF INTO _RecoverMf && this doesn't move _RecoverMf pointer???
DO WHILE TempNo > 0 AND !BOF("_RecoverMf")
  SKIP -1 IN _RecoverMf
  TempNo = TempNo - _RecoverMf.span
ENDDO
RetVal = IIF(TempNo = 0 AND !BOF("_RecoverMf") AND MemProp[_RecoverTf.MemNo, 2] = _RecoverMf.TYPE, .T., .F.)
SET RELATION TO BlockCount-i INTO _RecoverMf
GO RecnTf
RETURN RetVal

*******************
PROCEDURE MostBlocksFound
* check if most memoblocks can fit - by lining up bottom-1 blockno's -
* and just setting _RecoverTf.memo_at, etc.
PRIVATE RetValue, LastTfBC, NoFitCount, LastNoFitC, FPToffset0, FPToffsetz, FPToffset, HvValTot

RetValue = .F.
SELECT _RecoverMf
GO TOP
FPToffset0 = _RecoverMf.pos - CEILING(512/mBlockSize)*mBlockSize && normal offset if 1st memo was not choped off
GO BOTTOM
SKIP -1
SELECT _RecoverHv
SUM _RecoverHv.VALUE TO HvValTot
GO TOP
SELECT _RecoverTf
GO BOTTOM IN _RecoverTf
IF RECCOUNT("_RecoverTf")> 0
  SKIP -1 && there may be no memo's pointed to - 12-03-01
ENDIF
FPToffsetz = _RecoverMf.pos - _RecoverTf.BlockNo*mBlockSize && normal offset if last buffered memos not lost
LastTfBC = _RecoverTf.BlockCount && last nonzero block count in _RecoverTf

* Weight = .8 at 100 and .98 at 10K _RecoverTf records
IF RECCOUNT("_RecoverTf")> 0 AND;
    ((_RecoverHv.VALUE => Weight(HvValTot, .9)*HvValTot OR RECCOUNT("_RecoverHv")=1) AND _RecoverHv.VALUE > 1)
  * try most blocks check now
  SELECT _RecoverMf
  SET ORDER TO pos
  SELECT _RecoverTf
  SET ORDER TO BlockNo
  SET FILTER TO
  NoFitCount = 0

  * (A) - try first block offset
  FPToffset = FPToffset0
  SET RELATION TO BlockNo*mBlockSize + FPToffset INTO _RecoverMf
  COUNT FOR EOF("_RecoverMf") OR MemProp[_RecoverTf.MemNo, 2] != _RecoverMf.TYPE TO NoFitCount

  * (B) - if not, try last block offset
  IF (1 - NoFitCount/RECCOUNT('_RecoverTf')) < Weight(RECCOUNT('_RecoverTf'), .8)
    * insufficient fit - try FPToffsetz
    FPToffset = FPToffsetz
    COUNT FOR EOF("_RecoverMf") OR MemProp[_RecoverTf.MemNo, 2] != _RecoverMf.TYPE TO LastNoFitC
    IF LastNoFitC < NoFitCount
      FPToffset = FPToffsetz
      NoFitCount = LastNoFitC
    ELSE
      FPToffset = FPToffset0
    ENDIF
  ENDIF

  * (C) - look for offset near last block
  IF RECCOUNT('_RecoverTf') > 23 AND (1 - NoFitCount/RECCOUNT('_RecoverTf')) < Weight(RECCOUNT('_RecoverTf'), .8)
    * insufficient fit - try variable FPToffset's at tail end
    PRIVATE BestOffset, OffsetRange, i
    BestOffset = FPToffset
    LastNoFitC = NoFitCount
    OffsetRange = ABS(INT((1-Weight(RECCOUNT('_RecoverTf'), 0.8))*RECCOUNT('_RecoverTf')))
    FOR i = -OffsetRange TO OffsetRange
      GO BOTTOM && _RecoverTf
      SKIP -1 + IIF(i>0, -i, 0)
      SET RELATION TO
      SELECT _RecoverMf
      GO BOTTOM
      SKIP -1 + IIF(i>0, 0, i)
      FPToffset = _RecoverMf.pos - _RecoverTf.BlockNo*mBlockSize
      SELECT _RecoverTf
      SET RELATION TO BlockNo*mBlockSize + FPToffset INTO _RecoverMf
      COUNT FOR EOF("_RecoverMf") OR MemProp[_RecoverTf.MemNo, 2] != _RecoverMf.TYPE TO LastNoFitC
      IF LastNoFitC < NoFitCount
        NoFitCount = LastNoFitC
        BestOffset = FPToffset
      ENDIF
    ENDFOR
    FPToffset = BestOffset
  ENDIF

  IF (1 - NoFitCount/RECCOUNT('_RecoverTf')) => Weight(RECCOUNT('_RecoverTf')) && most fit ok
    *** success ***
    * Note: _RecoverTf => _RecoverMf relation still exists

    *mark memo locations in _RecoverTf
    SCAN FOR _RecoverTf.memo_at = -10 AND !EOF("_RecoverMf")
      REPLACE _RecoverTf.memo_at WITH _RecoverMf.pos, _RecoverTf.GROUP WITH 1
      REPLACE _RecoverMf.fitted WITH .T.
    ENDSCAN

    * fix last block
    GO BOTTOM && IN _RecoverTf
    IF !EOF("_RecoverMf")
      REPLACE _RecoverTf.span WITH _RecoverMf.span,;
        _RecoverTf.BlockCount WITH LastTfBC+_RecoverMf.span
    ENDIF

    SET RELATION TO
    RetValue = .T.
    SELECT _RecoverHv
    REPLACE _RecoverHv.NdMemoCnt WITH 1,;
      _RecoverHv.MultiFit WITH 1,;
      _RecoverHv.FitProb WITH 1-NoFitCount/RECCOUNT('_RecoverTf'),;
      _RecoverHv.FitAttempt WITH 1
  ELSE && not most found - unmark the ones marked as found
    SET RELATION TO
    REPLACE _RecoverTf.memo_at WITH -10 ALL
    REPLACE _RecoverTf.GROUP WITH 0 ALL
    SELECT _RecoverMf
    REPLACE _RecoverMf.fitted WITH .F. ALL
    SELECT _RecoverTf
    SET FILTER TO memo_at < 0
    RetValue = .F.
  ENDIF
ENDIF

SELECT _RecoverTf
SET ORDER TO BlockNo
SELECT _RecoverMf
SET ORDER TO pos
SELECT _RecoverHv

RETURN RetValue

**********
PROCEDURE Weight && used in SPM memo recovery
PARAMETERS RecCnt, MinRat
PRIVATE MinVal
MinVal = IIF(PARAMETERS()>1, MinRat, 0)

RETURN MAX(MinVal, 1-EXP(-0.662135*RecCnt^(0.192863586)))

*y = 1 - exp(-a*x^n)
*If you don't want the (100,.8), (10K, .98) use formula:
*n = ln(ln(1-y2)/ln(1-y1))/2/ln10
*a = -ln(y2)/x1^n

******************
PROCEDURE CreateRecM
* creates FPx type table - so that it can be used with both FPx and VFP
* ===> (Text_Memo M, Gen_Memo G, Pict_Memo P, TableName C(64), Date_Time C(20))
* 3/11/05 - not modified for Blobs (W), will store Blobs into text memos.
PARAMETERS RecordLen, FieldCount
PRIVATE FileHandle
ON ERROR *
USE IN RecoverM
ON ERROR

** Write .DBF **
FileHandle=FCREATE("RecoverM.DBF")

* type of file - FPx with memo
=FWRITE(FileHandle, CHR(245))

* date (today!) : 1-3
=FWRITE(FileHandle,CHR(YEAR(DATE())-INT(YEAR(DATE())/100)*100);
  +CHR(MONTH(DATE()))+CHR(DAY(DATE())))

* 0 Records in file : 4-7
=FWRITE(FileHandle, REPLICATE(CHR(0),4))

* Position of first data record : 8-9
=FWRITE(FileHandle, CHR(32 + FieldCount*32 + 1)+CHR(0))

* Length of data record : 10-11
=FWRITE(FileHandle, CHR(RecordLen)+CHR(0))

=FWRITE(FileHandle, REPLICATE(CHR(0), 20)) && Fill with blanks

* field SubRecords
=WriteSubRec(FileHandle, "TEXT_MEMO", "M",  1, 10)
=WriteSubRec(FileHandle, "GEN_MEMO",  "G", 11, 10)
=WriteSubRec(FileHandle, "PICT_MEMO", "P", 21, 10)
=WriteSubRec(FileHandle, "TABLENAME", "C", 31, 64)
=WriteSubRec(FileHandle, "DATE_TIME", "C", 95, 20)

=FWRITE(FileHandle, CHR(13), 1) && header record terminator
=FCLOSE(FileHandle)

** Write .FPT **
FileHandle=FCREATE("RecoverM.FPT")
* 0-3: NextFreeBlock, 6-7: BlockSize, blanks - 64byte blocksize, block 8 NextFree
=FWRITE(FileHandle, REPLICATE(CHR(0), 3)+CHR(8);
  + REPLICATE(CHR(0), 3)+CHR(64);
  + REPLICATE(CHR(0), 504))
=FCLOSE(FileHandle)

**
PROCEDURE WriteSubRec
PARAMETER Fhandle, Fname, Ftype, Fdisp, Fwidth
* FieldName/Type/DisplacementInRecord/Width/0... to 32
=FWRITE(FileHandle, PADR(Fname,11,CHR(0))+Ftype+CHR(Fdisp)+REPLICATE(CHR(0), 3)+CHR(Fwidth)+REPLICATE(CHR(0),15))

**********
PROCEDURE RepairMemoPs
IF !RepMptrsM
  RETURN ''
ENDIF
=CheckMemos()
=WriteMemoH(TmemoHandle, mBlockSize) && fix Memo header - TMemoHandle could be MemoHandle

* COUNT FOR memo_at > -1 TO TempNo
RETURN ', '

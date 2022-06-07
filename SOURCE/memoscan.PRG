* Procedure MemoScan
* Creates full/part _RecoverTf cursor for storing memo info - and detects errors:
* illegal/invalid pointers, crosslinks, memo size overlaps (very rare occurrences)
PARAMETERS ReturnOnError && used for error memoscanning only
EXTERNAL ARRAY MemProp, FldProp
PRIVATE i, j, N, TempNo1, TempSR, TempS2, Mcode, RecNum
Mcode = '' && memo trace code part in record
RepMsg1 = GM(52, "Memo scan level") + " 1 - "
RepMsg2 = ""
PRIVATE N0, N, M0
IF !USED("_RecoverTf")
  SELECT 0
  CREATE CURSOR _RecoverTf (;
    Ix N(10), RECN N(10), MemNo N(3), MemoCode C(9), BlockNo N(10),;
    Span N(10), msize N(10), BlockCount N(10), Memo_At N(10), GROUP N(4))
  INDEX ON BlockNo TAG BlockNo
ELSE
  SELECT _RecoverTf
ENDIF
SET ORDER TO
GO BOTTOM
N = INT((FileLen-FirstRecPos)/RecordLen) && number of records
N0 = IIF(RECCOUNT()=0, 1, RECN+IIF(MemNo < MemoCount, 0, 1)) && starting/resume record number
M0 = IIF(RECCOUNT()=0, 1, 1+IIF(MemNo < MemoCount, MemNo, 0)) && starting/resume memo number

SET ORDER TO BlockNo

FOR i = N0 TO N

  TempSR = GetRec(DBFhandle,i)
  =UserReport(i)
  FOR j = M0 TO MemoCount && check each memo field in record
    mMemo_at = -10
    mMsize = 0
    mGroup = 0

    *get memo BlockNo in memo file - from memo pointer
    TempS2 = SUBSTR(TempSR, MemProp[j,1]+1, IIF(VFP, 4, 10)) && memo pointer string
    * get memo pointer value
    IF VFP
      TempNo1 = Byte2Int(TempS2, 1)
    ELSE
      *      TempNo1 = IIF(!PosInt(TempS2) AND VAL(TempS2)*mBlockSize<512
      TempNo1 = IIF(!PosInt(TempS2) OR BETWEEN(VAL(TempS2)*mBlockSize, 1,511),;
        2*MemoLen/mBlockSize,;
        VAL(TempS2))
    ENDIF

    IF TempNo1> 0 && non-zero or garbage pointer
      Mcode = '' && changed in MemCheck
      IF ReturnOnError AND !MemCheck(i, j, TempNo1) && for error memoscanning only
        RETURN ErrMsgs(i, j)
      ENDIF

      * continuation of _RecoverTf build requires checking for real memo
      =IIF(!ReturnOnError AND MemCheck(i, j, TempNo1), .T., .F.)

      INSERT INTO _RecoverTf VALUES(;
        0, i, j, Mcode, TempNo1,;
        0, mMsize,;
        0, mMemo_at, mGroup )

    ENDIF
  ENDFOR
  M0 = 1

ENDFOR

IF !ReturnOnError && no further checks needed - just database creation finished
  RETURN .T.
ENDIF

IF MScanLevel>1 && level 2 memo check - If no above pointer errors check for memo overlaps / crosslinks
  SELECT _RecoverTf
  RepMsg1 = GM(52, "Memo scan level") + " 2 - "
  TempNo2 = BlockNo*mBlockSize
  TempNo1= TempNo2 + msize + 7
  GO TOP
  RecNum = RECNO()
  SCAN
    =UserReport(RECN)
    IF (_RecoverTf.Memo_At + _RecoverTf.msize > MemoLen);
        OR ((TempNo1 => BlockNo*mBlockSize;
        OR TempNo2 = BlockNo*mBlockSize) AND RECNO()!=RecNum)
      * if size beyond memo, memo overlap (beyond boundary), or crosslinked
      RETURN ErrMsgs(RECN, MemNo)
    ENDIF
    TempNo2 = BlockNo*mBlockSize
    TempNo1= TempNo2 + msize + 7
    RecNum = RECNO()
  ENDSCAN
ENDIF

IF ReturnOnError && close for memo error check and no errors
  USE IN _RecoverTf
ENDIF
=WaitWin()

PROCEDURE ErrMsgs
PARAMETER RecNm, MemNm
ErrMsg = GM(90, "Record")+" " + ALLT(STR(RecNm))+ ", '" + ALLT(MemProp[MemNm, 3]) + "' " + GM(53, "memo pointer error!") +CRLF
IF ReturnOnError AND !mTraceM AND !SPMm AND !RepMptrsM && close if no msalvage
  USE IN _RecoverTf
ENDIF

=WaitWin()
RETURN .F.

PROCEDURE MemCheck
* checks for illegal & invalid memo pointers
PARAMETER i, j, MBlockNo && record, MemoNumberInRec, MemoBlockNo
PRIVATE TempSM
*IF "EMP." $ DBFfile AND i > 9
*  WAIT WINDOW  'MemCheck' + STR(memohandle)
*ENDIF

IF MBlockNo*mBlockSize < MemoLen -8 AND MBlockNo*mBlockSize => 512 && possible valid pointer
  TempSM = GetString(memohandle, MBlockNo*mBlockSize, 8+19)
  IF MtraceFlag AND MemProp[j, 2] = 1 AND FldProp[MemProp[j,4], 2] = 'M' && only text and binary memos carry trace code
    * Trace code and text memo
    TempS2 = SUBSTR(TempSM, 9, 19) && suposed total memocode in memo
    Mcode = SUBSTR(TempSR, 9, 9) && Memotrace code part in record
    IF TempS2 != MemProp[j,3] + Mcode
      RETURN .F.
    ENDIF
  ELSE && other memo types, G, P, W
    * check for illegal memo pointer
    TempS2 = SUBSTR(TempSM, 1, 4) && memotype signature
    TempNo2 = Byte2Int(SUBSTR(TempSM, 5, 4), -1) && memo size
    IF MemProp[j,2] != Byte2Int(TempS2, -1) && memo signature not there
      *    IF MemProp[j,2] != Byte2Int(TempS2, -1);
      *              OR (TempNo2 == 0) OR (TempNo2 => MemoLen - MBlockNo*mBlockSize+ 1)
      RETURN .F.
    ENDIF
  ENDIF
ELSE && beyond file pointer
  RETURN .F.
ENDIF

mMemo_at = MBlockNo*mBlockSize
mMsize = GetValue(memohandle, mMemo_at+4, 4, -1)
mGroup = 1

PROCEDURE PosInt
PARAMETER Fstring
* checks if right justified +ve integer
IF CHR(0) $ Fstring
  * add-on: 10/18/2005 UBS software - some UBS Fox2X tables have (last field) memo pointers with
  * binary zeroes that trips up Recover/Rebuild with " FILE NOT OPEN" error
  * Normal Fox2X memo pointers should be string numbers or just 10 spaces for 0 pointer
*  wait window DBFfile + '<<'
  RETURN .F.
ENDIF
IF RIGHT(Fstring,1)==' ' AND !EMPTY(Fstring) && must be right justified or empty
  RETURN .F.
ENDIF
PRIVATE Nstring, i, X
Nstring = ALLT(Fstring)
FOR i = 1 TO LEN(Nstring)
  X = SUBSTR(Nstring,i,1)
  IF (X<'0' OR X>'9') && must be digit
    RETURN .F.
  ENDIF
ENDFOR
RETURN .T.

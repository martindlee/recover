***************************
* PROCEDURE RecVal
* Evaluates probability of a string being a record. Any illegal FieldVal gives 0 prob.

PARAMETERS Rstring, MsgFlag, ScanLevel, CheckMemo
* record string and IF to return on warnings and check memos
PRIVATE RetVal, TempNo, i, FldMsg, FLDCOUNT
* Note: CheckMemo .F. for skipping memo check
***
* Return Values
* IF MsgFlag == .F.
* Numeric: > 0 for OK values OR 0 for corrupt values
* ELSE && return on every non empty message
* String: '' OR error messages "Error:..." OR warnings "Warning:..." IF ChkWarn
* add " " at begining of string
* ENDIF
****
EXTERNAL ARRAY FldProp
*check delete flag
IF !LEFT(Rstring,1) $ DelChar
  RETURN IIF(MsgFlag, GM(21, "Error: Invalid delete flag"), 0)
ENDIF
* check trace code
IF RTraceFlag AND SUBSTR(Rstring, 2, 7)!='ReCoVeR'
  RETURN IIF(MsgFlag, GM(22, "Error: invalid trace code"), 0)
ENDIF
IF ScanLevel<2
  RETURN IIF(MsgFlag, "", 0)
ENDIF
FLDCOUNT = RECCOUNT("RecoverDef")-1
RetVal = IIF(MsgFlag, '', 100)
*check rest of fields
FOR i = 1 TO FLDCOUNT
  FldMsg = ''
  IF CheckMemo OR !FldProp[i, 2] $ 'MGPW' && check the memo or other fields
    TempNo = FieldVal(SUBSTR(Rstring, FldProp[i, 5], FldProp[i, 3]),  FldProp[i, 2],  FldProp[i, 4])
  ELSE
    TempNo = 1  && Its a memo and its not checked - assign 1 - assume OK
  ENDIF
  IF TempNo == 0 && bad field or memo
    IF MsgFlag
      IF !FldProp[i, 2] $ 'MGPW' && other than memo
        LFSm = .F.
        RETURN "'" + ALLT(FldProp[i,1]) + "' "+GM(23, "field error")  +"."
      ELSE && memo error
        RETURN "'" + ALLT(FldProp[i,1]) + "' "+GM(23, "field error") + " - " + GM(24, "invalid memo pointer!")
      ENDIF
    ELSE
      RETURN 0
    ENDIF
  ELSE && possible warning or numeric value
    IF MsgFlag && return if MsgFlag and if warning message
      IF LEN(FldMsg)>0
        LFSm = .F.
        RETURN FldMsg
      ENDIF
    ELSE
      RetVal = RetVal * TempNo
    ENDIF
  ENDIF
ENDFOR
RETURN RetVal

**
PROCEDURE FieldVal
PARAMETERS Fstring, Ftype, Decm
* checks each field for restrictions
DO CASE
CASE Ftype == 'T' && DateTime
  PRIVATE B0
  IF Fstring==REPLICATE(CHR(0),8) && empty date/time field from append blank
    RETURN 1.0
  ENDIF
  B0 = Byte2Int(LEFT(Fstring,3), 1)
  IF B0 <1757585 OR B0 >5373484 OR SUBSTR(Fstring, 4, 1)!=CHR(0) OR Byte2Int(RIGHT(Fstring, 4), 1) > 86400000
    RETURN 0
  ELSE
    RETURN 1.5
  ENDIF

CASE Ftype $ 'IBYQV'
  * VFP Integer/Double/Currency - no restrictions ??
  * Varbinary ('Q' hex-endcoded field view), Varchar & VarCharBinary
  RETURN 1

CASE Ftype == '0' && _NullFlags
  IF ASC(Fstring) < NullFlagCeil && 2^(count of null field types in .def)
    RETURN 1
  ELSE
    RETURN 0
  ENDIF

CASE Ftype $ 'MGPW' && memo types && OK
  * accept 0 pointers
  IF (VFP AND Fstring == CHR(0)+CHR(0)+CHR(0)+CHR(0)) OR (!VFP AND EMPTY(Fstring))
    RETURN 1
  ENDIF
  IF !VFP AND !RJDigits(Fstring) && DigitsOnly/RightJustified for non VFP
    RETURN 0
  ENDIF
  * check valid memo type signature in memo file
  PRIVATE Mtype, TempS, TempNo
  TempS = CHR(0)+CHR(0)+CHR(0)
  DO CASE
  CASE Ftype $ 'MW' && memo or blob
    Mtype = TempS+CHR(1)
  CASE Ftype == 'G'
    Mtype = TempS+CHR(2)
  CASE Ftype == 'P'
    Mtype = TempS+CHR(0)
  ENDCASE
  * now check for valid memo signature
  TempNo = IIF(VFP, Byte2Int(Fstring, 1), VAL(Fstring))
  =FSEEK(MemoHandle, TempNo*MBlockSize)
  IF Mtype != FREAD(MemoHandle, 4)
    RETURN 0.5 && wrong type - but it could be just a bad pointer
  ENDIF
  RETURN 1.5 && high probability

  * Types C, Cb, D, L, F, N below can be blank
CASE EMPTY(FSTRING)
  RETURN 1

CASE Ftype $ 'CbCt' && character types
  PRIVATE RIGHTC, LEFTC, TC, SpH
  TC = TextChar(Fstring)
  LEFTC = LEFT(Fstring, 1)
  RIGHTC = RIGHT(Fstring, 1)
  SpH = SpaceHole(Fstring)
  DO CASE
  CASE Ftype == 'Ct' AND !TC
    * 'Ct' and its not all text - but should be text only
    RETURN 0 && content problems

  CASE LEFTC != ' ' AND RIGHTC == ' ' && Left Justified
    DO CASE
    CASE Ftype == 'Cb'
      RETURN 1.1 && high value for LJ
    CASE Ftype=='C' AND !TC
      RETURN 0.9 && likely holes don't matter
    CASE TC
      RETURN IIF(SpH, 0.8*Fwarn(), 1.1)
    ENDCASE

  CASE LEFTC != ' ' AND RIGHTC != ' ' && full field - eg. 'CA1023LL90F' or 'CA10  LL90F'
    IF TC OR Ftype=='Cb' && 'Ct' included
      RETURN IIF(SpH, 0.5*Fwarn(), 0.8)
    ELSE &&    IF !TC AND 'C' && 'Ct' already excluded
      RETURN IIF(SpH, 0.4*Fwarn(), 0.7)
    ENDIF

  CASE LEFTC==' ' && Middle position OR Right Justified
    =IIF(RIGHTC!=' ' AND !Ftype=='C', Fwarn(), '')
    IF TC OR Ftype=='Cb' && 'Ct' included
      RETURN IIF(SpH, 0.3*Fwarn(), 0.5)
    ELSE &&    IF !TC AND 'C' && 'Ct' already excluded
      RETURN IIF(SpH, 0.2*Fwarn(), 0.4)
    ENDIF
  ENDCASE
  WAIT WINDOW 'Recover SFP method character CASE error!'

CASE Ftype == 'D' && Date - use for good verification?
  IF !RJDigits(Fstring) && must be all digits '0-9'
    RETURN 0
  ENDIF
  * Check if date is valid
  PRIVATE Yr, Mn, Dy
  Yr = LEFT(Fstring, 4)
  Mn = SUBSTR(Fstring, 5, 2)
  Dy = RIGHT(Fstring, 2)
  DO CASE
  CASE AT(SET('date'), "AMERICAN USA MDY")>0
    IF EMPTY(CTOD(Mn+'.'+Dy+'.'+Yr))
      RETURN 0
    ENDIF

  CASE AT(SET('date'), "BRITISH/FRENCH GERMAN ITALIAN DMY")>0
    IF EMPTY(CTOD(Dy+'.'+Mn+'.'+Yr))
      RETURN 0
    ENDIF

  CASE AT(SET('date'), "JAPAN ANSI YMD")>0
    IF EMPTY(CTOD(Yr+'.'+Mn+'.'+Dy))
      RETURN 0
    ENDIF

  ENDCASE
  RETURN 1.5 && date OK

CASE Ftype == 'L'
  IF Fstring != 'F' AND Fstring != 'T'
    RETURN 0
  ELSE
    RETURN 1
  ENDIF
CASE Ftype == 'N' OR Ftype == 'F'  && must be RightJust. if not empty.
  RETURN IIF(!RJNumeric(Fstring), 0, 1)

ENDCASE
WAIT WINDOW "FieldVal Procedure Ftype error"
return 0

PROCEDURE Fwarn
IF MsgFlag AND ScanLevel>2
  FldMsg = " " + GM(26, "warning: field '") + ALLT(FldProp[i,1]) + "'"
  RETURN 1
ENDIF
RETURN 1


***************** Related Procedures

PROCEDURE TextChar
* checks if all text and if any 3xSpaceHoles between text.
PARAMETER Fstring
IF EMPTY(Fstring)
  RETURN .T.
ENDIF
PRIVATE i, x
FOR i = 1 TO LEN(Fstring)
  x = SUBSTR(Fstring, i, 1)
  IF (x<CHR(32) OR x>CHR(126)) && AND x!=CHR(10) AND x!=CHR(13) AND
    RETURN .F.
  ENDIF
ENDFOR
RETURN .T.

PROCEDURE SpaceHole
* checks if 3xSpaceHoles exist in text
PARAMETER Fstring
IF AT('   ', ALLT(Fstring))>0
  RETURN .T.
ELSE
  RETURN .F.
ENDIF

PROCEDURE RJNumeric
PARAMETER Fstring
* checks if Numeric or Float field valid.
*IF EMPTY(Fstring) && already excluded in FieldVal
*  RETURN .T.
*ENDIF
IF RIGHT(Fstring,1)==' ' && must be right justified.
  RETURN .F.
ENDIF
PRIVATE Nstring, i, X
Nstring = ALLT(Fstring)
FOR i = 1 TO LEN(Nstring)
  x = SUBSTR(Nstring,i,1)
  IF x!='.' AND x!='-' AND (x<'0' OR x>'9') && must be digit, period or -ve sign (1st)
    RETURN .F.
  ENDIF
ENDFOR
RETURN .T.

PROCEDURE RJDigits
PARAMETER Fstring
* Checks that Fstring if RJ digits only
IF RIGHT(Fstring,1)==' ' && must be right justified.
  RETURN .F.
ENDIF
PRIVATE Nstring, i, X
Nstring = ALLT(Fstring)
FOR i = 1 TO LEN(Nstring)
  x = SUBSTR(Nstring,i,1)
  IF (x<'0' OR x>'9') && must be digit
    RETURN .F.
  ENDIF
ENDFOR
RETURN .T.

PROCEDURE MemoPCheck
* Checks if memo pointer is valid
PARAMETER Mtype, Fstring
PRIVATE TempNo, Mpos
TempNo = IIF(VFP, Byte2Int(Fstring, 1), ALLT(VAL(Fstring)))
MPos=FSEEK(MemoHandle, TempNo*MBlockSize)
IF Mtype != FREAD(MemoHandle, 4)
  RETURN .F. && wrong type
ENDIF
RETURN .T.

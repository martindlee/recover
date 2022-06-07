*** MemoPut.prg - corrected 10-06-96 for lower case FieldName entries
* corrected 05-28-97 for extraneous trace code - not vital.
* Returns 19 byte string: TraceString + MemoText to be used in writing
* into memos - for Recover tracing technique.
* Replaces previous TraceString with new one.
PARAMETER FieldName, MemoText
IF EMPTY(MemoTrace)
  WAIT WINDOW "Recover MemoTrace error. Press any key to continue..."
ENDIF
MemoText = IIF(LEFT(MemoText,10)==PADR(ALLT(UPPER(FieldName)),10),;
  SUBSTR(MemoText,20), MemoText)
RETURN PADR(UPPER(FieldName),10) + MemoTrace + MemoText

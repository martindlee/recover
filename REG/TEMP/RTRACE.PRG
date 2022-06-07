* Returns 15 byte string to be placed into first field for file recovery tracing
PARAMETER Memos && .T. or any character or numeric value IF memotracing is required
IF PARAMETERS()>0
  MemoTrace =  RIGHT(SYS(2015),9) && memotrace is a public variable IF USED
  RETURN "ReCoVeR"+MemoTrace
ENDIF
RETURN "ReCoVeR"


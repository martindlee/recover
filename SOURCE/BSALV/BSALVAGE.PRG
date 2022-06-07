*Bsalvage for Visual FoxPro
External Array FldProp
Private X, i, j
Dimension X[10+(Reccount('RecoverDef')-1)*5]
X[1] = DBFhandle
X[2] = RecordLen
X[3] = FirstRecPos
X[4] = FileLen
X[5] = RScanLevel
X[6] = EofMark
X[7] = RTraceFlag
X[8] = DelChar
For i = 10+1 to 10+Reccount('RecoverDef')-1
  For j = 1 to 5
    X[5*(i-10+1)+j] = FldProp[i-10, j]
  ENDFOR
ENDFOR

DO FormSet Bsalv with X

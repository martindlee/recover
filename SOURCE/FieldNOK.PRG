*PROCEDURE FieldNameOK
* checks if file fieldname duplication and string valid format
*
PARAMETER FieldString, CheckDups, NonVFPT
Private NonVFPtype
NonVFPType = Parameters() > 2 AND NonVFPT

IF CheckDups && Check for fieldname duplication
  IF !USED("_RecoverFN")
    PRIVATE OldAlias
    OldAlias = ALIAS()
    CREATE CURSOR _RecoverFN (FieldName C(10))
    INDEX ON FieldName TAG FieldName
    IF !EMPTY(OldAlias)
      SELECT (OldAlias)
    ENDIF
  ENDIF
  IF SEEK(FieldString, "_RecoverFN")
    DuplicateFN = .T.
* wait window '1 ' + Fieldstring
    RETURN .F.
  ENDIF
  INSERT INTO _RecoverFN VALUES (FieldString)
ENDIF

* check string valid format
IF ALLT(FieldString)=="_NullFlags" OR ALLT(FieldString)=="_DBASELOCK" && VFP sys field & old dbase record lock field
  RETURN
ENDIF
PRIVATE C, CS, CL, i
C = LEFT(FieldString, 1)
* First character must be Upper case letter or certain "other international characters"?
IF !Between(C, 'A', 'Z');
    AND !C $ "_ƒŠŒšœŸÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏĞÑÒÓÔÕÖØÙÚÛÜİŞßàáâãäåæçèéêëìíîïğñòóôõöøùúûüışÿ"
  RETURN .F.
ENDIF
CS = ALLT(FieldString)
CL = LEN(CS)
* rest characters must be Upper case letter or numeric or underline
FOR i = 1 TO CL
  C=SUBSTR(CS, i, 1)
  IF !Between(C, 'A', 'Z') AND !Between(C, '0', '9') AND C!='_';
      AND !(Between(C, 'a', 'z') AND NonVFPType);
      AND !C $ "ƒŠŒšœŸÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏĞÑÒÓÔÕÖØÙÚÛÜİŞßàáâãäåæçèéêëìíîïğñòóôõöøùúûüışÿ"
    RETURN .F.
  ENDIF
ENDFOR

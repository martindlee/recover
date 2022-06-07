* PROCEDURE cr_recovert
* creates temporary RecoverT table for browse viewing from DBFarray
* Returns DBF file size.
PRIVATE ALL
** generates temporary table RecoverT from def file.
SET TALK OFF
FileHandle = FCREATE('RecoverT.dbf')
Select RecoverDef
* check if memos
LOCATE FOR LEFT(RecoverDef.type,1) $ 'MPG'
MemoFlag = FOUND()
* wait window iiF(memoflag, 'memflag', 'no-memoflag')+'<<<'

SUM VAL(RecoverDef.Width) FOR RECNO()<RECCOUNT() TO RecordLen
RecordLen = RecordLen + 1

GO BOTTOM
VFP=.F.
FileType = 0
TempS = LEFT(Field_Name, 2)
DO CASE
CASE TempS == 'VF'
  FileType = 48
  VFP = .T.
CASE (TempS ='FP' OR TempS ='AL') AND MemoFlag
  FileType = 245
CASE TempS ='FP' OR TempS ='AL'
  FileType = 3
CASE TempS = 'DB' && DB3 with memo
  FileType = 131
ENDCASE
IF !EMPTY(RecoverDef.Dec)
  * this helps with DB3/memo files - only use this in future versions
  FirstRecPos = VAL(RecoverDef.Dec)
ELSE && version 1.0 assumption
  FirstRecPos = (RECCOUNT('RecoverDef'))*32 + 1 + IIF(VFP, 263, 0) && 1 for header terminator (x0D)
ENDIF

=FWRITE(FileHandle, REPLICATE(CHR(0), FirstRecPos-1))

* TableFlags = VAL(SUBSTR(RecoverDef.Field_Name, 5, 3))

TableFlags = IIF(BIT(1,VAL(SUBSTR(RecoverDef.Field_Name, 5, 3))), 2, 0) && use the memo flag only

nCodePage  = VAL(SUBSTR(RecoverDef.Field_Name, 8, 3))

* Write Header - 1st part
=FSEEK(FileHandle, 0)
=FWRITE(FileHandle, CHR(FileType)) && Write file type
=PutString(FileHandle, 1, CHR(97)+CHR(8)+CHR(14)) && write some sort of date - note no century possible.
=PutValue(FileHandle, 8, FirstRecPos, 2, 1) && first record pos
=PutValue(FileHandle, 10, RecordLen, 2,1) && write recordlen
=PutValue(FileHandle, 28, TableFlags, 1, 1) && TableFlags
=PutValue(FileHandle, 29, nCodePage,   1, 1) && nCodePage

* Write field definitions
RDispl = 1
SCAN FOR RECNO()<RECCOUNT()
  =PutString(FileHandle, RECNO()*32, ALLT(RecoverDef.Field_Name)) && Field Name
  =PutString(FileHandle, RECNO()*32 + 11, LEFT(TYPE, 1)) && Field Type
  =PutValue (FileHandle, RECNO()*32 + 12, Rdispl, 4, 1) && Displacement in record
  =PutString(FileHandle, RECNO()*32 + 16, CHR(VAL(RecoverDef.Width))) && Field Length
  =PutString(FileHandle, RECNO()*32 + 17, CHR(VAL(RecoverDef.Dec))) && Decimals
  FieldFlag = VAL(SUBSTR(RecoverDef.Type, 2, 3))
  =PutString(FileHandle, RECNO()*32 + 18, CHR(FieldFlag)) && FieldFlags
  RDispl = RDispl + VAL(RecoverDef.Width)
ENDSCAN
=PutString(FileHandle, RECCOUNT()*32, CHR(13)) && header terminator
=FCLOSE(FileHandle)

* check if memo needed
IF MemoFlag
  * create an empty memo file
  FileHandle = FCREATE('RecoverT.'+IIF(FileType==131, 'dbt','fpt')) && .dbt FOR older FILES
  TempS = CHR(0)+CHR(0)+CHR(0)
  =FWRITE(FileHandle,TempS+IIF(FileType==131, CHR(1),CHR(8));
  +TempS + CHR(64);
  +REPLICATE(CHR(0), 512-8))
  =FCLOSE(FileHandle)
ENDIF
RETURN FirstRecPos

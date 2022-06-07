* Abri Technologies - handy Recover option string generator.
* this is an easy method of getting the option codes you want into
* the _cliptext string. Just run this program and the desired option
* code string will be in windows notepad.
Dimension RecOpt[23]
*    Record file (DBF) error detection methods:
RecOpt[1]  = 'T' && (T) Check record file header
RecOpt[2]  = 'F' && (T) Scan records - with delete flag - and trace code (IF coded)
RecOpt[3]  = 'F' && (F)  AND check fields for corruption (slower)
RecOpt[4]  = 'F' && (F)    AND check suspicious fields (slower)
*                       ('warnings' - eg. right justified char field '    Peter Joh',
*                       binary data in char fields, etc.)
*  Record file (DBF)   repair methods:
RecOpt[5]  = 'T' && (T) repair header
RecOpt[6]  = 'F' && (T) Trace method (if coded)
RecOpt[7]  = 'T' && (T) LFS method
RecOpt[8]  = 'F' && (T) vFPS (Visual File pieces salvage)

*   Memo error         detection:
RecOpt[9]  = 'T' && (T) Check memo file header
RecOpt[10] = 'T' && (T) Scan memos - level 1 - invalid pointers (slower)
RecOpt[11] = 'T' && (T)   AND - level 2 - memo crosslinks / overlaps (slower)

*   Memo file  (FPT)   repair methods:
RecOpt[12] = 'T' && (T) repair header
RecOpt[13] = 'F' && (T) Trace method (if coded)
RecOpt[14] = 'F' && (F) SPM method
RecOpt[15] = 'T' && (T) Repair memo pointers
RecOpt[16] = 'T' && (T) Empty memo

*    Other             options
RecOpt[17] = 'F' && (F) Save extraneous memos into RecoverM.dbf/fpt
RecOpt[18] = 'T' && (T) Show Progress messages
RecOpt[19] = 'F' && (T) Show end MsgBox Dialog
RecOpt[20] = 'T' && (T) Save old DBF/FPT (major changes changes only - when file rewritten).
RecOpt[21] = 'T' && (T) Warning/Error on .DEF file / Header field discrepancy.
RecOpt[22] = 'F' && (F) Adjust invalid autoincrement NextVal and StepVal
RecOpt[23] = 'F' && (T) Write Recover report to RECOVREP.TXT log file

*
RetVal = ''
For I = 1 to 23
  RetVal = RetVal + RecOpt[i]
EndFor
_ClipText = RetVal
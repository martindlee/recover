SET CPDIALOG OFF
*SET PATH TO
SET EXCLUSIVE OFF
PRIVATE ALL
PUBLIC Calendar
_SCREEN.WINDOWSTATE = 2 && full screen
_SCREEN.CAPTION = "UBS Appointment Book"
_SCREEN.FONTNAME = "Arial"
_SCREEN.FONTSIZE = 9
_SCREEN.MAXBUTTON = .F.
_SCREEN.CLOSABLE = .T.

FPTfile = GETFILE('FPT','FPT file?','OPEN')

IF EMPTY(FPTfile) OR !FILE(FPTfile) OR UPPER(RIGHT(FPTfile, 4)) != '.FPT'
  MessageBox("Incorrect file selected!")
  RETURN
ENDIF

DIMENSION FileArr[1,5]
=ADIR(FileArr, FPTfile) && get file details to FileArr
FileLen=FileArr[1,2]

IF FileLen > 2147483647
  IF MESSAGEBOX("This file size is beyond 2GB limit. ";
      + "It can be fixed by adjusting size to just below 2GB and correcting record counter. ";
      + "After size/counter adjustment you can try to view the file and then error-scan/repair if needed (takes long time).";
      + CRLF + CRLF + " Do you want to proceed with repair now?", 4, "2GB+ file size warning.") = 6 && yes
    FPThandle  = FOPEN(dbffile, 2) && .DBF filehandle
    =FCHSIZE(FPThandle, 2^31 - 2) && this will change to -1 byte below limit and allow EOF mark
    FileLen = 2^31 - 2 && new file size
    =FFLUSH(FPThandle) && just to make sure of proper access after mods
    =FCLOSE(FPThandle)
  ELSE && exit requested
    MESSAGEBOX("File not adjusted. Exit Requested!", 0, "Notice!")
  ENDIF
ELSE
  MESSAGEBOX("This file size is below the 2GB limit (2GB = 2147483647). No size adjustment needed.")
ENDIF

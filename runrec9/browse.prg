PARAMETER FPath
* general browsing program
IF PARAMETERS() = 0 && default file
  IF FILE('RECOVLST.DBF')
    FilePath = 'RECOVLST.DBF'
  ELSE
    FilePath = 'REBUILD.DBF'
  ENDIF
ELSE
  FilePath = FPath
ENDIF

ON ERROR *
_SCREEN.WINDOWSTATE = 2
_SCREEN.CAPTION = "Recover 4.0 - VFP9 StandAlone BROWSING"
_SCREEN.CLOSABLE = .T.
ON ERROR
ON SHUTDOWN QUIT


IF !FILE('RECOVLST.DBF') AND !FILE('REBUILD.DBF')
  MESSAGEBOX( "Please select location of RECOVLST.DBF or REBUILD.DBF!" + CHR(13), 0, "Notice!")
  FilePath=GETFILE("DBF","Recovlst.dbf???")
ENDIF

IF EMPTY(FilePath) && OR !"RECOVLST.DBF"$UPPER(FilePath)
  QUIT
ENDIF

SET SYSMENU TO _MSM_EDIT
SET CPDIALOG OFF
ON KEY LABEL CTRL+R DO PackIt
ON KEY LABEL ESCAPE QUIT

USE (FilePath) EXCL
DO WHILE .T.
  DO BrowseIt
ENDDO

*------------------
PROCEDURE BrowseIt
BROWSE TITLE "Comands: Exit=ESC, AppendRec=Ctrl+Y, DeleteTogle=Ctrl+T, Pack=Ctrl+R"
*------------------
PROCEDURE PackIt
PACK
DO BrowseIt

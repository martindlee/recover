PARAMETER FPath
* general browsing program
IF PARAMETERS() = 0
  FilePath = 'RECOVLST.DBF'
ELSE
  FilePath = FPath
ENDIF

ON ERROR *
_SCREEN.WindowState = 2
_SCREEN.caption = "Recover 2.0 - VFP5.0a StandAlone BROWSING"
MODI WINDOW SCREEN TITLE "Recover 2.0 - BROWSING utility."
_SCREEN.Closable = .T.
ON SHUTDOWN QUIT
ON ERROR

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
BROWSE TITLE "RECOVLST.DBF: Exit=ESC, AppendRec=Ctrl+Y, DeleteTogle=Ctrl+T, Pack=Ctrl+R"
*------------------
PROCEDURE PackIt
PACK
DO BrowseIt

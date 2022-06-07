* Use a routine like this for the enduser to start Rebuild more safely
* make this into a StartRebuild.exe (or whatever.exe) - make sure to EXCLUDE update.app from the project

PRIVATE ALL
OldDir = FULLPATH('.')
*FileNameOfFileList = "RebuildList.txt"

*------ pre-Rebuild safety checks
* The enduser should have latest good backup before proceeding.
IF FILE("Rebuild.dbf") AND FILE("NewRebuild.dbf");
    AND MESSAGEBOX("Do you have the latest valid data backup.", 4, "Notice") = 7 && "No"
  MESSAGEBOX("Backup directory data first", 0, "Notice")
  RETURN .F.
ENDIF

IF !FILE("Rebuild.dbf") && this should never happen to enduser.
  =MESSAGEBOX("Rebuild.dbf file missing")
  RETURN .F.
ENDIF

**--- Your other pre-Rebuild routines
* You can check here that enduser has correct current revision of your software before proceeding.

* first check condition of Rebuild - did it get an initial FileScan, is it a potential ErrorScan
USE REBUILD
lErrorScan = RECCOUNT() > 1 && the files were already scanned for structure
lFileScanNeeded = !lErrorScan && never scanned files for structure yet.
lFileUpdate = .F.
USE

IF lFileScanNeeded && initial structure file scan not yet done
  IF REBUILD(FirstDirectory, SecondDirectory, etc) < 1 && or just Rebuild("")!=0 for current directory
  * OR
  *IF REBUILD("*FILELIST*", FileNameOfFileList) < 1
    *This FileScan has errors
    =MESSAGEBOX("Cannot continue Rebuild.. errors in data files. Call support..", 0, "Notice.")
    CLOSE ALL
    RETURN .F.
  ENDIF
ENDIF

DO CASE
CASE FILE("Rebuild.dbf") AND !FILE("NewRebuild.dbf") && this is an ErrorScan
CASE FILE("UPDATE.APP") AND FILE("NewRebuild.dbf") && this should be a new filestructure update
  lFileUpdate = .T.
  * put all your pre-update code in UPDATE.APP - see sample update.prg file
  lUDsuccess = UPDATE() && this will launch your update.app file
  SET DEFAULT TO OldDir && return to OldDir for next line
  ERASE UPDATE.APP && that way it won't interfere with next update.app or absence of it
ENDCASE
nRebResult = REBUILD()

**--- Your Post-Rebuild code if any --- other tasks you may want to do.
* For example to do PostUpdate use
*IF lFileUpdate
*  lUDPostSuccess = PostUpdate() && your PostUpdate.app file
*  ERASE PostUpdate.app && allows new future PostUpdate.app
*Endif

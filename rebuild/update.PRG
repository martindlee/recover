* this is a sample update showing how to change a field name
* Normally Rebuild can make file change structure updates except renaming a field.

ALTER TABLE ExactTablePathName RENAME COLUMN Lname TO LastName
USE && its open after altering
CLOSE ALL && exclusive use required for Rebuild.

* But now you have changed a file structure -
* any previous Rebuild enduser filescan is invalid
* scan the files before (or after) Rebuild update
IF REBUILD(FirstDirectory, SecondDirectory, etc) !=0 && or just Rebuild("")!=0 for current directory
* OR
*IF REBUILD("*FILELIST*", FileNameOfFileList) < 0
  *This FileScan has errors - probably will not happen
  =MESSAGEBOX("Update.app cannot continue collecting file data structure info.. errors in data files. Call support..", 0, "Notice.")
  CLOSE ALL
  RETURN
ENDIF
* now run Rebuild file update && both Rebuild and NewRebuild tables should be present
IF REBUILD() = 0 && update success
  * you can do other PostUpdate tasks you may want here - eg. deleting obsolete files, etc.

ELSE
  MESSAGEBOX("Update failure. Call support..", 0, "Notice.")
ENDIF

* Program fixdrive
* replaces upper drive letters in *.app/*.exe files
PARAMETERS AppFile && the full name of *.app, *.exe
AppHandle = FOPEN(AppFile, 2)
IF AppHandle > 0
  FileLen = FSEEK(AppHandle, 0, 2)
  LastPos = -1
  = FSEEK(AppHandle, 0)
  DO WHILE !FEOF(AppHandle)
    LastPos=Srchfile(AppHandle, LastPos+1, FileLen, ':\')
    IF LastPos > 1 AND UPPER(GetString(AppHandle, LastPos-1, 1)) $ 'DEFGH'
      =Fseek(AppHandle, LastPos -1)
      =FWRITE(AppHandle, 'c')
    ENDIF
  ENDDO
  =FCLOSE(AppHandle)
ENDIF

*************
PROCEDURE GetString
PARAMETERS FileHandle, fileloc, nbytes
=FSEEK(FileHandle, fileloc)
RETURN FREAD(FileHandle, nbytes)

************
PROCEDURE SrchFile
PARAMETERS FileHandle, FStart, FEnd, String1
***************************************
PRIVATE ALL && Bpos, Fpos, ByteBlock1, ByteBlock2, EndOfFile
Fpos=Fstart
BPos=0
=FSEEK(FileHandle, Fstart)
IF FEOF(FileHandle)
  RETURN -1
ENDIF
EndOfFile = .F.
ByteBlock1 = FREAD(FileHandle, 2048)
EndOfFile  =  LEN(ByteBlock1)=0
ByteBlock2 = FREAD(FileHandle, 2048)
DO WHILE !EndOfFile AND FPos<=FEnd
  Bpos=AT(String1, ByteBlock1+ByteBlock2)
  IF Bpos>0
    =FSEEK(FileHandle, Fpos+Bpos-1)
    RETURN Fpos+Bpos-1
  ENDIF
  Fpos=Fpos+2048
  ByteBlock1 = ByteBlock2
  ByteBlock2 = FREAD(FileHandle, 2048)
  EndOfFile = LEN(ByteBlock2)=0
ENDDO
RETURN -1

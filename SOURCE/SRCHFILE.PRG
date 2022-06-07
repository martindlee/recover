*:*****************************************************************************
*:
*:        Program: C:\RECOVER\SOURCE\SRCHFILE.PRG
*:         System: srchfile.prg
*:         Author: Paul Lee
*:      Copyright (c) 1995, Abri Technologies, Inc.
*:  Last modified: 09/28/95 at 14:51:00
*:
*:      Documented 22:03:13                                FoxDoc version 3.00a
*:*****************************************************************************
PARAMETERS FileHandle, FStart, FEnd, String1
***************************************
* Searches a file for String. Where
* FileHandle: is from FOPEN or FCREATE,
* String1: the string searched for - up to 2048 characters long
* Fstart: the file position to start searching at
* Fend: approx file pos. where to end search.
***************************************
* Returns the file byte location of a string if found
* (and places pointer there) OR -1 if not found
* NOTE: this will search ~2048 bytes beyond Fend
PRIVATE ALL && Bpos, Fpos, ByteBlock1, ByteBlock2, EndOfFile
IF Fstart > FEnd
  RETURN -1
ENDIF
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
* EOF: SRCHFILE.PRG

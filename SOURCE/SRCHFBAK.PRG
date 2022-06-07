*:*****************************************************************************
*:
*:        Program: C:\RECOVER\SOURCE\SRCHFILE.PRG
*:         System: srchfbak.prg
*:         Author: Paul Lee
*:      Copyright (c) 1995, Abri Technologies, Inc.
*:
*:*****************************************************************************
PARAMETERS FileHandle, FStart, FEnd, String1
***************************************
* Searches a file BACKWARDS for first occurence of String1 from end of file,
* where
* FileHandle: is from FOPEN or FCREATE,
* String1: the string searched for - up to 2048 characters long
* Fstart: the file position to start searching at
* Fend: approx file pos. where to end search.
***************************************
* Returns the file byte location of a string if found
* (and places pointer there) OR -1 if not found
* NOTE: this may search ~2048 bytes before FStart
PRIVATE Bpos, Fpos, ByteBlock1, ByteBlock2, BegOfFile
BPos=0
IF FStart<0 OR Fstart-Fend < LEN(String1)
  RETURN -1
ENDIF
Fpos=FSEEK(FileHandle, IIF(Fstart=>2048*2, FStart-2048*2, 0)) && here Fend<Fstart
BegOfFile = .F.

DO CASE
CASE Fstart - Fend <= 2048
  =FSEEK(FileHandle, Fend)
  ByteBlock1=FREAD(FileHandle, Fstart-Fend)
  ByteBlock2 = ''
  Fpos = Fend
CASE Fstart - Fend < 2048*2
  =FSEEK(FileHandle, Fend)
  ByteBlock1 = FREAD(FileHandle, Fstart - Fend - 2048)
  ByteBlock2 = FREAD(FileHandle, 2048)
  Fpos = Fend
CASE Fstart - Fend => 2048*2
  Fpos=Fstart-2048*2
  =FSEEK(FileHandle, Fpos)
  ByteBlock1 = FREAD(FileHandle, 2048)
  ByteBlock2 = FREAD(FileHandle, 2048)
ENDCASE

*? fpos
DO WHILE !BegOfFile AND FPos=>Fend &&-2048 && Fend < Fstart here
  Bpos=RAT(String1, ByteBlock1+ByteBlock2)
  IF Bpos>0
    =FSEEK(FileHandle, Fpos+Bpos-1)
    RETURN Fpos+Bpos-1
  ENDIF
  ByteBlock2 = ByteBlock1
  DO CASE
  CASE Fpos<=Fend && nothing left to search
    BegOfFile=.T.
  CASE Fpos - Fend < 2048
    =FSEEK(FileHandle, Fend)
    ByteBlock1=FREAD(FileHandle, Fpos-Fend)
    Fpos = Fend
  CASE Fpos - Fend => 2048
    Fpos=Fpos-2048
    =FSEEK(FileHandle, Fpos)
    ByteBlock1 = FREAD(FileHandle, 2048)
  ENDCASE
ENDDO
RETURN -1
* EOF: SRCHFILE.PRG

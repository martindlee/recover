Parameter DBFfile
* Get basic file len info. for demo
PRIVATE ALL
DIMENSION FileArr[1,5]
=ADIR(FileArr, DBFfile) && get file details to FileArr
FileLen=FileArr[1,2]
RELEASE FileArr
IF filelen!=16386 AND filelen!=17786
  POP KEY
  DEFINE WINDOW demoscreen ;
    AT  0.000, 0.000  ;
    SIZE 15.000,75.000 ;
    TITLE "NOTICE:" ;
    FONT "Arial", 8 ;
    STYLE "B" ;
    NOFLOAT ;
    NOCLOSE ;
    NOMINIMIZE ;
    DOUBLE
  MOVE WINDOW demoscreen CENTER
  ACTIVATE WINDOW demoscreen NOSHOW
  @ 1.,2.167 SAY;
    "This is only a demo copy of Recover Vers. 4.0" + CHR(13) + ;
    "for FoxPro table and memo file recovery." + CHR(13) + ;
    "It is limited to the demo .DBF file sizes.";
    SIZE 6.000,52.250, 0.000 ;
    FONT "Arial", 10 ;
    STYLE "BT"

  @ 6.,2.167 SAY;
    "To obtain your registered copy of Recover please" + CHR(13) + ;
    "use ordering information is on our website" + CHR(13) + ;
    "http://www.abri.com/" ;
    SIZE 6.000,62.250, 0.000 ;
    FONT "Arial", 10 ;
    STYLE "BT"

  @ 12.538,35.167 GET _ok ;
    PICTURE "@*HT OK" ;
    SIZE 1.769,8.000,0.667 ;
    DEFAULT 1 ;
    FONT "Arial", 8 ;
    STYLE "B"

  ACTIVATE WINDOW demoscreen

  READ CYCLE

  RELEASE WINDOW demoscreen
  RETURN .F.
ENDIF

Return .T.
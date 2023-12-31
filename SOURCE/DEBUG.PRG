*       *********************************************************
*       *                                                         
*       * 01/12/95              DEBUG.PRG                00:32:27 
*       *                                                         
*       *********************************************************
*       *                                                         
*       * Author's Name                                           
*       *                                                         
*       * Copyright (c) 1995 Company Name                         
*       * Address                                                 
*       * City,     Zip                                           
*       *                                                         
*       * Description:                                            
*       * This program was automatically generated by GENSCRN.    
*       *                                                         
*       *********************************************************

PARAMETERS progname

*       *********************************************************
*       *                                                         
*       *          DEBUG/Windows Setup Code - SECTION 1           
*       *                                                         
*       *********************************************************
*

#REGION 1
* allows viewing of open tables for debugging

PRIVATE ALS, _I, J, _KL, _IMAX, _SAlias, SRec, _YN, _DBrowse
DIMENSION _KL[50]
_DBrowse=''
IF PARAMETERS()=0
  _PName=''
ELSE
  _PName= 'DEBUG CALLED FROM: '+ProgName
ENDIF
PUSH KEY
ON KEY LABEL ESCAPE
ON KEY LABEL ALT+F10 ACTIVATE WINDOW VIEW
_SAlias=ALIAS()	&& select current alias selection

_Imax=0
FOR I=1 TO 50
  IF NOT EMPTY(ALIAS(I))
    _Imax=_Imax+1
    _KL[_Imax]=I
  ENDIF
ENDFOR

IF _Imax=0
  DIMENSION ALS[1], Srec[1],K[1]
  _YN='NO'
  K[1]=1
  ALS[1]=' '
ELSE
  _YN='  '
  DIMENSION ALS[_Imax],Srec[_Imax],K[_Imax]
ENDIF
J=1
FOR I=1 TO _Imax && save record pointers
  K[I]=_KL[I]
  SELECT ALIAS(K[I])
  IF ALIAS()=_SAlias
    J=I
  ENDIF
  Srec[I] = RECNO()
  ALS[I]=STR(K[I],2)+' '+ALIAS(K[I])
ENDFOR
IF NOT EMPTY(_SAlias)
  SELECT (_SAlias)  && show current DBF
ENDIF
_DBrowse=STR(K[j],2)+' '+ALIAS(K[j])
RELEASE _KL	&& don't clutter up memory display
SET TALK OFF


#REGION 0
REGIONAL m.currarea, m.talkstat, m.compstat

IF SET("TALK") = "ON"
	SET TALK OFF
	m.talkstat = "ON"
ELSE
	m.talkstat = "OFF"
ENDIF
m.compstat = SET("COMPATIBLE")
SET COMPATIBLE FOXPLUS

m.rborder = SET("READBORDER")
SET READBORDER ON

*       *********************************************************
*       *                                                         
*       *               Windows Window definitions                
*       *                                                         
*       *********************************************************
*

IF NOT WEXIST("onebehind") ;
	OR UPPER(WTITLE("ONEBEHIND")) == "ONEBEHIND.PJX" ;
	OR UPPER(WTITLE("ONEBEHIND")) == "ONEBEHIND.SCX" ;
	OR UPPER(WTITLE("ONEBEHIND")) == "ONEBEHIND.MNX" ;
	OR UPPER(WTITLE("ONEBEHIND")) == "ONEBEHIND.PRG" ;
	OR UPPER(WTITLE("ONEBEHIND")) == "ONEBEHIND.FRX" ;
	OR UPPER(WTITLE("ONEBEHIND")) == "ONEBEHIND.QPR"
	DEFINE WINDOW onebehind ;
		AT 0.000, 1.000 ;
		SIZE 22.538,99.200 ;
		TITLE "Ctrl+Q exits browse" ;
		FONT "MS Sans Serif", 8 ;
		FLOAT ;
		NOCLOSE ;
		NOMINIMIZE
ENDIF


*       *********************************************************
*       *                                                         
*       *               DEBUG/Windows Screen Layout               
*       *                                                         
*       *********************************************************
*

#REGION 1
IF WVISIBLE("onebehind")
	ACTIVATE WINDOW onebehind SAME
ELSE
	ACTIVATE WINDOW onebehind NOSHOW
ENDIF
@ 2.692,76.800 SAY "Tables in use." ;
	FONT "MS Sans Serif", 10 ;
	STYLE "BT"
@ 18.615,71.000 SAY "(IF YOU GET STUCK)" ;
	FONT "MS Sans Serif", 8 ;
	STYLE "BT"
@ 0.846,69.600 SAY "READ LEVEL=" ;
	FONT "MS Sans Serif", 10 ;
	STYLE "BT"
@ 12.769,73.400 SAY "Courtesy of" + CHR(13) + ;
		"Abri Technologies, " + CHR(13) + ;
		"Expert Foxprow/Win" + CHR(13) + ;
		"Contract Work" + CHR(13) + ;
		"(304) 947-7129." ;
	SIZE 5.000,20.000, 0.000 ;
	PICTURE "@I" ;
	FONT "MS Sans Serif", 8 ;
	STYLE "T"
@ 7.154,68.800 SAY "Display Variables Like:" ;
	FONT "MS Sans Serif", 8 ;
	STYLE "BT"
@ 4.462,4.400 SAY "Execute Command" ;
	FONT "MS Sans Serif", 8 ;
	STYLE "BT"
@ 7.615,5.000 SAY "Double click on table for browsing:" ;
	FONT "MS Sans Serif", 8 ;
	STYLE "T"
@ 1.923,5.200 SAY _PName ;
	SIZE 1.000,46.167 ;
	FONT "MS Sans Serif", 8 ;
	STYLE "B"
@ 0.846,90.600 SAY RDLEVEL() ;
	SIZE 1.000,1.000 ;
	FONT "MS Sans Serif", 10 ;
	STYLE "B"
@ 2.692,69.800 SAY _YN ;
	SIZE 1.000,4.000 ;
	FONT "MS Sans Serif", 10 ;
	STYLE "B" ;
	PICTURE "@J"
@ 5.615,5.200 GET _excmd ;
	SIZE 1.000,90.400 ;
	DEFAULT " " ;
	FONT "MS Sans Serif", 8 ;
	PICTURE "@KT" ;
	VALID _qwt015rsh() ;
	COLOR ,RGB(,,,255,255,255)
@ 8.462,71.400 GET MemDispl ;
	SIZE 1.000,17.333 ;
	DEFAULT " " ;
	FONT "MS Sans Serif", 8 ;
	STYLE "B" ;
	PICTURE "@KT" ;
	WHEN _qwt015rwn() ;
	VALID _qwt015ryr() ;
	COLOR ,RGB(,,,255,255,255)
@ 10.231,71.000 GET _extxxx ;
	PICTURE "@*VT E\<xit" ;
	SIZE 1.625,15.125,1.250 ;
	DEFAULT 1 ;
	FONT "MS Sans Serif", 10 ;
	STYLE "B"
@ 19.769,71.000 GET _TRMPGM ;
	PICTURE "@*HT Terminate Foxprow" ;
	SIZE 1.923,20.167,0.667 ;
	DEFAULT 1 ;
	FONT "MS Sans Serif", 8 ;
	STYLE "B" ;
	VALID _qwt015s2y()
@ 8.769,5.200 GET _DBrowse ;
 	PICTURE "@&N" ;
	FROM ALS ;
	SIZE 12.692,52.400 ;
	DEFAULT 1 ;
	FONT "MS Sans Serif", 8 ;
	VALID _qwt015s5t()
@ 12.615,72.600 TO 18.230,94.400 ;
	PEN 1, 8

IF NOT WVISIBLE("onebehind")
	ACTIVATE WINDOW onebehind
ENDIF

READ CYCLE MODAL ;
	SHOW _qwt015sbm()

RELEASE WINDOW onebehind

#REGION 0

SET READBORDER &rborder

IF m.talkstat = "ON"
	SET TALK ON
ENDIF
IF m.compstat = "ON"
	SET COMPATIBLE ON
ENDIF


*       *********************************************************
*       *                                                         
*       *               DEBUG/Windows Cleanup Code                
*       *                                                         
*       *********************************************************
*

#REGION 1
IF WEXIST('View')
  ACTIVATE WINDOW VIEW
  KEYBOARD '{ESC}'
ENDIF
* restore all tables to original position
FOR I=1 TO _Imax && restore record pointers
  IF USED(ALIAS(K[I]))
    SELECT ALIAS(K[I])
    DO CASE
    CASE  (Srec[I] > RECCOUNT()) AND RECCOUNT()>0 && it was at end
      GO BOTTOM
      SKIP
    CASE RECCOUNT()=0 && there were no records
    OTHERWISE			&& normal case
      GO Srec[I]
    ENDCASE
  ENDIF
ENDFOR
IF NOT EMPTY(_SAlias) && select original table
  SELECT (_SAlias)
ENDIF

POP KEY





*       *********************************************************
*       *                                                         
*       *   DEBUG/Windows Supporting Procedures and Functions     
*       *                                                         
*       *********************************************************
*

#REGION 1
PROCEDURE DisplM
* Display memory
=ActWTW()
READ CYCLE MODAL ;
  WHEN _qkp1ebw1v()
RELEASE WINDOW this_window
RETURN

FUNCTION _qkp1ebw1v     && Read Level When
IF NOT EMPTY(MEMDISPL)
  DISPLAY MEMORY LIKE (MemDispl)
  ? ' '
  ? 'Press key/mouse to continue '
ELSE
  DISPLAY MEMORY
ENDIF
RETURN

*saves current database environment
oldselect = ALIAS()
oldorder = ORDER()
DO CASE
CASE RECCOUNT() = 0
  oldrecno = 0
CASE EOF()
  SKIP -1
  oldrecno = RECNO()
OTHERWISE
  oldrecno = RECNO()
ENDCASE
oldfilter = FILTER()
RETURN

PROCEDURE ActWTW
DEFINE WINDOW this_window ;
  AT 4.769, 8.000 ;
  SIZE 26.154,95.000 ;
  FONT "MS Sans Serif", 8 ;
  STYLE "B" ;
  NOFLOAT ;
  NOCLOSE ;
  NOMINIMIZE ;
  DOUBLE
ACTIVATE WINDOW this_window


*       *********************************************************
*       *                                                         
*       * _QWT015RSH           _excmd VALID                       
*       *                                                         
*       * Function Origin:                                        
*       *                                                         
*       * From Platform:       Windows                            
*       * From Screen:         DEBUG,     Record Number:   12     
*       * Variable:            _excmd                             
*       * Called By:           VALID Clause                       
*       * Object Type:         Field                              
*       * Snippet Number:      1                                  
*       *                                                         
*       *********************************************************
*
FUNCTION _qwt015rsh     &&  _excmd VALID
#REGION 1
IF NOT EMPTY(_excmd)
  ON ERROR *
  =ActWTW()
  &_excmd
  ? 'Press key/mouse to continue '
  READ CYCLE MODAL
  RELEASE WINDOW this_window
  ON ERROR
ENDIF
*_excmd=''
SHOW GET _excmd
SHOW GETS OFF


*       *********************************************************
*       *                                                         
*       * _QWT015RWN           MemDispl WHEN                      
*       *                                                         
*       * Function Origin:                                        
*       *                                                         
*       * From Platform:       Windows                            
*       * From Screen:         DEBUG,     Record Number:   13     
*       * Variable:            MemDispl                           
*       * Called By:           WHEN Clause                        
*       * Object Type:         Field                              
*       * Snippet Number:      2                                  
*       *                                                         
*       *********************************************************
*
FUNCTION _qwt015rwn     &&  MemDispl WHEN
#REGION 1
SET CURSOR ON


*       *********************************************************
*       *                                                         
*       * _QWT015RYR           MemDispl VALID                     
*       *                                                         
*       * Function Origin:                                        
*       *                                                         
*       * From Platform:       Windows                            
*       * From Screen:         DEBUG,     Record Number:   13     
*       * Variable:            MemDispl                           
*       * Called By:           VALID Clause                       
*       * Object Type:         Field                              
*       * Snippet Number:      3                                  
*       *                                                         
*       *********************************************************
*
FUNCTION _qwt015ryr     &&  MemDispl VALID
#REGION 1
IF NOT EMPTY(memdispl)
  SET CURSOR OFF
  DO DisplM
  SET CURSOR ON
ENDIF
*memdspl=''
show get memdispl

*       *********************************************************
*       *                                                         
*       * _QWT015S2Y           _TRMPGM VALID                      
*       *                                                         
*       * Function Origin:                                        
*       *                                                         
*       * From Platform:       Windows                            
*       * From Screen:         DEBUG,     Record Number:   15     
*       * Variable:            _TRMPGM                            
*       * Called By:           VALID Clause                       
*       * Object Type:         Push Button                        
*       * Snippet Number:      4                                  
*       *                                                         
*       *********************************************************
*
FUNCTION _qwt015s2y     &&  _TRMPGM VALID
#REGION 1
CLOSE DATABASES
QUIT

*       *********************************************************
*       *                                                         
*       * _QWT015S5T           _DBrowse VALID                     
*       *                                                         
*       * Function Origin:                                        
*       *                                                         
*       * From Platform:       Windows                            
*       * From Screen:         DEBUG,     Record Number:   16     
*       * Variable:            _DBrowse                           
*       * Called By:           VALID Clause                       
*       * Object Type:         List                               
*       * Snippet Number:      5                                  
*       *                                                         
*       *********************************************************
*
FUNCTION _qwt015s5t     &&  _DBrowse VALID
#REGION 1
IF NOT EMPTY(ALLTRIM(ALIAS[VAL(LEFT(_dbROWSE,2))]))
  DEFINE WINDOW _brow11;
    AT  0.000, 0.000 SIZE 35.000,90.000 ;
    FONT "Terminal", 8 STYLE 'N' NOCLOSE FLOAT GROW NOMINIMIZE NONE
*  MOVE WINDOW _brow11 CENTER

  SELECT ALIAS(VAL(LEFT(_dbROWSE,2)))
  BROWSE;
    TITLE "DEBUG BROWSE: Table "+ALIAS()+" - ESC exits";
    FONT "Terminal", 8 STYLE 'N' WINDOW _brow11
*    NOAPPEND NODELETE NOEDIT NOMENU WHEN .F.
  RELEASE WINDOW _brow11

ENDIF


*       *********************************************************
*       *                                                         
*       * _QWT015SBM           Read Level Show                    
*       *                                                         
*       * Function Origin:                                        
*       *                                                         
*       *                                                         
*       * From Platform:       Windows                            
*       * From Screen:         DEBUG                              
*       * Called By:           READ Statement                     
*       * Snippet Number:      6                                  
*       *                                                         
*       *********************************************************
*
FUNCTION _qwt015sbm     && Read Level Show
PRIVATE currwind
STORE WOUTPUT() TO currwind
*
* Show Code from screen: DEBUG
*
#REGION 1
IF SYS(2016) = "ONEBEHIND" OR SYS(2016) = "*"
	ACTIVATE WINDOW onebehind SAME
	@ 1.923,5.200 SAY _PName ;
		SIZE 1.000,46.167, 0.000 ;
		FONT "MS Sans Serif", 8 ;
		STYLE "B"
	@ 0.846,90.600 SAY RDLEVEL() ;
		SIZE 1.000,1.000, 0.000 ;
		FONT "MS Sans Serif", 10 ;
		STYLE "B"
	@ 2.692,69.800 SAY _YN ;
		SIZE 1.000,4.000, 0.000 ;
		FONT "MS Sans Serif", 10 ;
		STYLE "B" ;
		PICTURE "@J"
ENDIF
IF NOT EMPTY(currwind)
	ACTIVATE WINDOW (currwind) SAME
ENDIF
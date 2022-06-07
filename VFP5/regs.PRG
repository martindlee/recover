* generates single user license code for vfp5 into reg\vfp5s
clear
set safety off
erase ..\reg\temp\*.*
set safety on
copy file ..\runrec9\runrec9.exe to ..\reg\temp\runrec9.exe
erase illegal.prg
copy file ..\source\recover.prg to illegal.prg
build app recovers from recovers
do ..\fixdrive with 'recovers.app'
run ..\makes.bat vfp5
*erase illegal.prg
*erase recovers.app
clear

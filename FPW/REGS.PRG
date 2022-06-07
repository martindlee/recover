* generates single user license code for fpw into reg\fpws
clear
run ..\delreg
set safety off
copy file ..\source\recover.prg to illegal.prg
copy file ..\recovlck\recovlck.exe to ..\reg\temp\recovlck.exe
set safety on
modify project recovers
do ..\fixdrive with 'recovers.app'
run ..\makes.bat fpw
erase illegal.prg
erase recovers.app
clear


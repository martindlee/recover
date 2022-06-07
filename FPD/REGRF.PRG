* generates fpd RF package
clear
SET TALK OFF
run ..\delreg
set safety off
copy file ..\recovlck\recovlck.exe to ..\reg\temp\recovlck.exe
set safety on
modify project recover
do ..\fixdrive with 'recover.app'
modify project gendef
do ..\fixdrive with 'GENDEF.app'
run ..\makeRF.bat fpd
erase recover.app
erase gendef.app
clear

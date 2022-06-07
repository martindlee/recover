* generates vfp5 RF package
set safety off
erase ..\reg\temp\*.*
set safety on
copy file ..\rebuild\rebuild.zip to ..\reg\temp\rebuild.zip
build app recover from recover
do ..\fixdrive with 'recover.app'
build app gendef from gendef
do ..\fixdrive with 'gendef.app'
run ..\makeRF.bat vfp5
*erase recover.app
*erase gendef.app
clear

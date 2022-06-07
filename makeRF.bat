rem Generates %1RF.zip registered file
del ..\reg\temp < ..\y 
copy recover.app ..\reg\temp
copy gendef.app ..\reg\temp
copy ..\source\rtrace.prg  ..\reg\temp
copy ..\source\memoget.prg ..\reg\temp
copy ..\source\memoput.prg ..\reg\temp
copy ..\doc\genopt.prg ..\reg\temp
copy ..\doc\manual.txt ..\reg\temp
copy ..\doc\order.txt ..\reg\temp
copy ..\doc\recovmsg.zip ..\reg\temp
copy ..\doc\update.txt ..\reg\temp
del ..\reg\%1RF.zip
pkzip ..\reg\%1RF.zip ..\reg\temp\*.*
del ..\reg\temp < ..\y 
pause
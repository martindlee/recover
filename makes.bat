Rem Generates %1s.zip registered file
copy recovers.app ..\reg\temp
copy recovers.app \rec%1.app
copy ..\source\rtrace.prg  ..\reg\temp
copy ..\source\memoget.prg ..\reg\temp
copy ..\source\memoput.prg ..\reg\temp
copy ..\doc\manual.txt ..\reg\temp
copy ..\doc\update.txt ..\reg\temp
copy ..\doc\order.txt ..\reg\temp
del ..\reg\%1s.zip
pkzip ..\reg\%1s.zip ..\reg\temp\*.*
del ..\reg\temp < ..\y
pause
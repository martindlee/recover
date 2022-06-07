@echo off
pkunzip %1 a:
copy %1.zip a:
echo remove diskette and re-insert
pause
comp %1.zip a:

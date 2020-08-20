@echo off
cls
setlocal EnableDelayedExpansion
set "cmd=findstr /R /N "^^" StatPandLCheck.txt | find /C ":""

for /f %%a in ('!cmd!') do set number=%%a
IF %number% NEQ 0 (
echo "Success" 
) else (
echo "Failure"
)
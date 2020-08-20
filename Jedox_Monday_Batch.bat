:: ********************************
:: Batch script to run nightly ETL jobs via the Jedox ETL Client
:: ********************************

::
:: Use DebugFlag for testing
:: All the calls to the Jedox jobs are wrapped in a test of the DebugFlag
:: 0 = Debug mode off so run the jobs
:: 1 = Debug mode on so run the jobs are SKIPPED 
::

set DebugFlag=0

:: Remove the logs from prior runs
if exist MondayBatch*.log (
  del MondayBatch*.log
)

:: Set up Logs 
for /f "tokens=1 delims=." %%T in ('echo %TIME::=-%') do set TimeN=%%T
for /f "tokens=2 delims= " %%D in ('echo %DATE:/=-%') do set DateN=%%D
set LogFilePath="C:\Program Files\Jedox\Jedox Suite\tomcat\client"

:: Remove the double quotes from the path
call :dequote %LogFilePath%
set LogFileName="%ret%\MondayBatch-%DateN%_%timen%.log"

echo Path %LogFilePath%  > %LogFileName%
echo Name %LogFileName%  >> %LogFileName%

@echo off
set SalesDailyUpdate_ReturnCode=0
set EmailReturnCode=0
set HealthCode=0

for /f "tokens=*" %%i in ('time /t') do set Time_now=%%i
for /f "tokens=*" %%i in ('date /t') do set Date_now=%%i

:: Change to the correct drive and directory where the Jedox client resolves
c:
cd "C:\Program Files\Jedox\Jedox Suite\tomcat\client"


echo ***  Start of Jedox Monday batch: %Date_now% %Time_now%  ***  >> %LogFileName%
echo ***  Retrieving SalesDaily Update Times Now: %Date_now% %Time_now%  ***  >>%LogFileName%
echo. >> %LogFileName%

call .\etlclient -p "[99-00] Administrative Tasks" -j "[01-10]-Update Status Table with SalesDaily Load Dates" >>%LogFileName%
:: NOTE %ERRORLEVEL% is not returning the correct values everything is 0
:: Search the log for Warnings, Failed, Error and set the error level accordingly
type %LogFileName%|findstr /I /c:"Status: Failed"
IF %ERRORLEVEL% EQU 0 (
  SET SalesDailyUpdate_ReturnCode=12
)
IF %SalesDailyUpdate_ReturnCode% NEQ 0 goto SalesDailyUpateError

:: Now look for warnings
type %LogFileName%|findstr /I /c:"Completed with Warnings"
IF %ERRORLEVEL% EQU 0 (
  SET SalesDailyUpdate_ReturnCode=11
)
IF %SalesDailyUpdate_ReturnCode% NEQ 0 goto SalesDailyUpateError
IF %SalesDailyUpdate_ReturnCode% EQU 0 goto SendEmailMon

:SalesDailyUpateError
:: There was an error in the store polling data job
set EmailReturnCode=%SalesDailyUpdate_ReturnCode%
for /f "tokens=*" %%i in ('time /t') do set Time_now=%%i
for /f "tokens=*" %%i in ('date /t') do set Date_now=%%i
echo ***  Error PAS-SalesDaily Update ETL: %Date_now% %Time_now%  ***  >> %LogFileName%
echo ***  The email return code is: %EmailReturnCode%  ***  >> %LogFileName%
goto SendEmailMon

:SendEmailMon
:: Send and email each Monday with the SalesDaily update times

set FilePath="C:\Program Files\Jedox\Jedox Suite\tomcat\client"

:: Remove the double quotes from the path
call :dequote %FilePath%
set FileName="%ret%\SailesDailyUpdate.txt"

:: OutFile is the name of the file that will contain the email commands executed by PowerShell
set OutFile=sendmailmon.ps1

:: Strip the quotes from the log file name so it can be attached to the email

set SubjectText="SalesDaily Data Warehouse Table Update Times are in the file attached."

:: Generate the command to send an email with the results
:: NOTE $body contains the body of the email message
:: This is in the text file EmailBody.txt in the client directory
echo $body = Get-Content -Path EmailBodyMon.txt ^| Out-String >%OutFile%

if %DebugFlag% EQU 1 (
  IF %SalesDailyUpdate_ReturnCode% NEQ 0 (
    echo send-mailmessage -from ^"JedoxAdmin@pasco.com.au^" -to ^"RSnyder@pasco.com.au^" -subject %SubjectText% -body $body -Attachment %FileName%,%LogFile% -priority High -dno onFailure -smtpServer mtwrly01.onepas.local >>%OutFile%
  ) else (
        echo send-mailmessage -from ^"JedoxAdmin@pasco.com.au^" -to ^"RSnyder@pasco.com.au^" -subject %SubjectText% -body $body -Attachment %FileName% -priority High -dno onFailure -smtpServer mtwrly01.onepas.local >>%OutFile%
    )
)
if %DebugFlag% EQU 0 (
  IF %SalesDailyUpdate_ReturnCode% NEQ 0 (
    echo send-mailmessage -from ^"JedoxAdmin@pasco.com.au^" -to ^"RSnyder@pasco.com.au^", ^"MKocenda@pasco.com.au^" -subject %SubjectText% -body $body -Attachment %FileName%,%LogFile% -priority High -dno onFailure -smtpServer mtwrly01.onepas.local >>%OutFile%
  ) else (
        echo send-mailmessage -from ^"JedoxAdmin@pasco.com.au^" -to ^"RSnyder@pasco.com.au^", ^"MKocenda@pasco.com.au^" -subject %SubjectText% -body $body -Attachment %FileName% -priority High -dno onFailure -smtpServer mtwrly01.onepas.local >>%OutFile%
    )
)

:: Send the email using the file sendmail.ps1 which has just been "written" above
Powershell.exe -executionpolicy remotesigned -File "C:\Program Files\Jedox\Jedox Suite\tomcat\client\sendmailmon.ps1"
exit /B 0

:dequote
::This removes the double quotes from the string that was passed in.
setlocal
rem The tilde in the next line is the really important bit.
set thestring=%~1
endlocal&set ret=%thestring%
goto :eof

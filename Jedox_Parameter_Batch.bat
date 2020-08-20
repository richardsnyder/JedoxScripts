:: ********************************
:: Batch script to update Jedox Paremter cube via ETL jobs via ETL Client
:: ********************************

::
:: Use DebugFlag for testing
:: All the calls to the Jedox jobs are wrapped in a test of the DebugFlag
:: 0 = Debug mode off so run the jobs
:: 1 = Debug mode on so run the jobs are SKIPPED 
::

set DebugFlag=0

:: Remove the logs from prior runs
if exist ParameterBatch*.log (
  del ParameterBatch*.log
)

:: Set up Logs 
for /f "tokens=1 delims=." %%T in ('echo %TIME::=-%') do set TimeN=%%T
for /f "tokens=2 delims= " %%D in ('echo %DATE:/=-%') do set DateN=%%D
set LogFilePath="C:\Program Files\Jedox\Jedox Suite\tomcat\client"

:: Remove the double quotes from the path
call :dequote %LogFilePath%
set LogFileName="%ret%\ParameterBatch-%DateN%_%timen%.log"

echo Path %LogFilePath%  > %LogFileName%
echo Name %LogFileName%  >> %LogFileName%

@echo off
set Update_ReturnCode=0
set EmailReturnCode=0
set HealthCode=0

for /f "tokens=*" %%i in ('time /t') do set Time_now=%%i
for /f "tokens=*" %%i in ('date /t') do set Date_now=%%i

:: Change to the correct drive and directory where the Jedox client resolves
c:
cd "C:\Program Files\Jedox\Jedox Suite\tomcat\client"

echo ***  Start of Jedox Parameter Update batch: %Date_now% %Time_now%  ***  >> %LogFileName%
echo ***  Updating Retail Reporting Week from DataWarehouse: %Date_now% %Time_now%  ***  >>%LogFileName%
echo. >> %LogFileName%

call .\etlclient -p "[99-00] Administrative Tasks" -j "[01-04]-load[Cube]:Parameter - Week" >>%LogFileName%

echo ***  Loading Jedox Parameters into the DataWarehouse: %Date_now% %Time_now%  ***  >>%LogFileName%
echo. >> %LogFileName%
call .\etlclient -p "[99-00] Administrative Tasks" -j "[01-05]-load[DW]:Jedox_Parameters Table" >>%LogFileName%

:: NOTE %ERRORLEVEL% is not returning the correct values everything is 0
:: Search the log for Warnings, Failed, Error and set the error level accordingly
type %LogFileName%|findstr /I /c:"Status: Failed"
IF %ERRORLEVEL% EQU 0 (
  SET Update_ReturnCode=12
)
IF %Update_ReturnCode% NEQ 0 goto UpdateError

:: Now look for warnings
type %LogFileName%|findstr /I /c:"Completed with Warnings"
IF %ERRORLEVEL% EQU 0 (
  SET Update_ReturnCode=11
)
IF %Update_ReturnCode% NEQ 0 goto UpdateError
IF %Update_ReturnCode% EQU 0 goto SendEmail

:UpdateError
:: There was an error in the store polling data job
set EmailReturnCode=%Update_ReturnCode%
for /f "tokens=*" %%i in ('time /t') do set Time_now=%%i
for /f "tokens=*" %%i in ('date /t') do set Date_now=%%i
echo ***  Error Parameter Update ETL: %Date_now% %Time_now%  ***  >> %LogFileName%
echo ***  The email return code is: %EmailReturnCode%  ***  >> %LogFileName%
goto SendEmail

:SendEmail
:: Send and email each Monday with the SalesDaily update times

set FilePath="C:\Program Files\Jedox\Jedox Suite\tomcat\client"

:: Remove the double quotes from the path
call :dequote %FilePath%
set FileName="%ret%\ParameterCube.txt"
set WeekFile="%FilePath%\CurrentWeek.txt"

::Assign the contents of the file CurrentWeek.txt to the variable Week.
for /f "delims=" %%i in (CurrentWeek.txt) do set Week=%%i

:: OutFile is the name of the file that will contain the email commands executed by PowerShell
set OutFile=sendmailparam.ps1

:: Strip the quotes from the attached file names so they can be attached to the email
call :dequote %FileName%
set ParamFile=%ret%

call :dequote %LogFileName%
Set LogFile=%ret%

set SubjectText="Updated #_Parameter Cube Week Value to %Week%"
:: Generate the command to send an email with the results
:: NOTE $body contains the body of the email message
:: This is in the text file EmailBody.txt in the client directory
echo $body = Get-Content -Path EmailBodyParam.txt ^| Out-String >%OutFile%

if %DebugFlag% EQU 1 (
  echo send-mailmessage -from ^"JedoxAdmin@pasco.com.au^" -to ^"RSnyder@pasco.com.au^" -subject %SubjectText% -body $body -Attachment "%ParamFile%","%LogFile%" -priority High -dno onFailure -smtpServer mtwrly01.onepas.local >>%OutFile%
)

if %DebugFlag% EQU 0 (
  echo send-mailmessage -from ^"JedoxAdmin@pasco.com.au^" -to ^"RSnyder@pasco.com.au^", ^"MLau@pasco.com.au^" -subject %SubjectText% -body $body -Attachment "%ParamFile%","%LogFile%" -priority High -dno onFailure -smtpServer mtwrly01.onepas.local >>%OutFile%
)
:: , ^"MKocenda@pasco.com.au^"
:: Send the email using the file sendmail.ps1 which has just been "written" above
Powershell.exe -executionpolicy remotesigned -File "C:\Program Files\Jedox\Jedox Suite\tomcat\client\sendmailparam.ps1"
exit /B 0

:dequote
::This removes the double quotes from the string that was passed in.
setlocal
rem The tilde in the next line is the really important bit.
set thestring=%~1
endlocal&set ret=%thestring%
goto :eof

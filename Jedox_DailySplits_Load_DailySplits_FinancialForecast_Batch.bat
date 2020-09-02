:: ********************************
:: Batch script to run nightly ETL jobs via the Jedox ETL Client
:: ********************************

:: ******* Change Log *******************
:: **************************************
::
:: Use DebugFlag for testing
:: All the calls to the Jedox jobs are wrapped in a test of the DebugFlag
:: 0 = Debug mode off so run the jobs
:: 1 = Debug mode on so execution of the ETL jobs is SKIPPED 
::
set DebugFlag=0

:: Go to the drive and folder where the ETL client reside
C:
cd "C:\Program Files\Jedox\Jedox Suite\tomcat\client"

:: Remove the logs from prior runs
if exist DailySplitsImportDailySplitsFinancialForecastBatch*.log (
  del DailySplitsImportDailySplitsFinancialForecastBatch*.log
)

:: Work out the day of the week
:: If it's Monday load the Forecasts
For /F "tokens=1,2,3,4 delims=/ " %%A in ('Date /t') do @( 
  Set DOW=%%A
  Set Day=%%B
  Set Month=%%C
  Set Year=%%D
)

:: Set up Logs 
for /f "tokens=1 delims=." %%T in ('echo %TIME::=-%') do set TimeN=%%T
for /f "tokens=2 delims= " %%D in ('echo %DATE:/=-%') do set DateN=%%D
set LogFilePath="C:\Program Files\Jedox\Jedox Suite\tomcat\client"

:: Remove the double quotes from the path
call :dequote %LogFilePath%
set LogFileName="%ret%\DailySplitsImportDailySplitsFinancialForecastBatch-%DateN%_%timen%.log"

echo Path %LogFilePath%  > %LogFileName%
echo Name %LogFileName%  >> %LogFileName%

@echo off
:: Create/set variables for error checks
:: ====== Subroutine Codes ==============
set DailySplits_ReturnCode=0
set FinalReturnCode=0

::======== Batch Level Codes ==========
set EmailReturnCode=0
set HealthCode=0
set WeekParameterUpdateError=0
set ParameterUpdateError=0

for /f "tokens=*" %%i in ('time /t') do set Time_now=%%i
for /f "tokens=*" %%i in ('date /t') do set Date_now=%%i

echo ***  Start of Jedox daily splits export batch: %Date_now% %Time_now%  ***  >> %LogFileName%

::
:: How to run the PAS - FIN Test Job from the ETL Client
:: 
:: C:\Program Files\Jedox\Jedox Suite\tomcat\client\etlclient -p "[01-00]-PAS-FINANCIALS [Financials] Structure Update and Data Load" -j "Test Job" -o Testjob.log
:: 


::
:: Export JedoxParamete to a file
:UpdateParameters
for /f "tokens=*" %%i in ('time /t') do set Time_now=%%i
for /f "tokens=*" %%i in ('date /t') do set Date_now=%%i
echo ***  Starting Export of Parameter Cube to File Job Now: %Date_now% %Time_now%  ***  >>%LogFileName%
echo. >> %LogFileName%
IF %DebugFlag% EQU 0 (
  call .\etlclient -p "[99-00] Administrative Tasks" -j "[01-11]-Parameter Cube Export" >>%LogFileName%
)
:: NOTE %ERRORLEVEL% is not returning the correct values everything is 0
:: Search the log for Warnings, Failed, Error and set the error level accordingly
:: ERRORLEVEL 0 means it found the string!!
type %LogFileName%|findstr /I /c:"Status: Failed"
IF %ERRORLEVEL% EQU 0 (
  SET ParameterUpdateError=2
)
type %LogFileName%|findstr /I /c:"Completed with Warnings"
)
IF %ERRORLEVEL% EQU 0 (
  SET ParameterUpdateError=1
)

IF %ParameterUpdateError% NEQ 0 (
  echo ***  Check Parameter Cube ***  >>%LogFileName%
  set EmailReturnCode=999
  goto SendEmail
) else (
  echo ***  Parameter Cube Successfully Exported ***  >>%LogFileName%
  echo. >> %LogFileName%
)

::
:: Capture the current/Forecast year
:: from a file created in the previous step.
:: Use as variables for down stream processing
:CaptureParameters
for /f "tokens=*" %%i in ('time /t') do set Time_now=%%i
for /f "tokens=*" %%i in ('date /t') do set Date_now=%%i
echo ***  Capturing Parameters Now: %Date_now% %Time_now%  ***  >>%LogFileName%
echo. >> %LogFileName%

:: Capture Current Year In Financials Cube
type ParameterCube.txt|findstr /B /c:"CurrYear " >DailySplits_CurrYear.txt
type DailySplits_CurrYear.txt

For /F "tokens=1,2,3,4 delims=/ " %%A in ('type  DailySplits_CurrYear.txt') do (
  Set CurrYear=%%B
)
echo CurrYear is %CurrYear% >>%LogFileName%

:: Capture Forecast Year
type ParameterCube.txt|findstr /I /c:"BudYear " >DailySplits_BudYear.txt
type DailySplits_BudYear.txt

For /F "tokens=1,2,3,4 delims=/ " %%A in ('type  DailySplits_BudYear.txt') do (
  Set BudYear=%%B
)
echo BudYear  is %BudYear% >>%LogFileName%

:: 2020-Aug-26 RKS Added Daily Splits Export
:DailySplitsExport
for /f "tokens=*" %%i in ('time /t') do set Time_now=%%i
for /f "tokens=*" %%i in ('date /t') do set Date_now=%%i
echo ***  Daily Splits Export Job Now: %Date_now% %Time_now%  ***  >>%LogFileName%
echo. >> %LogFileName%

IF %DebugFlag% EQU 0 (
  call .\etlclient -p "[04-04]-PAS-FINANCIALS [Daily Splits by Dispatch Type]" -j "Load Financial Forecast Daily Splits" >>%LogFileName%
)
GOTO SendEmail


:SendEmail
:: We are here so there have been no errors
:: Perform a database save prior to sending the email

SET FinalReturnCode=0
SET EmailReturnCode=0

:: Look for Errors
type %LogFileName%|findstr /I /c:"ERROR [main]"
IF %ERRORLEVEL% EQU 0 (
  SET FinalReturnCode=2 
  set EmailReturnCode=2
)

:: Look for failures
type %LogFileName%|findstr /I /c:"Status: Failed"
IF %ERRORLEVEL% EQU 0 (
  SET FinalReturnCode=2 
  set EmailReturnCode=2
)

:: Now look for warnings
type %LogFileName%|findstr /I /c:"Completed with Warnings"
IF %ERRORLEVEL% EQU 0 (
  SET FinalReturnCode=1 
  set EmailReturnCode=1
)

echo ************ Final Return Code is: %FinalReturnCode% ***************** >> %LogFileName%

for /f "tokens=*" %%i in ('time /t') do set Time_now=%%i
for /f "tokens=*" %%i in ('date /t') do set Date_now=%%i
echo ***  Sending Email Now: %Date_now% %Time_now%  ***  >> %LogFileName%
echo ***  The email return code is : %EmailReturnCode%  ***  >> %LogFileName%
echo. >> %LogFileName%

set OutFile=DailySplitsForecastLoadSendMail.ps1

:: Strip the quotes from the log file name so it can be attached to the email
call :dequote %LogFileName%

:: Generate the subject based on the results %EmailReturnCode%
:: HC:0 = Both the Financials and Retail cube updates were successful
:: HC:1 = The Financials update completed with warnings and the Retail cube was not updated
:: HC:2 = The Financials update failed and the Retail cube was not updated
:: HC:3 = The Financials update was successful but the Retail cube completed with warnings
:: HC:4 = The Financials update was successful but the Retail cube update failed

IF %EmailReturnCode% EQU 0 (
  set SubjectText="Step 3 Jedox Daily Spits Financial Forecast Import  Batch - Daily Splits Import Successful"
)
IF %EmailReturnCode% EQU 1 (
  set SubjectText="Step 3 Jedox Daily Spits Financial Forecast Import  Batch - The Daily Splits Import completed with warnings"
)
IF %EmailReturnCode% EQU 2 (
  set SubjectText="Step 3 Jedox Daily Spits Financial Forecast Import  Batch - The Daily Splits Import failed! - Investigate NOW!"
)
IF %EmailReturnCode% EQU 999 (
  set SubjectText="Step 3 Jedox Daily Spits Financial Forecast Import  Batch - The Update of Paramters Failed! - Investigate NOW! "
)
:: Generate the command to send an email with the results
:: NOTE $body contains the body of the email message
:: This is in the text file EmailBody.txt in the client directory

set BodyText="Daily splits have been loaded into the Jedox cube Retail by Dispatch Type. Log files are attached."

:: The next line is for testing only
if %DebugFlag% EQU 1 (
  echo send-mailmessage -from ^"JedoxAdmin@pasco.com.au^" -to ^"JedoxNightly@pasco.com.au^" -subject %SubjectText% -body %BodyText% -Attachment "%ret%" -priority High -dno onFailure -smtpServer mtwrly01.onepas.local >%OutFile%
) else (
  echo send-mailmessage -from ^"JedoxAdmin@pasco.com.au^" -to ^"JedoxNightly@pasco.com.au^", ^"pasaccountants@pasco.com.au^" -subject %SubjectText% -body %BodyText% -Attachment "%ret%" -priority High -dno onFailure -smtpServer mtwrly01.onepas.local >%OutFile%
)

:: Send the email using the file DailySplitsForecastLoadSendMail.ps1 which has just been "written" above
Start /wait Powershell.exe -executionpolicy remotesigned -File "C:\Program Files\Jedox\Jedox Suite\tomcat\client\DailySplitsForecastLoadSendMail.ps1"
exit /B %EmailReturnCode%

:dequote
::This removes the double quotes from the string that was passed in.
setlocal
:: The tilde in the next line is the really important bit.
set thestring=%~1
endlocal&set ret=%thestring%
goto :eof
:: ********************************
:: Batch script to run nightly ETL jobs via the Jedox ETL Client
:: ********************************

:: ******* Change Log *******************
:: 2015-05-01 RKS - Turned off the update of forecast as this should only change when there is a new forecast
:: 2015-05-08 RKS - Turned off the update of budget each monday as we don't want it to change until the budget open/close dates are sorted out.
:: 2015-05-12 RKS - Added weekly store status update (each Sunday) load.
:: 2015-05-13 RKS - Changed around to run Store Attribute check first 
:: 2015-05-25 RKS - Turned on the actualisation of forecast but not update of forecast_mmm 
:: 2015-05-29 RKS - Changed variable extract to CurrYearETL, PrevYearETL, BudYearETL (CaptureParameters section)
:: 2015-07-01 RKS - Modified for use of NextYearETL for daily extract
:: 2015-08-24 RKS - Changed the order of processes (Financials/Retail, Status Update, Weekly Retail, Daily Retail...)
:: 2015-09-11 RKS - Added the Stat P&L check process and CAPEX and Sales Cube loads
:: 2015-09-28 RKS - Added load for Retail and Financial LTM cubes
:: 2015-11-05 RKS - Added Cash Flow cube Update - Runs after Financial and Retail but before Weekly sales
:: 2016-03-29 RKS - Changed the name of the projects from PAS-FINANCIALS to PAS-DEVELOPMENT
:: **************************************
::
:: Use DebugFlag for testing
:: All the calls to the Jedox jobs are wrapped in a test of the DebugFlag
:: 0 = Debug mode off so run the jobs
:: 1 = Debug mode on so execution of the ETL jobs is SKIPPED 
::
set DebugFlag=0

c:
cd "C:\Program Files\Jedox\Jedox Suite\tomcat\client"

:: Remove the logs from prior runs
if exist NightlyCompBatch*.log (
  del NightlyCompBatch*.log
)

:: Work out the day of the week
:: If it's Monday load the Budgets
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
set LogFileName="%ret%\NightlyCompBatch-%DateN%_%timen%.log"

echo Path %LogFilePath%  > %LogFileName%
echo Name %LogFileName%  >> %LogFileName%

@echo off
:: Create/set variables for error checks
:: ====== Subroutine Codes ==============
set WeeklyStoreStatusUpdate_ReturnCode=0
set WeeklyStoreCompTypeUpdate_ReturnCode=0

::======== Batch Level Codes ==========
set EmailReturnCode=0
set HealthCode=0
set WeekParameterUpdateError=0
set ParameterUpdateError=0

for /f "tokens=*" %%i in ('time /t') do set Time_now=%%i
for /f "tokens=*" %%i in ('date /t') do set Date_now=%%i

c:
cd "C:\Program Files\Jedox\Jedox Suite\tomcat\client"
echo ***  Start of Jedox nightly comp batch: %Date_now% %Time_now%  ***  >> %LogFileName%

::
:: How to run the PAS - FIN Test Job from the ETL Client
:: 
:: C:\Program Files\Jedox\Jedox Suite\tomcat\client\etlclient -p "[01-00]-PAS-DEVELOPMENT [Financials] Structure Update and Data Load" -j "Test Job" -o Testjob.log
:: 

::
:: Capture the forecast month version, previous/current/budget year, and Store Attribute Change 
:: from a file created in the previous step.
:: Use as variables for down stream processing
:CaptureParameters
for /f "tokens=*" %%i in ('time /t') do set Time_now=%%i
for /f "tokens=*" %%i in ('date /t') do set Date_now=%%i
echo ***  Capturing Parameters Now: %Date_now% %Time_now%  ***  >>%LogFileName%
echo. >> %LogFileName%

:: Capture Retail Forecast Month
:: Loading Forecast
type ParameterCube.txt|findstr /I /c:"Retail Forecast Version" >Forecast_MMM.txt
type Forecast_MMM.txt

For /F "tokens=1,2,3,4 delims=/ " %%A in ('type  Forecast_MMM.txt') do (
  Set FcastVer=%%D
)
echo RetailFcastVer is %FcastVer% >>%LogFileName%

:: Capture Financial Forecast Month
:: Loading Forecast
type ParameterCube.txt|findstr /I /c:"FMth" >FinancialForecast_MMM.txt
type FinancialForecast_MMM.txt

For /F "tokens=1,2,3,4 delims=/ " %%A in ('type  FinancialForecast_MMM.txt') do (
  Set FinFcastVer=%%B
)
echo FinancialFcastVer is %FinFcastVer% >>%LogFileName%

:: Capture Previous Year
:: Loading Actuals
type ParameterCube.txt|findstr /I /c:"PrevYearETL" >PrevYear.txt
type PrevYear.txt

For /F "tokens=1,2,3,4 delims=/ " %%A in ('type  PrevYear.txt') do (
  Set PrevYear=%%B
)
echo PrevYear is %PrevYear% >>%LogFileName%

:: Capture Current Year
:: Loading Actuals, Budget, Forecast
type ParameterCube.txt|findstr /I /c:"CurrYearETL" >CurrYear.txt
type CurrYear.txt

For /F "tokens=1,2,3,4 delims=/ " %%A in ('type  CurrYear.txt') do (
  Set CurrYear=%%B
)
echo CurrYear is %CurrYear% >>%LogFileName%

:: Capture Budget Year
:: Loading Budget
type ParameterCube.txt|findstr /I /c:"BudYearETL" >BudYear.txt
type BudYear.txt

For /F "tokens=1,2,3,4 delims=/ " %%A in ('type  BudYear.txt') do (
  Set BudYear=%%B
)
echo BudYear  is %BudYear% >>%LogFileName%

:: Capture Next Year
:: Loading Sales Daily
type ParameterCube.txt|findstr /I /c:"NextYearETL" >NextYear.txt
type NextYear.txt

For /F "tokens=1,2,3,4 delims=/ " %%A in ('type  NextYear.txt') do (
  Set NextYear=%%B
)
echo NextYear  is %NextYear% >>%LogFileName%

:PasWklyRtlStoreStatusUpdate
for /f "tokens=*" %%i in ('time /t') do set Time_now=%%i
for /f "tokens=*" %%i in ('date /t') do set Date_now=%%i
echo ***  Starting Weekly Store Calendar and Store Calendar Week Update Job Now: %Date_now% %Time_now%  ***  >>%LogFileName%
echo. >> %LogFileName%

IF %DebugFlag% EQU 0 (
  call .\etlclient -p "[99-00] Administrative Tasks" -j "[01-07]-load [Cube]:Store Calendar and Store Calendar Week - Store Status Dates" >>%LogFileName%
)
:: NOTE %ERRORLEVEL% is not returning the correct values everything is 0
:: Search the log for Warnings, Failed, Error and set the error level accordingly
:: ERRORLEVEL 0 means it found the string!!
type %LogFileName%|findstr /I /c:"Status: Failed"
IF %ERRORLEVEL% EQU 0 (
  SET WeeklyStoreStatusUpdate_ReturnCode=14
)
IF %WeeklyStoreStatusUpdate_ReturnCode% NEQ 0 goto PasWklyRtlStoreStatusUpdateError

:: Now look for warnings
type %LogFileName%|findstr /I /c:"Completed with Warnings"
IF %ERRORLEVEL% EQU 0 (
  SET WeeklyStoreStatusUpdate_ReturnCode=13
)
IF %WeeklyStoreStatusUpdate_ReturnCode% NEQ 0 goto PasWklyRtlStoreStatusUpdateError
IF %WeeklyStoreStatusUpdate_ReturnCode% EQU 0 goto PasWklyRtlStoreCompUpdate

:PasWklyRtlStoreStatusUpdateError
:: There was an error in the PAS - FIN Test Job
set EmailReturnCode=%WeeklyStoreStatusUpdate_ReturnCode%
for /f "tokens=*" %%i in ('time /t') do set Time_now=%%i
for /f "tokens=*" %%i in ('date /t') do set Date_now=%%i
echo ***  Error PAS-StoreStatusUpdate ETL: %Date_now% %Time_now%  ***  >> %LogFileName%
echo ***  The email return code is: %EmailReturnCode%  ***  >> %LogFileName%
goto SendEmail

:PasWklyRtlStoreCompUpdate
for /f "tokens=*" %%i in ('time /t') do set Time_now=%%i
for /f "tokens=*" %%i in ('date /t') do set Date_now=%%i
echo ***  Starting Export of Store Comp to DW Job Now: %Date_now% %Time_now%  ***  >>%LogFileName%
echo. >> %LogFileName%

IF %DebugFlag% EQU 0 (
  call .\etlclient -p "[99-00] Administrative Tasks" -j "[01-08]-Load Store Comp Type into DW" -c PrevYear=%PrevYear% CurrYear=%CurrYear% BudYear=%BudYear% >>%LogFileName%
)
:: NOTE %ERRORLEVEL% is not returning the correct values everything is 0
:: Search the log for Warnings, Failed, Error and set the error level accordingly
type %LogFileName%|findstr /I /c:"Status: Failed"
IF %ERRORLEVEL% EQU 0 (
  SET WeeklyStoreCompTypeUpdate_ReturnCode=12
)
IF %WeeklyStoreCompTypeUpdate_ReturnCode% NEQ 0 goto PasWklyRtlStoreCompUpdateError

:: Now look for warnings
type %LogFileName%|findstr /I /c:"Completed with Warnings"
IF %ERRORLEVEL% EQU 0 (
  SET WeeklyRtlSalesForecast_ReturnCode=11
)
IF %WeeklyStoreCompTypeUpdate_ReturnCode% NEQ 0 goto PasWklyRtlStoreCompUpdateError
IF %WeeklyStoreCompTypeUpdate_ReturnCode% EQU 0 goto SendEmail

:PasWklyRtlStoreCompUpdateError
:: There was an error in the update of comp store data into the DW
set EmailReturnCode=%WeeklyStoreCompTypeUpdate_ReturnCode%
for /f "tokens=*" %%i in ('time /t') do set Time_now=%%i
for /f "tokens=*" %%i in ('date /t') do set Date_now=%%i
echo ***  Error PAS-WeeklyStoreCompTypeUpdate ETL: %Date_now% %Time_now%  ***  >> %LogFileName%
echo ***  The email return code is: %EmailReturnCode%  ***  >> %LogFileName%
goto SendEmail


:SendEmail
:: We are here so there have been no errors
:: Perform a database save prior to sending the email

for /f "tokens=*" %%i in ('time /t') do set Time_now=%%i
for /f "tokens=*" %%i in ('date /t') do set Date_now=%%i
echo ***  Sending Email Now: %Date_now% %Time_now%  ***  >> %LogFileName%
echo ***  The email return code is : %EmailReturnCode%  ***  >> %LogFileName%
echo. >> %LogFileName%

set OutFile=sendmail.ps1

:: Strip the quotes from the log file name so it can be attached to the email
call :dequote %LogFileName%

:: Generate the subject based on the results %EmailReturnCode%
:: HC:0 = Both the Financials and Retail cube updates were successful
:: HC:1 = The Financials update completed with warnings and the Retail cube was not updated
:: HC:2 = The Financials update failed and the Retail cube was not updated
:: HC:3 = The Financials update was successful but the Retail cube completed with warnings
:: HC:4 = The Financials update was successful but the Retail cube update failed

IF %EmailReturnCode% EQU 0 (
  set SubjectText="Results from Jedox Comp Update Nightly Batch - All extracts and cube loads were successful"
)
IF %EmailReturnCode% EQU 11 (
  set SubjectText="Results from Jedox Comp Update Nightly Batch - The Weekly Comp Store Update completed with warnings"
)
IF %EmailReturnCode% EQU 12 (
  set SubjectText="Results from Jedox Comp Update Nightly Batch - The Weekly Comp Store Update failed"
)
IF %EmailReturnCode% EQU 13 (
  set SubjectText="Results from Jedox Comp Update Nightly Batch - The Weekly Store Status Update completed with warnings"
)
IF %EmailReturnCode% EQU 14 (
  set SubjectText="Results from Jedox Comp Update Nightly Batch - The Weekly Store Status Update failed"
)
:: Generate the command to send an email with the results
:: NOTE $body contains the body of the email message
:: This is in the text file EmailBody.txt in the client directory
echo $body = Get-Content -Path EmailBody.txt ^| Out-String >%OutFile%

:: The next line is for testing only
if %DebugFlag% EQU 1 (
  echo send-mailmessage -from ^"JedoxAdmin@pasco.com.au^" -to ^"RSnyder@pasco.com.au^" ,^"MLau@pasco.com.au^" -subject %SubjectText% -body $body -Attachment "%ret%" -priority High -dno onFailure -smtpServer mtwrly01.onepas.local >>%OutFile%
) else (
  echo send-mailmessage -from ^"JedoxAdmin@pasco.com.au^" -to ^"RSnyder@pasco.com.au^", ^"MLau@pasco.com.au^" -subject %SubjectText% -body $body -Attachment "%ret%" -priority High -dno onFailure -smtpServer mtwrly01.onepas.local >>%OutFile%
)

:: Send the email using the file sendmail.ps1 which has just been "written" above
Start /wait Powershell.exe -executionpolicy remotesigned -File "C:\Program Files\Jedox\Jedox Suite\tomcat\client\sendmail.ps1"
exit /B %EmailReturnCode%

:dequote
::This removes the double quotes from the string that was passed in.
setlocal
rem The tilde in the next line is the really important bit.
set thestring=%~1
endlocal&set ret=%thestring%
goto :eof
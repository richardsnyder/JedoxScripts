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
if exist FinancialBatch*.log (
  del FinancialBatch*.log
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

:: ======= Capture the Time for Sending Email purposes ==========
:: ======= Only send the mail if it is after 7am ================
for /f "tokens=1 delims=-" %%T in ('echo %TIME::=-%') do set RunTime=%%T

:: Remove the double quotes from the path
call :dequote %LogFilePath%
set LogFileName="%ret%\FinancialBatch-%DateN%_%timen%.log"

echo Path %LogFilePath%  > %LogFileName%
echo Name %LogFileName%  >> %LogFileName%

@echo off
:: Create/set variables for error checks
:: ====== Subroutine Codes ==============
set DimLoad_ReturnCode=0
set PasFin_ReturnCode=0
set CashFlow_ReturnCode=0

::======== Batch Level Codes ==========
set EmailReturnCode=0
set HealthCode=0
set WeekParameterUpdateError=0
set ParameterUpdateError=0

for /f "tokens=*" %%i in ('time /t') do set Time_now=%%i
for /f "tokens=*" %%i in ('date /t') do set Date_now=%%i

c:
cd "C:\Program Files\Jedox\Jedox Suite\tomcat\client"
echo ***  Start of Jedox nigtly batch: %Date_now% %Time_now%  ***  >> %LogFileName%


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

:: Capture Current Year In Financials Cube
:: Loading Actuals, Budget, Forecast
type ParameterCube.txt|findstr /I /c:"CurrYear" >CurrYearFIN.txt
type CurrYearFIN.txt

For /F "tokens=1,2,3,4 delims=/ " %%A in ('type  CurrYearFIN.txt') do (
  Set CurrYearFIN=%%B
)
echo CurrYearFIN is %CurrYearFIN% >>%LogFileName%

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
::
:: How to run the PAS - FIN Test Job from the ETL Client
::

:: Dimension load
:DimensionLoad
for /f "tokens=*" %%i in ('time /t') do set Time_now=%%i
for /f "tokens=*" %%i in ('date /t') do set Date_now=%%i
echo ***  Starting Dimension Update Job Now: %Date_now% %Time_now%  ***  >>%LogFileName%
echo. >> %LogFileName%

IF %DebugFlag% EQU 0 (
  call .\etlclient -p "[00-00]-PAS-FINANCIALS Load All Dimensions" -j "Load Dimensions" >>%LogFileName%
)
:: NOTE %ERRORLEVEL% is not returning the correct values everything is 0
:: Search the log for Warnings, Failed, Error and set the error level accordingly
type %LogFileName%|findstr /I /c:"Status: Failed"
IF %ERRORLEVEL% EQU 0 (
  SET DimLoad_ReturnCode=2
)
IF %DimLoad_ReturnCode% NEQ 0 goto DimLoadError

:: Now look for warnings  
type %LogFileName%|findstr /I /c:"Completed with Warnings"
IF %ERRORLEVEL% EQU 0 (
  SET DimLoad_ReturnCode=1
)
IF %DimLoad_ReturnCode% NEQ 0 goto DimLoadError

:: If no errors with finance job found run the retail job
IF %DimLoad_ReturnCode% EQU 0 goto FinCubLoad

:DimLoadError
:: There was an error in the Financials Load Test Job
set EmailReturnCode=%DimLoad_ReturnCode%
for /f "tokens=*" %%i in ('time /t') do set Time_now=%%i
for /f "tokens=*" %%i in ('date /t') do set Date_now=%%i
echo ***  Error PAS-FIN ETL: %Date_now% %Time_now%  ***  >> %LogFileName%
echo ***  The email return code is: %EmailReturnCode%  ***  >> %LogFileName%
goto SendEmail


:: Financials cube load
:FinCubLoad
for /f "tokens=*" %%i in ('time /t') do set Time_now=%%i
for /f "tokens=*" %%i in ('date /t') do set Date_now=%%i
echo ***  Starting Financials Update Job Now: %Date_now% %Time_now%  ***  >>%LogFileName%
echo. >> %LogFileName%

IF %DebugFlag% EQU 0 (
  call .\etlclient -p "[01-00]-PAS-FINANCIALS [Financials] Structure Update and Data Load" -j "Fin Nightly" >>%LogFileName%
  call .\etlclient -p "[99-00] Administrative Tasks" -j "[01-07]-load [Cube]:Store Calendar and Store Calendar Week - Store Status Dates" >>%LogFileName%
  call .\etlclient -p "[02-00]-PAS-FINANCIALS [Retail] Store Update and Data Load" -j "[02-00]-load[Cube]:Retail(FinancialsLoad_All:_Budget)" >>%LogFileName%
  call .\etlclient -p "[02-00]-PAS-FINANCIALS [Retail] Store Update and Data Load" -j "[03-00]-load[Cube]:Retail(CompType_All:_Budget)" >>%LogFileName%
  call .\etlclient -p "[06-00]-PAS-FINANCIALS [CAPEX]" -j "[01-00] CAPEX Actual And Forecast_MMM Load" >>%LogFileName%  
)
:: NOTE %ERRORLEVEL% is not returning the correct values everything is 0
:: Search the log for Warnings, Failed, Error and set the error level accordingly
type %LogFileName%|findstr /I /c:"Status: Failed"
IF %ERRORLEVEL% EQU 0 (
  SET PasFin_ReturnCode=2
)
IF %PasFin_ReturnCode% NEQ 0 goto PasFinError

:: Now look for warnings  
type %LogFileName%|findstr /I /c:"Completed with Warnings"
IF %ERRORLEVEL% EQU 0 (
  SET PasFin_ReturnCode=1
)
IF %PasFin_ReturnCode% NEQ 0 goto PasFinError

:: If no errors with finance job found run the retail job
IF %PasFin_ReturnCode% EQU 0 goto CashFlowCubLoad

:PasFinError
:: There was an error in the Financials Load Test Job
set EmailReturnCode=%PasFin_ReturnCode%
for /f "tokens=*" %%i in ('time /t') do set Time_now=%%i
for /f "tokens=*" %%i in ('date /t') do set Date_now=%%i
echo ***  Error PAS-FIN ETL: %Date_now% %Time_now%  ***  >> %LogFileName%
echo ***  The email return code is: %EmailReturnCode%  ***  >> %LogFileName%
goto SendEmail

:: Update Cash Flow
:CashFlowCubLoad
for /f "tokens=*" %%i in ('time /t') do set Time_now=%%i
for /f "tokens=*" %%i in ('date /t') do set Date_now=%%i
echo ***  Starting Cash Flow Update Job Now: %Date_now% %Time_now%  ***  >>%LogFileName%
echo. >> %LogFileName%

IF %DebugFlag% EQU 0 (
  call .\etlclient -p "[08-00]-PAS-FINANCIALS [Cash Flow]" -j "[00-00-01]-CashFlow Update Act & Fcast" -c CurrYear=%CurrYearFIN% Forecast_MMM=%FinFcastVer% >>%LogFileName%
)
:: NOTE %ERRORLEVEL% is not returning the correct values everything is 0
:: Search the log for Warnings, Failed, Error and set the error level accordingly
type %LogFileName%|findstr /I /c:"Status: Failed"
IF %ERRORLEVEL% EQU 0 (
  SET CashFlow_ReturnCode=2
)
IF %CashFlow_ReturnCode% NEQ 0 goto CashFlowError

:: Now look for warnings  
type %LogFileName%|findstr /I /c:"Completed with Warnings"
IF %ERRORLEVEL% EQU 0 (
  SET CashFlow_ReturnCode=1
)
IF %CashFlow_ReturnCode% NEQ 0 goto CashFlowError

:: If no errors with finance job found run the retail job
IF %CashFlow_ReturnCode% EQU 0 goto :eof

:CashFlowError
:: There was an error in the Financials Load Test Job
set EmailReturnCode=%CashFlow_ReturnCode%
for /f "tokens=*" %%i in ('time /t') do set Time_now=%%i
for /f "tokens=*" %%i in ('date /t') do set Date_now=%%i
echo ***  Error Cash Flow ETL: %Date_now% %Time_now%  ***  >> %LogFileName%
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
  set SubjectText="Jedox Cube Update was Successful"
)
IF %EmailReturnCode% EQU 1 (
  set SubjectText="Jedox Cube Update Completed with Warnings"
)
IF %EmailReturnCode% EQU 2 (
  set SubjectText="Jedox Cube Update Failed"
)

:: Generate the command to send an email with the results
:: NOTE $body contains the body of the email message
:: This is in the text file EmailBody.txt in the client directory
echo $body = Get-Content -Path EmailBodyFinUpdate.txt ^| Out-String >%OutFile%

:: The next line is for testing only
if %DebugFlag% EQU 1 (
  echo send-mailmessage -from ^"JedoxAdmin@pasco.com.au^" -to ^"RSnyder@pasco.com.au^" ,^"MLau@pasco.com.au^" -subject %SubjectText% -body $body -Attachment "%ret%" -priority High -dno onFailure -smtpServer mtwrly01.onepas.local >>%OutFile%
) else ( 
  echo send-mailmessage -from ^"JedoxAdmin@pasco.com.au^" -to ^"RSnyder@pasco.com.au^" ,^"MLau@pasco.com.au^" -subject %SubjectText% -body $body -Attachment "%ret%" -priority High -dno onFailure -smtpServer mtwrly01.onepas.local >>%OutFile%
)

:: Send the email using the file sendmail.ps1 which has just been "written" above IF IT IS AFTER 7AM
:: Don't send the email to the accountants during the nightly processing.
if %RunTime% GTR 7 (
  start /wait Powershell.exe -executionpolicy remotesigned -File "C:\Program Files\Jedox\Jedox Suite\tomcat\client\sendmail.ps1"
)
exit /b %EmailReturnCode%

:dequote
::This removes the double quotes from the string that was passed in.
setlocal
rem The tilde in the next line is the really important bit.
set thestring=%~1
endlocal&set ret=%thestring%
goto :eof
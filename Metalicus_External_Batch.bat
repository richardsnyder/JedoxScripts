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
cd "C:\Program Files\Jedox\Jedox Suite\tomcat\client"
:: Remove the logs from prior runs
if exist NightlyBatch*.log (
  del NightlyBatch*.log
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
set LogFileName="%ret%\NightlyBatch-%DateN%_%timen%.log"

echo Path %LogFilePath%  > %LogFileName%
echo Name %LogFileName%  >> %LogFileName%

@echo off
:: Create/set variables for error checks
:: ====== Subroutine Codes ==============
set PasFin_TestJob_ReturnCode=0
set Rtl_Nightly_ReturnCode=0
set CashFlow_Update_ReturnCode=0
set WeeklyRtlSalesForecast_ReturnCode=0
set WeeklyRtlSalesActual_ReturnCode=0
set WeeklyRtlSalesBudget_ReturnCode=0
set DailyRtlSalesActual_ReturnCode=0
set WeeklyStoreStatusUpdate_ReturnCode=0
set WeeklyStoreCompTypeUpdate_ReturnCode=0
set StorePollingData_ReturnCode=0
set SalesDailyUpdate_ReturnCode=0
set CapexUpdate_ReturnCode=0
set SalesCubeUpdate_ReturnCode=0
set RetailLtmUpdate_ReturnCode=0
set FinancialLtmUpdate_ReturnCode=0
set RetailWeeklyTargetLoad_ReturnCode=0

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

::
:: How to run the PAS - FIN Test Job from the ETL Client
:: 
:: C:\Program Files\Jedox\Jedox Suite\tomcat\client\etlclient -p "[01-00]-PAS-FINANCIALS [Financials] Structure Update and Data Load" -j "Test Job" -o Testjob.log
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

:: Retail Weekly Sales Actuals
:PasWklyRtlSalesActual
:: There was NO error in the Financials Load Test Job
for /f "tokens=*" %%i in ('time /t') do set Time_now=%%i
for /f "tokens=*" %%i in ('date /t') do set Date_now=%%i
echo ***  Starting Weekly Retail Actuals Update Job Now: %Date_now% %Time_now%  ***  >>%LogFileName%
echo. >> %LogFileName%

IF %DebugFlag% EQU 0 (
  call .\etlclient -p "[10-00]-PAS-FINANCIALS [Retail Sales Weekly Metalicus] Store Update and Data Load" -j "01-00 Nightly - Retail Sales Weekly Cube Load" -c PrevYear=%PrevYear% CurrYear=%CurrYear% >>%LogFileName%
)
:: NOTE %ERRORLEVEL% is not returning the correct values everything is 0
:: Search the log for Warnings, Failed, Error and set the error level accordingly
type %LogFileName%|findstr /I /c:"Status: Failed"
IF %ERRORLEVEL% EQU 0 (
  SET WeeklyRtlSalesActual_ReturnCode=8
)
IF %WeeklyRtlSalesActual_ReturnCode% NEQ 0 goto PasWklyRtlSalesActualError

:: Now look for warnings
type %LogFileName%|findstr /I /c:"Completed with Warnings"
IF %ERRORLEVEL% EQU 0 (
  SET WeeklyRtlSalesActual_ReturnCode=7
)
IF %WeeklyRtlSalesActual_ReturnCode% NEQ 0 goto PasWklyRtlSalesActualError
:: The following has been commented out to enable budget updates on Monday
::IF %WeeklyRtlSalesActual_ReturnCode% EQU 0 goto PasWklyRtlSalesBudget

IF %WeeklyRtlSalesActual_ReturnCode% EQU 0 goto PasDailyRtlSalesActual

:PasWklyRtlSalesActualError
:: There was an error in the PAS - FIN Test Job
set EmailReturnCode=%WeeklyRtlSalesActual_ReturnCode%
for /f "tokens=*" %%i in ('time /t') do set Time_now=%%i
for /f "tokens=*" %%i in ('date /t') do set Date_now=%%i
echo ***  Error PAS-WeeklyRetailSalesActual ETL: %Date_now% %Time_now%  ***  >> %LogFileName%
echo ***  The email return code is: %EmailReturnCode%  ***  >> %LogFileName%
goto SendEmail


:: 2015-08-24 RKS Added Daily Sales Load
:: Retail Sales Weekly Forecast
:PasDailyRtlSalesActual
for /f "tokens=*" %%i in ('time /t') do set Time_now=%%i
for /f "tokens=*" %%i in ('date /t') do set Date_now=%%i
echo ***  Starting Daily Retail Actuals Update Job Now: %Date_now% %Time_now%  ***  >>%LogFileName%
echo. >> %LogFileName%

IF %DebugFlag% EQU 0 (
  call .\etlclient -p "[10-01]-PAS-FINANCIALS [Retail Sales Daily Metalicus] Store Update and Data Load" -j "01-00 Nightly - Retail Sales Daily  Cube Load">>%LogFileName%
)
:: NOTE %ERRORLEVEL% is not returning the correct values everything is 0
:: Search the log for Warnings, Failed, Error and set the error level accordingly
type %LogFileName%|findstr /I /c:"Status: Failed"
IF %ERRORLEVEL% EQU 0 (
  SET DailyRtlSalesActual_ReturnCode=16
)
IF %DailyRtlSalesActual_ReturnCode% NEQ 0 goto PasDailyRtlSalesActualError

:: Now look for warnings
type %LogFileName%|findstr /I /c:"Completed with Warnings"
IF %ERRORLEVEL% EQU 0 (
  SET DailyRtlSalesActual_ReturnCode=15
)
IF %DailyRtlSalesActual_ReturnCode% NEQ 0 goto PasDailyRtlSalesActualError
IF %DailyRtlSalesActual_ReturnCode% EQU 0 goto SendEmail

:PasDailyRtlSalesActualError
:: There was an error in the PAS - FIN Test Job
set EmailReturnCode=%DailyRtlSalesActual_ReturnCode%
for /f "tokens=*" %%i in ('time /t') do set Time_now=%%i
for /f "tokens=*" %%i in ('date /t') do set Date_now=%%i
echo ***  Error PAS-WeeklyRetailSalesForecast ETL: %Date_now% %Time_now%  ***  >> %LogFileName%
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
  set SubjectText="Results from Jedox Metalicus External Batch - All cube loads were successful"
)
IF %EmailReturnCode% EQU 1 (
  set SubjectText="Results from Jedox Metalicus External Batch - The Financials update completed with warnings and the Retail cube was not updated"
)
IF %EmailReturnCode% EQU 2 (
  set SubjectText="Results from Jedox Metalicus External Batch - The Financials update failed and the Retail cube was not updated"
)
IF %EmailReturnCode% EQU 3 (
  set SubjectText="Results from Jedox Metalicus External Batch - The Financials update was successful but the Retail cube completed with warnings"
)
IF %EmailReturnCode% EQU 4 (
  set SubjectText="Results from Jedox Metalicus External Batch - The Financials update was successful but the Retail cube update failed"
)
IF %EmailReturnCode% EQU 5 (
  set SubjectText="Results from Jedox Metalicus External Batch - The Financials & Retail update was successful but the Weekly Retail Sales cube Forecast update completed with warnings"
)
IF %EmailReturnCode% EQU 6 (
  set SubjectText="Results from Jedox Metalicus External Batch - The Financials & Retail update was successful but the Weekly Retail Sales cube Forecast update failed"
)
IF %EmailReturnCode% EQU 7 (
  set SubjectText="Results from Jedox Metalicus External Batch - The Financials & Retail update was successful but the Weekly Retail Sales cube Actual update completed with warnings"
)
IF %EmailReturnCode% EQU 8 (
  set SubjectText="Results from Jedox Metalicus External Batch - The Financials & Retail update was successful but the Weekly Retail Sales cube Actual update failed"
)
IF %EmailReturnCode% EQU 9 (
  set SubjectText="Results from Jedox Metalicus External Batch - The Financials, Retail & Weekly Retail Sales cube Actual were successful but the Weekly Retail Sales cube Budget update completed with warnings"
)
IF %EmailReturnCode% EQU 10 (
  set SubjectText="Results from Jedox Metalicus External Batch - The Financials, Retail & Weekly Retail Sales cube Actual were successful but the Weekly Retail Sales cube Budget update failed"
)
IF %EmailReturnCode% EQU 11 (
  set SubjectText="Results from Jedox Metalicus External Batch - The Financials, Retail & Weekly Retail Sales cube Actual were successful but the Weekly Comp Store Update completed with warnings"
)
IF %EmailReturnCode% EQU 12 (
  set SubjectText="Results from Jedox Metalicus External Batch - The Financials, Retail & Weekly Retail Sales cube Actual were successful but the Weekly Comp Store Update failed"
)
IF %EmailReturnCode% EQU 13 (
  set SubjectText="Results from Jedox Metalicus External Batch - The Financials, Retail & Weekly Retail Sales cube Actual were successful but the Weekly Store Status Update completed with warnings"
)
IF %EmailReturnCode% EQU 14 (
  set SubjectText="Results from Jedox Metalicus External Batch - The Financials, Retail & Weekly Retail Sales cube Actual were successful but the Weekly Store Status Update failed"
)
IF %EmailReturnCode% EQU 15 (
  set SubjectText="Results from Jedox Metalicus External Batch - The Financials, Retail & Weekly Retail Sales cube Actual & Forecast were successful but the Daily Retail Actual Update completed with warnings"
)
IF %EmailReturnCode% EQU 16 (
  set SubjectText="Results from Jedox Metalicus External Batch - The Financials, Retail & Weekly Retail Sales cube Actual & Forecast were successful but the Daily Retail Actual Update failed"
)
IF %EmailReturnCode% EQU 17 (
  set SubjectText="Results from Jedox Metalicus External Batch - The Financials, Retail ,Weekly & Daily Retail cubes Actual & Forecast were successful but the CAPEX Update completed with warnings"
)
IF %EmailReturnCode% EQU 18 (
  set SubjectText="  Results from Jedox Metalicus External Batch - The Financials, Retail ,Weekly & Daily Retail cubes & Forecast were successful but the CAPEX Update failed""
)
IF %EmailReturnCode% EQU 19 (
  set SubjectText="Results from Jedox Metalicus External Batch - The Financials, Retail ,Weekly & Daily Retail cubes and CAPEX cube Actual & Forecast were successful but the Sales Cube Update completed with warnings"
)
IF %EmailReturnCode% EQU 20 (
  set SubjectText="Results from Jedox Metalicus External Batch - The Financials, Retail ,Weekly & Daily Retail cubes and CAPEX cube Actual & Forecast were successful but the Sales Cube Update failed"
)
IF %EmailReturnCode% EQU 21 (
  set SubjectText="Results from Jedox Metalicus External Batch - The Financials, Retail Weekly & Daily Retail cubes CAPEX and Sales cube Actual & Forecast were successful but the Retail LTM Cube Update completed with warnings"
)
IF %EmailReturnCode% EQU 22 (
  set SubjectText="Results from Jedox Metalicus External Batch - The Financials, Retail ,Weekly & Daily Retail cubes, CAPEX and Sales cube Actual & Forecast were successful but the Retail LTM Cube Update failed"
)
IF %EmailReturnCode% EQU 23 (
  set SubjectText="Results from Jedox Metalicus External Batch - The Financials, Retail ,Weekly & Daily Retail cubes, CAPEX, Sales cube Actual & Forecast, and Retail LTM cubes were successful but the Financial LTM Cube Update completed with warnings"
)
IF %EmailReturnCode% EQU 24 (
  set SubjectText="Results from Jedox Metalicus External Batch - The Financials, Retail ,Weekly & Daily Retail cubes, CAPEX, Sales cube Actual & Forecast, and Retail LTM cubes were successful but the Financial LTM Cube Update failed"
)
IF %EmailReturnCode% EQU 25 (
  set SubjectText="Results from Jedox Metalicus External Batch - The Financials, Retail ,Weekly & Daily Retail cubes, CAPEX, Sales cube Actual & Forecast, Retail and Financial LTM cubes were successful but the Retail Weekly Target Load completed with warnings"
)
IF %EmailReturnCode% EQU 26 (
  set SubjectText="Results from Jedox Metalicus External Batch - The Financials, Retail ,Weekly & Daily Retail cubes, CAPEX, Sales cube Actual & Forecast, Retail and Financial LTM cubes were successful but the Retail Weekly Target Load failed"
)
IF %EmailReturnCode% EQU 27 (
  set SubjectText="Results from Jedox Metalicus External Batch - The Financials, Retail , were successful but the CashFlow Forecast_mmm Load completed with warnings"
)
IF %EmailReturnCode% EQU 28 (
  set SubjectText="Results from Jedox Metalicus External Batch - The Financials, Retail , were successful but the CashFlow Forecast_mmm Load failed"
)
IF %EmailReturnCode% EQU 94 (
  set SubjectText="Results from Jedox Metalicus External Batch - All cube loads were successful (Financials, Retail, Weekly & Daily Retail Sales, CAPEX, Sales, Retail LTM and Financial LTM) but the Store Polling Data Extract completed with warnings"
)
IF %EmailReturnCode% EQU 95 (
  set SubjectText="Results from Jedox Metalicus External Batch - All cube loads were successful (Financials, Retail, Weekly & Daily Retail Sales, CAPEX, Sales, Retail LTM and Financial LTM) but the Store Polling Data Extract failed"
)
IF %EmailReturnCode% EQU 96 (
  set SubjectText="Results from Jedox Metalicus External Batch - All cube loads (Financials, Retail, Weekly & Daily Retail Sales, CAPEX, Sales, Retail LTM and Financial LTM) and Store Polling Data Extract were successful but the SalesDaily update time extract completed with warnings"
)
IF %EmailReturnCode% EQU 97 (
  set SubjectText="Results from Jedox Metalicus External Batch - All cube loads (Financials, Retail, Weekly & Daily Retail Sales, CAPEX, Sales, Retail LTM and Financial LTM) and Store Polling Data Extract were successful but the Sales Daily Update time Extract failed"
)
IF %EmailReturnCode% EQU 98 (
  set SubjectText="Results from Jedox Metalicus External Batch - TThe cube updates (Financials, Retail, Weekly & Daily Retail Sales, CAPEX, Sales, Retail LTM and Financial LTM) and Store Polling and SalesDaily Upate Time Extracts were successful but database save completed with warnings"
)
IF %EmailReturnCode% EQU 99 (
  set SubjectText="Results from Jedox Metalicus External Batch - The cube updates (Financials, Retail, Weekly & Daily Retail Sales, CAPEX, Sales, Retail LTM and Financial LTM) and Store Polling and SalesDaily Upate Time Extracts were successful but database save failed"
)
IF %EmailReturnCode% EQU 999 (
  set SubjectText="Results from Jedox Metalicus External Batch - The Update of Paramters Failed! No Updates were Run! - Investigate NOW! "
)
:: Generate the command to send an email with the results
:: NOTE $body contains the body of the email message
:: This is in the text file EmailBody.txt in the client directory
echo $body = Get-Content -Path EmailBody.txt ^| Out-String >%OutFile%

:: The next line is for testing only
if %DebugFlag% EQU 1 (
  echo send-mailmessage -from ^"JedoxAdmin@pasco.com.au^" -to ^"RSnyder@pasco.com.au^" ,^"LMcInTyre@pasco.com.au^" -subject %SubjectText% -body $body -Attachment "%ret%" -priority High -dno onFailure -smtpServer mtwrly01.onepas.local >>%OutFile%
) else (
  echo send-mailmessage -from ^"JedoxAdmin@pasco.com.au^" -to ^"RSnyder@pasco.com.au^", ^"LMcInTyre@pasco.com.au^" -subject %SubjectText% -body $body -Attachment "%ret%" -priority High -dno onFailure -smtpServer mtwrly01.onepas.local >>%OutFile%
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
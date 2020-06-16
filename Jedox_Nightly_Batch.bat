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
set PasFin_ReturnCode=0
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
set WholesaleActualReturnCode=0
set FinalReturnCode=0

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

:: Dimension Cube load
:DimensionLoad
for /f "tokens=*" %%i in ('time /t') do set Time_now=%%i
for /f "tokens=*" %%i in ('date /t') do set Date_now=%%i
echo ***  Starting Financials Update Job Now: %Date_now% %Time_now%  ***  >>%LogFileName%
echo. >> %LogFileName%

IF %DebugFlag% EQU 0 (
  call .\etlclient -p "[00-00]-PAS-FINANCIALS Load All Dimensions" -j "Load Dimensions" >>%LogFileName%
)
:: NOTE %ERRORLEVEL% is not returning the correct values everything is 0
:: Search the log for Warnings, Failed, Error and set the error level accordingly
type %LogFileName%|findstr /I /c:"Status: Failed"
IF %ERRORLEVEL% EQU 0 (
  SET PasFin_ReturnCode=2
)
IF %PasFin_ReturnCode% NEQ 0 goto PasDimError

:: Now look for warnings  
type %LogFileName%|findstr /I /c:"Completed with Warnings"
IF %ERRORLEVEL% EQU 0 (
  SET PasFin_ReturnCode=1
)
IF %PasFin_ReturnCode% NEQ 0 goto PasDimError

:: If no errors with finance job found run the retail job
IF %PasFin_ReturnCode% EQU 0 goto FinCubLoad

:PasDimError
:: There was an error in the Financials Load Test Job
set EmailReturnCode=%PasFin_ReturnCode%
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
)
GOTO RunRtlJob

:: Retail cube load
:RunRtlJob
:: There was NO error in the Financials Load Test Job
for /f "tokens=*" %%i in ('time /t') do set Time_now=%%i
for /f "tokens=*" %%i in ('date /t') do set Date_now=%%i
echo ***  Starting RTL Update Job Now: %Date_now% %Time_now%  ***  >>%LogFileName%
echo. >> %LogFileName%

IF %DebugFlag% EQU 0 (
  call .\etlclient -p "[99-00] Administrative Tasks" -j "[01-07]-load [Cube]:Store Calendar and Store Calendar Week - Store Status Dates" >>%LogFileName%
  call .\etlclient -p "[02-00]-PAS-FINANCIALS [Retail] Store Update and Data Load" -j "Nightly" >>%LogFileName%
)
:: NOTE %ERRORLEVEL% is not returning the correct values everything is 0
:: Search the log for Warnings, Failed, Error and set the error level accordingly
GOTO UpdateParameters

::
:: Updating JedoxParameters table in PAS_DWH & Writing them to a file
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
  echo ***  Parameter Cube Successfully Updated ***  >>%LogFileName%
  echo. >> %LogFileName%
)

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

:: Capture Current Year In Financials Cube
:: Loading Actuals, Budget, Forecast
type ParameterCube.txt|findstr /B /c:"CurrYear " >CurrYearFIN.txt
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

:: Capture Current ETL Period
:: Loading Wholesale
type ParameterCube.txt|findstr /I /c:"Current Period ETL" >CurrentPeriod.txt
type CurrentPeriod.txt

For /F "tokens=1,2,3,4 delims=/ " %%A in ('type  CurrentPeriod.txt') do (
  Set CurrentPeriod=%%D
)
echo CurrentPeriod  is %CurrentPeriod% >>%LogFileName%

:: Retail Weekly Sales Actuals
:PasWklyRtlSalesActual
:: There was NO error in the Financials Load Test Job
for /f "tokens=*" %%i in ('time /t') do set Time_now=%%i
for /f "tokens=*" %%i in ('date /t') do set Date_now=%%i
echo ***  Starting Weekly Retail Actuals Update Job Now: %Date_now% %Time_now%  ***  >>%LogFileName%
echo. >> %LogFileName%

IF %DebugFlag% EQU 0 (
  call .\etlclient -p "[04-01]-PAS-FINANCIALS [Retail Sales Weekly] Store Update and Data Load" -j "01-00 Nightly - Retail Sales Weekly Cube Load" -c PrevYear=%PrevYear% CurrYear=%CurrYear% >>%LogFileName%
)
GOTO PasCapexLoad

:: 2015-09-11 RKS Added CAPEX Load
:PasCapexLoad
for /f "tokens=*" %%i in ('time /t') do set Time_now=%%i
for /f "tokens=*" %%i in ('date /t') do set Date_now=%%i
echo ***  Starting CAPEX Update Job Now: %Date_now% %Time_now%  ***  >>%LogFileName%
echo. >> %LogFileName%

IF %DebugFlag% EQU 0 (
  call .\etlclient -p "[06-00]-PAS-FINANCIALS [CAPEX]" -j "[01-00] CAPEX Actual And Forecast_MMM Load" -c CurrentYear=%CurrYearFIN% Forecast_MMM=%FinFcastVer% >>%LogFileName%
)
GOTO PasSalesCubeLoad

:: 2015-09-11 RKS Added Sales Cube Load
:PasSalesCubeLoad
for /f "tokens=*" %%i in ('time /t') do set Time_now=%%i
for /f "tokens=*" %%i in ('date /t') do set Date_now=%%i
echo ***  Starting Sales Cube Update Job Now: %Date_now% %Time_now%  ***  >>%LogFileName%
echo. >> %LogFileName%

IF %DebugFlag% EQU 0 (
  call .\etlclient -p "[07-00]-PAS-FINANCIALS [Sales]" -j "[01-00] Sales Actual And Forecast_MMM Load" -c CurrentYear=%CurrYearFIN% Forecast_MMM=%FinFcastVer% >>%LogFileName%
)
GOTO PasWholesaleActual

:PasWholesaleActual
for /f "tokens=*" %%i in ('time /t') do set Time_now=%%i
for /f "tokens=*" %%i in ('date /t') do set Date_now=%%i
echo ***  Starting Wholesale Actuals Update Job Now: %Date_now% %Time_now%  ***  >>%LogFileName%
echo. >> %LogFileName%

IF %DebugFlag% EQU 0 (
  call .\etlclient -p "[10-00]-PAS-FINANCIALS [Wholesale]" -j "Wholesale Nightly Load" >>%LogFileName%
)
GOTO PasDailyRtlSalesActual

:: 2015-08-24 RKS Added Daily Sales Load
:: Retail Sales Weekly Forecast
:PasDailyRtlSalesActual
for /f "tokens=*" %%i in ('time /t') do set Time_now=%%i
for /f "tokens=*" %%i in ('date /t') do set Date_now=%%i
echo ***  Starting Daily Retail Actuals Update Job Now: %Date_now% %Time_now%  ***  >>%LogFileName%
echo. >> %LogFileName%

IF %DebugFlag% EQU 0 (
  call .\etlclient -p "[04-03]-PAS-FINANCIALS [Retail Sales Daily] Store Update and Data Load" -j "01-00 Nightly - Retail Sales Daily  Cube Load">>%LogFileName%
)

:: 2015-09-28 RKS Added Retail LTM Cube Load
:RetailLtmCubeLoad
for /f "tokens=*" %%i in ('time /t') do set Time_now=%%i
for /f "tokens=*" %%i in ('date /t') do set Date_now=%%i
echo ***  Starting Retail LTM Cube Update Job Now: %Date_now% %Time_now%  ***  >>%LogFileName%
echo. >> %LogFileName%

IF %DebugFlag% EQU 0 (
  call .\etlclient -p "[03-00]-PAS-FINANCIALS [Retail LTM] LTM Period and Data Load" -j "[02-00]-load [Cube]: Retail LTM (All)" >>%LogFileName%
)

:: 2015-09-28 RKS Added Financial LTM Cube Load
:FinancialLtmCubeLoad
for /f "tokens=*" %%i in ('time /t') do set Time_now=%%i
for /f "tokens=*" %%i in ('date /t') do set Date_now=%%i
echo ***  Starting Financial LTM Cube Update Job Now: %Date_now% %Time_now%  ***  >>%LogFileName%
echo. >> %LogFileName%

IF %DebugFlag% EQU 0 (
  call .\etlclient -p "[03-01]-PAS-FINANCIALS [Financial LTM] LTM Period and Data Load" -j "[02-00]-load [Cube]: Financial LTM (All)" >>%LogFileName%
)
GOTO CashFlowUpdate

:: CashFlow cube load
:CashFlowUpdate
:: There was NO error in the Retail Load
for /f "tokens=*" %%i in ('time /t') do set Time_now=%%i
for /f "tokens=*" %%i in ('date /t') do set Date_now=%%i
echo ***  Starting Cash Flow Update Job Now: %Date_now% %Time_now%  ***  >>%LogFileName%
echo. >> %LogFileName%

IF %DebugFlag% EQU 0 (
  call .\etlclient -p "[08-00]-PAS-FINANCIALS [Cash Flow]" -j "[00-00-01]-CashFlow Update Act & Fcast" -c CurrYear=%CurrYearFIN% Forecast_MMM=%FinFcastVer% >>%LogFileName%
)
GOTO StockCubeUpdate

:: 2020-May-14 RKS Added Stock Cube Load
:StockCubeUpdate
for /f "tokens=*" %%i in ('time /t') do set Time_now=%%i
for /f "tokens=*" %%i in ('date /t') do set Date_now=%%i
echo ***  Stock Cube Update Job Now: %Date_now% %Time_now%  ***  >>%LogFileName%
echo. >> %LogFileName%

IF %DebugFlag% EQU 0 (
  call .\etlclient -p "[11-00] -PAS-FINANCIALS [Stock]" -j "Stock Cube Nightly Load" >>%LogFileName%
)
GOTO PasStatPandLCheck

:PasStatPandLCheck
:: There was NO error in the Sales Daily Update job
for /f "tokens=*" %%i in ('time /t') do set Time_now=%%i
for /f "tokens=*" %%i in ('date /t') do set Date_now=%%i
echo ***  Starting Stat P and L Check Job Now: %Date_now% %Time_now%  ***  >>%LogFileName%
echo. >> %LogFileName%

IF %DebugFlag% EQU 0 (
  call .\etlclient -p "[99-00] Administrative Tasks" -j "[01-14]-Stat PandL Check" >>%LogFileName%
)

:: Check to see the file exists and if the size is greater than 0
:: If it is then goto SendMailStatPandLCheck
:: Else Save the databases
:: Then save the databases anyway
for %%a in ("C:\Program Files\Jedox\Jedox Suite\tomcat\client\StatPandLCheck.txt") do (
set length=%%~za
)
if  %length% NEQ 0 (
  goto SendMailStatPandLCheck
) else (
  goto ReviewConcessionProfitCentreCheck
)

:: The following is used to send the email letting us know the wee has been updated
:SendMailStatPandLCheck
:: Send and email each Monday with the SalesDaily update times

set FilePath="C:\Program Files\Jedox\Jedox Suite\tomcat\client"

:: Remove the double quotes from the path
call :dequote %FilePath%
set FileName="%ret%\StatPandLCheck.txt"

:: OutFile is the name of the file that will contain the email commands executed by PowerShell
set OutFile=sendmailstatpandlcheck.ps1

:: Strip the quotes from the attached file names so they can be attached to the email
call :dequote %FileName%
set ParamFile=%ret%

call :dequote %LogFileName%
Set LogFile=%ret%

set SubjectText="Missing Accounts in Stat P&L Hierarchy"
:: Generate the command to send an email with the results
:: NOTE $body contains the body of the email message
:: This is in the text file EmailBody.txt in the client directory
echo $body = Get-Content -Path EmailBodyStatPandLCheck.txt ^| Out-String >%OutFile%

if %DebugFlag% EQU 1 (
  echo send-mailmessage -from ^"JedoxAdmin@pasco.com.au^" -to ^"RSnyder@pasco.com.au^" ,^"MLau@pasco.com.au^" -subject %SubjectText% -body $body -Attachment "%ParamFile%" -priority High -dno onFailure -smtpServer mtwrly01.onepas.local >>%OutFile%
)

if %DebugFlag% EQU 0 (
  echo send-mailmessage -from ^"JedoxAdmin@pasco.com.au^" -to ^"RSnyder@pasco.com.au^" ,^"MLau@pasco.com.au^" -subject %SubjectText% -body $body -Attachment "%ParamFile%" -priority High -dno onFailure -smtpServer mtwrly01.onepas.local >>%OutFile%
)
:: Send the email using the file sendmail.ps1 which has just been "written" above
Powershell.exe -executionpolicy remotesigned -File "C:\Program Files\Jedox\Jedox Suite\tomcat\client\sendmailstatpandlcheck.ps1"

:: See if this works - It has been exiting immediately after sending the email on line 686 above. See if this goto works.
:: IF it doesn't then the send email will end to be moved to after the save database
:: AND it will need to send the final results email as well, i.e. 2 emails one for the Stat P&L and the Batch results.
goto ReviewConcessionProfitCentreCheck

:ReviewConcessionProfitCentreCheck
:: There was NO error in the Sales Daily Update job
for /f "tokens=*" %%i in ('time /t') do set Time_now=%%i
for /f "tokens=*" %%i in ('date /t') do set Date_now=%%i
echo ***  Starting Review Concession ProfitCentre Check Job Now: %Date_now% %Time_now%  ***  >>%LogFileName%
echo. >> %LogFileName%

IF %DebugFlag% EQU 0 (
  call .\etlclient -p "[99-00] Administrative Tasks" -j "[01-15]-Review Concession Profit Centre Check" >>%LogFileName%
)

:: Check to see the file exists and if the size is greater than 0
:: If it is then goto SendMailReviewConcessionCheck
:: Else Save the databases
:: Then save the databases anyway
for %%a in ("C:\Program Files\Jedox\Jedox Suite\tomcat\client\ReviewConcessionProfitCentreCheck.txt") do (
set length=%%~za
)
if  %length% NEQ 0 (
  goto SendMailReviewConcessionCheck
) else (
  goto SendEmail
)

:: The following is used to send the email letting us know the wee has been updated
:SendMailReviewConcessionCheck
:: Send and email each Monday with the SalesDaily update times

set FilePath="C:\Program Files\Jedox\Jedox Suite\tomcat\client"

:: Remove the double quotes from the path
call :dequote %FilePath%
set FileName="%ret%\ReviewConcessionProfitCentreCheck.txt"

:: OutFile is the name of the file that will contain the email commands executed by PowerShell
set OutFile=sendmailreviewconcessioncheck.ps1

:: Strip the quotes from the attached file names so they can be attached to the email
call :dequote %FileName%
set ParamFile=%ret%

call :dequote %LogFileName%
Set LogFile=%ret%

set SubjectText="Missing Profit Centres in Review Concession Hierarchy"
:: Generate the command to send an email with the results
:: NOTE $body contains the body of the email message
:: This is in the text file EmailBody.txt in the client directory
echo $body = Get-Content -Path EmailBodyStatPandLCheck.txt ^| Out-String >%OutFile%

if %DebugFlag% EQU 1 (
  echo send-mailmessage -from ^"JedoxAdmin@pasco.com.au^" -to ^"RSnyder@pasco.com.au^" ,^"MLau@pasco.com.au^" -subject %SubjectText% -body $body -Attachment "%ParamFile%" -priority High -dno onFailure -smtpServer mtwrly01.onepas.local >>%OutFile%
)

if %DebugFlag% EQU 0 (
  echo send-mailmessage -from ^"JedoxAdmin@pasco.com.au^" -to ^"RSnyder@pasco.com.au^" ,^"MLau@pasco.com.au^" -subject %SubjectText% -body $body -Attachment "%ParamFile%" -priority High -dno onFailure -smtpServer mtwrly01.onepas.local >>%OutFile%
)
:: Send the email using the file sendmail.ps1 which has just been "written" above
Powershell.exe -executionpolicy remotesigned -File "C:\Program Files\Jedox\Jedox Suite\tomcat\client\sendmailreviewconcessioncheck.ps1"

:: See if this works - It has been exiting immediately after sending the email on line 686 above. See if this goto works.
:: IF it doesn't then the send email will end to be moved to after the save database
:: AND it will need to send the final results email as well, i.e. 2 emails one for the Stat P&L and the Batch results.
goto SaveDatabase

:SaveDatabase
::for /f "tokens=*" %%i in ('time /t') do set Time_now=%%i
::for /f "tokens=*" %%i in ('date /t') do set Date_now=%%i
::echo ***  Saving All Jedox Databases: %Date_now% %Time_now%  ***  >> %LogFileName%
::echo. >> %LogFileName%

::IF %DebugFlag% EQU 0 (
::  call .\etlclient -p "[01-00]-PAS-FINANCIALS [Financials] Structure Update and Data Load" -j "Database Save" >>%LogFileName%
::)
::type %LogFileName%|findstr /i /c:"Status: Failed"
::IF %ERRORLEVEL% EQU 0 (
::  set EmailReturnCode=99
::  goto SendEmail
::)
::type %LogFileName%|findstr /i /c:"Completed with warnings"
::  IF %ERRORLEVEL% EQU 0 (
::    set EmailReturnCode=98
::	goto SendEmail
::)

:SendEmail
:: We are here so there have been no errors
:: Perform a database save prior to sending the email

SET FinalReturnCode=0
SET EmailReturnCode=0

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
  set SubjectText="Results from Jedox Nightly Batch - All cube loads were successful"
)
IF %EmailReturnCode% EQU 1 (
  set SubjectText="Results from Jedox Nightly Batch - The update completed with warnings, however the cubes were updated"
)
IF %EmailReturnCode% EQU 2 (
  set SubjectText="Results from Jedox Nightly Batch - The update failed! No Updates were Run! - Investigate NOW!"
)
IF %EmailReturnCode% EQU 999 (
  set SubjectText="Results from Jedox Nightly Batch - The Update of Paramters Failed! No Updates were Run! - Investigate NOW! "
)
:: Generate the command to send an email with the results
:: NOTE $body contains the body of the email message
:: This is in the text file EmailBody.txt in the client directory
echo $body = Get-Content -Path EmailBody.txt ^| Out-String >%OutFile%

:: The next line is for testing only
if %DebugFlag% EQU 1 (
  echo send-mailmessage -from ^"JedoxAdmin@pasco.com.au^" -to ^"JedoxNightly@pasco.com.au^" -subject %SubjectText% -body $body -Attachment "%ret%" -priority High -dno onFailure -smtpServer mtwrly01.onepas.local >>%OutFile%
) else (
  echo send-mailmessage -from ^"JedoxAdmin@pasco.com.au^" -to ^"JedoxNightly@pasco.com.au^" -subject %SubjectText% -body $body -Attachment "%ret%" -priority High -dno onFailure -smtpServer mtwrly01.onepas.local >>%OutFile%
)

:: Send the email using the file sendmail.ps1 which has just been "written" above
Start /wait Powershell.exe -executionpolicy remotesigned -File "C:\Program Files\Jedox\Jedox Suite\tomcat\client\sendmail.ps1"
exit /B %EmailReturnCode%

:dequote
::This removes the double quotes from the string that was passed in.
setlocal
:: The tilde in the next line is the really important bit.
set thestring=%~1
endlocal&set ret=%thestring%
goto :eof
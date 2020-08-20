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
if exist StockBatch*.log (
  del StockBatch*.log
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
set LogFileName="%ret%\StockBatch-%DateN%_%timen%.log"

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
echo ***  Starting Dimension Update Job Now: %Date_now% %Time_now%  ***  >>%LogFileName%
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
IF %PasFin_ReturnCode% EQU 0 goto UpdateParameters

:PasDimError
:: There was an error in the Financials Load Test Job
set EmailReturnCode=%PasFin_ReturnCode%
for /f "tokens=*" %%i in ('time /t') do set Time_now=%%i
for /f "tokens=*" %%i in ('date /t') do set Date_now=%%i
echo ***  Error PAS-FIN ETL: %Date_now% %Time_now%  ***  >> %LogFileName%
echo ***  The email return code is: %EmailReturnCode%  ***  >> %LogFileName%
goto SendEmail

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

:: 2020-May-14 RKS Added Stock Cube Load
:StockCubeUpdate
for /f "tokens=*" %%i in ('time /t') do set Time_now=%%i
for /f "tokens=*" %%i in ('date /t') do set Date_now=%%i
echo ***  Stock Cube Update Job Now: %Date_now% %Time_now%  ***  >>%LogFileName%
echo. >> %LogFileName%

IF %DebugFlag% EQU 0 (
  call .\etlclient -p "[11-00] -PAS-FINANCIALS [Stock]" -j "Stock Cube Nightly Load" >>%LogFileName%
)
GOTO SendEmail


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
  set SubjectText="Results from Jedox Stock Update  Batch - Stock cube load were successful"
)
IF %EmailReturnCode% EQU 1 (
  set SubjectText="Results from Jedox Stock Update Batch - The update completed with warnings, however the Stock cube was updated"
)
IF %EmailReturnCode% EQU 2 (
  set SubjectText="Results from Jedox Stock Update  Batch - The update failed! No Updates were Run! - Investigate NOW!"
)
IF %EmailReturnCode% EQU 999 (
  set SubjectText="Results from Jedox Stock Update  Batch - The Update of Paramters Failed! No Updates were Run! - Investigate NOW! "
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
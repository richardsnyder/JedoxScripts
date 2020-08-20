:: ********************************
:: Batch script to run nightly ETL jobs via the Jedox ETL Client
:: ********************************

:: ******* Change Log *******************
:: 20200422 RKS Set variables used by Retail Sales Daily load job.
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
if exist RetailDailyBatch*.log (
  del RetailDailyBatch*.log
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
set LogFileName="%ret%\RetailDailyBatch-%DateN%_%timen%.log"

echo Path %LogFilePath%  > %LogFileName%
echo Name %LogFileName%  >> %LogFileName%

::@echo off
:: Create/set variables for error checks
:: ====== Subroutine Codes ==============
set DailyRtlSalesActual_ReturnCode=0


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
type ParameterCube.txt|findstr /I /c:"Retail ETL Forecast" >Forecast_MMM.txt
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
  call .\etlclient -p "[04-03]-PAS-FINANCIALS [Retail Sales Daily] Store Update and Data Load" -j "01-00 Nightly - Retail Sales Daily  Cube Load" >>%LogFileName%
)
:: NOTE %ERRORLEVEL% is not returning the correct values everything is 0
:: Search the log for Warnings, Failed, Error and set the error level accordingly
type %LogFileName%|findstr /I /c:"Status: Failed"
IF %ERRORLEVEL% EQU 0 (
  SET DailyRtlSalesActual_ReturnCode=1
)
IF %DailyRtlSalesActual_ReturnCode% NEQ 0 goto PasDailyRtlSalesActualError

:: Now look for warnings
type %LogFileName%|findstr /I /c:"Completed with Warnings"
IF %ERRORLEVEL% EQU 0 (
  SET DailyRtlSalesActual_ReturnCode=2
)
IF %DailyRtlSalesActual_ReturnCode% NEQ 0 goto PasDailyRtlSalesActualError
:: The following has been commented out to enable budget updates on Monday
::IF %DailyRtlSalesActual_ReturnCode% EQU 0 goto PasWklyRtlSalesBudget

IF %DailyRtlSalesActual_ReturnCode% EQU 0 goto SendEmail

:PasDailyRtlSalesActualError
:: There was an error in the PAS - FIN Test Job
set EmailReturnCode=%DailyRtlSalesActual_ReturnCode%
for /f "tokens=*" %%i in ('time /t') do set Time_now=%%i
for /f "tokens=*" %%i in ('date /t') do set Date_now=%%i
echo ***  Error PAS-WeeklyRetailSalesActual ETL: %Date_now% %Time_now%  ***  >> %LogFileName%
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
  set SubjectText="Jedox Retail Sales Daily Cube Update was Successful"
)
IF %EmailReturnCode% EQU 1 (
  set SubjectText="Jedox Retail Sales Daily Cube Update Completed with Warnings"
)
IF %EmailReturnCode% EQU 2 (
  set SubjectText="Jedox Retail Sales Daily Cube Update Failed"
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
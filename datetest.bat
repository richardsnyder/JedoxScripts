@echo off
set CL_PARAMETER=%1
if "x%1x" == "xx" goto displayUsage
if %1 == dowstuff goto dowstuff
if %1 == nightly goto nightly
echo Command line parameter passed is [%CL_PARAMETER%]
echo.

:dowstuff
@For /F "tokens=1,2,3,4 delims=/ " %%A in ('Date /t') do @( 
  Set DOW=%%A
  Set Day=%%B
  Set Month=%%C
  Set Year=%%D
)
@echo DOW = %dow%
@echo DAY = %Day%
@echo Month = %Month%
@echo Year = %Year%

@set WeeklyRtlSalesActual_ReturnCode=0

@set PasWklyRtlSalesBudget=Going to PasWklyRtlSalesBudget
::@echo %PasWklyRtlSalesBudget%
    
@set PasStorePollingData=Going to PasStorePollingData
::@echo %PasStorePollingData%
    
@IF %WeeklyRtlSalesActual_ReturnCode% EQU 0 (
  @IF %DOW% EQU Tue ( 
    @echo %PasWklyRtlSalesBudget%
    goto end
  ) ELSE (
  @echo %PasStorePollingData%
  goto end
  )
)
:displayUsage
echo.
echo Usage: JedoxBatch.bat nightly/fin/retail/retailweek/test
goto end

:nightly
echo You are in nightly

@For %%G in Jobs.bat do @(
  call :subroutine %%G
)
goto end 

:subroutine
::call :dequote %1
::@echo %ret%
@echo %1
goto :eof

:end

:dequote
::This removes the double quotes from the string that was passed in.
setlocal
rem The tilde in the next line is the really important bit.
set thestring=%~1
endlocal&set ret=%thestring%
Goto :EOF



::  call .\etlclient -p "[99-00] Administrative Tasks" -j "[01-11]-Store Attribute Update" >>%LogFileName%
::  call .\etlclient -p "[01-00]-PAS-FINANCIALS [Financials] Structure Update and Data Load" -j "Test Job" >>%LogFileName%
::  call .\etlclient -p "[02-00]-PAS-FINANCIALS [Retail] Store Update and Data Load" -j "Nightly" >>%LogFileName%
::  call .\etlclient -p "[04-01]-PAS-FINANCIALS [Retail Sales Weekly] Store Update and Data Load" -j "02-00-01 Nightly - Retail Sales Weekly - Forecast (Only) Load" -c Forecast_MMM=%FcastVer% CurrYear=%CurrYear% >>%LogFileName%
::  call .\etlclient -p "[04-01]-PAS-FINANCIALS [Retail Sales Weekly] Store Update and Data Load" -j "01-00 Nightly - Retail Sales Weekly Cube Load" -c PrevYear=%PrevYear% CurrYear=%CurrYear% >>%LogFileName%
::  call .\etlclient -p "[99-00] Administrative Tasks" -j "[01-09]-Load AP21 Store Poll Data" >>%LogFileName%
::  call .\etlclient -p "[99-00] Administrative Tasks" -j "[01-10]-Update Status Table with SalesDaily Load Dates" >>%LogFileName%
  
  
  
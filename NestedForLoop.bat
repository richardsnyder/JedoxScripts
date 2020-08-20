ECHO OFF

type ParameterCube.txt|findstr /I /c:"Retail Forecast Version" >Forecast_MMM.txt
type Forecast_MMM.txt

For /F "tokens=1,2,3,4 delims=/ " %%A in ('type  Forecast_MMM.txt') do (
  Set FcastVer=%%D
)
echo FcastVer is %FcastVer%

type ParameterCube.txt|findstr /I /c:"CurrYear" >CurrYear.txt
type CurrYear.txt

For /F "tokens=1,2,3,4 delims=/ " %%A in ('type  CurrYear.txt') do (
  Set CurrYear=%%B
)
echo CurrYear is %CurrYear%

call .\etlclient -p "[04-01]-PAS-FINANCIALS [Retail Sales Weekly] Store Update and Data Load" -j "02-00 Manual - Retail Sales Weekly - Forecast Load" -c Forecast_MMM=%FcastVer% CurrYear=%CurrYear%

REM FOR %%A IN (""[Param1" "Param 2 with Space" -j "Param 3"") DO ECHO %%A
REM ""[01-00]-PAS-FINANCIALS [Financials] Structure Update and Data Load" -j "Test Job"") DO ECHO %%A

   REM "[02-00]-PAS-FINANCIALS [Retail] Store Update and Data Load" -j "Nightly" 
   REM "[04-01]-PAS-FINANCIALS [Weekly Retail Sales] Store Update and Data Load" -j "02-00 Manual - Weekly Retail Sales - Forecast Load" 
   REM "[04-01]-PAS-FINANCIALS [Weekly Retail Sales] Store Update and Data Load" -j "01-00 Nightly - Weekly Retail Sales Cube Load"
   REM "[04-01]-PAS-FINANCIALS [Weekly Retail Sales] Store Update and Data Load" -j "04-01 Load AP21 Store Poll Data" 
   REM "[04-01]-PAS-FINANCIALS [Weekly Retail Sales] Store Update and Data Load" -j "05-01 Update Status Table with SalesDaily Load Dates"
   REM "[01-00]-PAS-FINANCIALS [Financials] Structure Update and Data Load" -j "Database Save") DO ECHO %%A
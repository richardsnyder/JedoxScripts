echo %0 >D:\Jedox\UpdateDailySplitsFinancialForecastError.txt
echo sqlcmd -S MTWSQL06 -Q "exec msdb.dbo.sp_start_job 'Jedox - Daily Splits Financial Forecast'"  >>D:\Jedox\UpdateDailySplitsFinancialForecastError.txt
sqlcmd -S MTWSQL06 -Q "exec msdb.dbo.sp_start_job 'Jedox - Daily Splits Financial Forecast'"  >>D:\Jedox\UpdateDailySplitsFinancialForecastError.txt
echo %0 >D:\Jedox\UpdateDailySplitsFinancialBudgetError.txt
echo sqlcmd -S MTWSQL06 -Q "exec msdb.dbo.sp_start_job 'Jedox - Daily Splits Financial Budget'"  >>D:\Jedox\UpdateDailySplitsFinancialBudgetError.txt
sqlcmd -S MTWSQL06 -Q "exec msdb.dbo.sp_start_job 'Jedox - Daily Splits Financial Budget'"  >>D:\Jedox\UpdateDailySplitsFinancialBudgetError.txt
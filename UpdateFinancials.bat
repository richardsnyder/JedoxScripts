echo %0 >D:\Jedox\UpdateFinancialsError.txt
rem echo osql -D MTWSQL02 -E -Q "exec msdb.dbo.sp_start_job 'Load Store Targets'" >>C:\Error.txt
rem osql -D MTWSQL02 -E -Q "exec msdb.dbo.sp_start_job 'Load Store Targets'" >>C:\Error.txt
REM echo sqlcmd -S MTWSQL04 -U pasfin -P Fin1group -Q "exec msdb.dbo.sp_start_job 'Update GL in Data Warehouse and Jedox'"  >>D:\Jedox\UpdateFinancialsError.txt
REM sqlcmd -S MTWSQL04 -U pasfin -P Fin1group -Q "exec msdb.dbo.sp_start_job 'Update GL in Data Warehouse and Jedox'"  >>D:\Jedox\UpdateFinancialsError.txt
echo sqlcmd -S MTWSQL06 -Q "exec msdb.dbo.sp_start_job 'Data Warehouse - Financials Update'"  >>D:\Jedox\UpdateFinancialsError.txt
sqlcmd -S MTWSQL06 -Q "exec msdb.dbo.sp_start_job 'Data Warehouse - Financials Update'"  >>D:\Jedox\UpdateFinancialsError.txt
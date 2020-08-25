echo %0 >D:\Jedox\LoadTargetsError.txt
rem echo osql -D MTWSQL02 -E -Q "exec msdb.dbo.sp_start_job 'Load Store Targets'" >>C:\Error.txt
rem osql -D MTWSQL02 -E -Q "exec msdb.dbo.sp_start_job 'Load Store Targets'" >>C:\Error.txt
rem echo sqlcmd -S MTWSQL04 -U pasfin -P Fin1group -Q "exec msdb.dbo.sp_start_job 'Load Store Targets'"  >>D:\Jedox\LoadTargetsError.txt
rem sqlcmd -S MTWSQL04 -U pasfin -P Fin1group -Q "exec msdb.dbo.sp_start_job 'Load Store Targets'"  >>D:\Jedox\LoadTargetsError.txt
echo sqlcmd -S MTWSQL06 "exec msdb.dbo.sp_start_job 'Data Warehouse - Store Target Update'"  >>D:\Jedox\LoadTargetsError.txt
sqlcmd -S MTWSQL06 -Q "exec msdb.dbo.sp_start_job 'Data Warehouse - Store Target Update'"  >>D:\Jedox\LoadTargetsError.txt
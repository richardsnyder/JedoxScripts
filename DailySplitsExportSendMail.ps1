send-mailmessage -from "JedoxAdmin@pasco.com.au" -to "JedoxNightly@pasco.com.au", "pasaccountants@pasco.com.au" -subject "Step 1 Jedox Daily Spits Export  Batch - Daily Splits Export Successful" -body "Daily splits have been exported to the data warehouse. Log files are attached." -Attachment "C:\Program Files\Jedox\Jedox Suite\tomcat\client\DailySplitsExportDailySplitsBatch-14-10-2020_12-23-50.log" -priority High -dno onFailure -smtpServer mtwrly01.onepas.local 
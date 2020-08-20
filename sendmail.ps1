$body = Get-Content -Path EmailBody.txt | Out-String 
send-mailmessage -from "JedoxAdmin@pasco.com.au" -to "JedoxNightly@pasco.com.au" -subject "Results from Jedox Stock Update  Batch - Stock cube load were successful" -body $body -Attachment "C:\Program Files\Jedox\Jedox Suite\tomcat\client\StockBatch-20-08-2020_5-16-36.log" -priority High -dno onFailure -smtpServer mtwrly01.onepas.local 

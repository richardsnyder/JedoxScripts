$body = Get-Content -Path EmailBodyPayrollUpdate.txt | Out-String 
send-mailmessage -from "JedoxAdmin@pasco.com.au" -to "RSnyder@pasco.com.au" ,"MLau@pasco.com.au" -subject "Jedox Payroll Cube Update was Successful" -body $body -Attachment "C:\Program Files\Jedox\Jedox Suite\tomcat\client\PayrollBatch-20-08-2020_6-01-17.log" -priority High -dno onFailure -smtpServer mtwrly01.onepas.local 

set-executionpolicy remotesigned

Write-Host "Messages are being logged in C:\Utils\StopLog.txt"

$StopLog ="C:\Utils\StopLog.txt"

If (Test-Path $StopLog){
	Remove-Item $StopLog
}

 Function LogWrite
{
   Param ([string]$logstring)

   Add-content $StopLog -value $logstring
}

$aryServices = "JedoxSuiteHttpdService", "JedoxSuiteCoreService", "JedoxSuiteTomcatService", "JedoxSuiteMDXInterpreter", "JedoxSuiteMolapService"

foreach ($strService in $aryServices)
{
  $objWmiService = Get-Service -Name "$strService"
  if( $objWMIService.CanStop -and $objWMIService.Status -eq "Running" )
   { 
    LogWrite "stopping the $strService service now ..." 
    if("$strService" -eq "JedoxSuiteMolapService")
    {
      Stop-Service -Force "$strService"
    }
    else
    {
      Stop-Service "$strService"
    }
   }
  ELSE
   { 
    LogWrite "$strService is not running"
   }
 }
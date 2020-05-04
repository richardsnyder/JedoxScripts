set-executionpolicy remotesigned

Write-Host "Messages are being logged in C:\Utils\StartLog.txt"

$StartLog ="C:\Utils\StartLog.txt"

If (Test-Path $StartLog){
	Remove-Item $StartLog
}

 Function LogWrite
{
   Param ([string]$logstring)

   Add-content $StartLog -value $logstring
}

$aryServices = "JedoxSuiteMolapService", "JedoxSuiteTomcatService", "JedoxSuiteCoreService", "JedoxSuiteHttpdService", "JedoxSuiteMDXInterpreter"

#$aryServices = "JedoxSuiteMolapService"

foreach ($strService in $aryServices)
{
  $objWmiService = Get-Service -Name "$strService"
  if ( $objWmiService.Status -ne "Running" )
  {
    LogWrite "Starting the $strService service now ..."
    Start-Service "$strService"
  }
  else
  {
    LogWrite -ForegroundColor red "The" $strService "service is already running"
  }
 }
 
 # Remove all the *.archived files as they are created on startup
LogWrite "Removing *.archived files..."

get-childitem d:\jedox\data -include *.archive -recurse | foreach ($_)  {
  LogWrite "Removing... $_"
  Remove-Item $_.fullname
  }
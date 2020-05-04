param(
  [string] $JobType = "",
  [string] $JedoxJobFIle = ""
)

# set-executionpolicy remotesigned

$DebugFlag = 0

$ScriptDirectory = "/Users/rks/SynologyDrive/Development/PowerShell/JedoxScripts/"

$JobsToRun = $ScriptDirectory + "/" + $JedoxJobFIle

$LogDirectory = "/Users/rks/SynologyDrive/Development/PowerShell/JedoxScripts/log/"

$CurrentDate = get-date -format "yyyyMMddHHmm"

$LogFile = $LogDirectory + $JobType + $CurrentDate + ".log"

Write-Host "Messages are being logged in " + $LogFile

# Function for logging
Function LogWrite
{
   Param ([string]$logstring)

   Add-content $LogFile -value $logstring
}

LogWrite "Removing any logs for $JobType"

# Remove any previous log files
get-item $LogDirectory*$JobType*.log| remove-item

$CurrentTime =get-date -format "dd-MMM-yyyy:HHmm.ss"
LogWrite "Starting Jedox Jobs ---> " + $CurentTime

Get-Content $JobsToRun | ForEach-Object {
  $CurrentTime =get-date -format "dd-MMM-yyyy:HHmm.ss"
  LogWrite "Starting Job $_ at $CurrentTime" 
  Start-Sleep -s 2
  $ReturnCode = $?
  $CurrentTime = get-date -format "dd-MMM-yyyy:HHmm.ss"
  if ($ReturnCode -eq $true) {LogWrite "Job $_ Completed Successfully at $CurrentTime with returncode $ReturnCode"}
  else {LogWrite "Job $_ Did Not Complete Successfully at $CurrentTime with returncode $ReturnCode"}
}


param($Context)


$DurableRetryOptions = @{
  FirstRetryInterval  = (New-TimeSpan -Seconds 5)
  MaxNumberOfAttempts = 3
  BackoffCoefficient  = 2
}
$RetryOptions = New-DurableRetryOptions @DurableRetryOptions
Write-LogMessage -API 'NCApp' -tenant $tenant -message "Started N-Central App Cache" -sev info

$Batch = (Invoke-ActivityFunction -FunctionName 'NCApp_GetQueue' -Input 'LetsGo')
$ParallelTasks = foreach ($Item in $Batch) {
  Invoke-DurableActivity -FunctionName 'NCApp_Cache' -Input $item -RetryOptions $RetryOptions
}

$TableParams = Get-CippTable -tablename 'cacheNCdeviceapps'
$TableParams.Entity = Wait-ActivityFunction -Task $ParallelTasks
$TableParams.Force = $true
$TableParams = $TableParams | Where-Object -Property RowKey -NE "" | ConvertTo-Json -Compress
if ($TableParams) {
  try {
    Invoke-ActivityFunction -FunctionName 'Activity_AddOrUpdateTableRows' -Input $TableParams
  }
  catch {
    Write-LogMessage -API 'NCApp' -tenant $tenant -message "N-Central App Cache could not write to table: $($_.Exception.Message)" -sev error
  }
}
else {
  Write-LogMessage -API 'NCApp' -tenant $tenant -message "Tried writing empty values to N-Centrol App Cache" -sev Info
}
Write-LogMessage -API 'NCApp' -tenant $tenant -message 'N-Centrol App Cache has Finished' -sev Info

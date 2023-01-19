using namespace System.Net

param($Request, $TriggerMetadata)

$InstanceId = Start-NewOrchestration -FunctionName 'NCApp_Orchestration'
Write-Host "Started orchestration with ID = '$InstanceId'"
$Orchestrator = New-OrchestrationCheckStatusResponse -Request $Timer -InstanceId $InstanceId
Write-LogMessage -API 'NCApp' -message 'Starting N-Central App Cache' -sev Info
$Results = [pscustomobject]@{'Results' = 'Starting N-Central App Cache' }

Write-Host ($Orchestrator | ConvertTo-Json)


Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = $results
    })
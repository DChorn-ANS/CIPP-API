param($Timer)

if ($env:DEV_SKIP_NCAPP_TIMER) { 
    Write-Host 'Skipping NCApp timer'
    exit 0 
}

try {
        $InstanceId = Start-NewOrchestration -FunctionName 'BestPracticeAnalyser_Orchestration'
        Write-Host "Started orchestration with ID = '$InstanceId'"
        $Orchestrator = New-OrchestrationCheckStatusResponse -Request $Timer -InstanceId $InstanceId
        Write-LogMessage -API 'NCAppCache' -message 'Started retrieving N-Central App Cache' -sev Info
        $Results = [pscustomobject]@{'Results' = 'Started running analysis' }
    Write-Host ($Orchestrator | ConvertTo-Json)
}
catch { Write-Host "NCApp_OrchestratorStarterTimer Exception $($_.Exception.Message)" }

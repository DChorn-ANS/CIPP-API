using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

$APIName = $TriggerMetadata.FunctionName
Write-LogMessage -user $request.headers.'x-ms-client-principal' -API $APINAME  -message "Accessed this API" -Sev "Debug"
$Tenantfilter = $request.Query.tenantfilter

try {
    $eligbleschedules = New-GraphGetRequest -uri "https://graph.microsoft.com/beta/roleManagement/directory/roleEligibilitySchedules?`$expand=roleDefinition,principal" -tenantid $Tenantfilter
    $EligibleSchedulesSplat = @()
foreach ($EligibleSchedule in $eligbleschedules){
$object = [PSCustomObject]@{
    principalId = $EligibleSchedule.principalID
    roleDefinitionId = $EligibleSchedule.roleDefinitionId
    roleDisplayName = $EligibleSchedule.roleDefinition.displayName
    accountEnabled = $EligibleSchedule.principal.accountEnabled
    displayName = $EligibleSchedule.principal.displayName
    userPrincipalName = $EligibleSchedule.principal.userPrincipalName
    status = $EligibleSchedule.status
    startDateTime = $EligibleSchedule.scheduleInfo.startDateTime
    expiration = $EligibleSchedule.scheduleInfo.expiration.endDateTime
 }
    $EligibleSchedulesSplat += $object
    }
    $StatusCode = [HttpStatusCode]::OK
}
catch {
    $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
    $StatusCode = [HttpStatusCode]::Forbidden
    $EligibleSchedulesSplat = $ErrorMessage
}

#Display Results
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $StatusCode
    Body       = $EligibleSchedulesSplat
}) -Clobber
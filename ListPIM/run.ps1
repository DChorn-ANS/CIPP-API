using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

$APIName = $TriggerMetadata.FunctionName
Write-LogMessage -user $request.headers.'x-ms-client-principal' -API $APINAME  -message "Accessed this API" -Sev "Debug"
$Tenantfilter = $request.Query.tenantfilter

try {
    $eligbleschedules = New-GraphGetRequest -uri "https://graph.microsoft.com/beta/roleManagement/directory/roleEligibilitySchedules?`$expand=roleDefinition,principal" -tenantid $Tenantfilter
    $Assignmentschedules = New-GraphGetRequest -uri "https://graph.microsoft.com/beta/roleManagement/directory/roleAssignmentSchedules?`$expand=roleDefinition,principal" -tenantid $Tenantfilter
    $SchedulesSplat = @()
foreach ($EligibleSchedule in $eligbleschedules){
    $Expiration = if($null -eq $EligibleSchedule.scheduleInfo.expiration.endDateTime){"Permanent"}else{Get-Date $EligibleSchedule.scheduleInfo.expiration.endDateTime -format g}
$object = [PSCustomObject]@{
    principalId = $EligibleSchedule.principalID
    roleDefinitionId = $EligibleSchedule.roleDefinitionId
    roleDisplayName = $EligibleSchedule.roleDefinition.displayName
    accountEnabled = $EligibleSchedule.principal.accountEnabled
    displayName = $EligibleSchedule.principal.displayName
    userPrincipalName = $EligibleSchedule.principal.userPrincipalName
    status = $EligibleSchedule.status
    assignment = "Eligible"
    startDateTime = get-date $EligibleSchedule.scheduleInfo.startDateTime -format g
    expiration = $Expiration
 }
    $SchedulesSplat += $object
    }
    foreach ($Assignmentschedule in $Assignmentschedules){
        $Expiration = if($null -eq $Assignmentschedule.scheduleInfo.expiration.endDateTime){"Permanent"}else{Get-Date $Assignmentschedule.scheduleInfo.expiration.endDateTime -format g}
        $object = [PSCustomObject]@{
            principalId = $Assignmentschedule.principalID
            roleDefinitionId = $Assignmentschedule.roleDefinitionId
            roleDisplayName = $Assignmentschedule.roleDefinition.displayName
            accountEnabled = $Assignmentschedule.principal.accountEnabled
            displayName = $Assignmentschedule.principal.displayName
            userPrincipalName = $Assignmentschedule.principal.userPrincipalName
            status = $Assignmentschedule.status
            assignment = "Active"
            startDateTime =  get-date $Assignmentschedule.scheduleInfo.startDateTime -format g
            expiration = $Expiration
         }
            $SchedulesSplat += $object
        }
    $StatusCode = [HttpStatusCode]::OK
}
catch {
    $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
    $StatusCode = [HttpStatusCode]::Forbidden
    $SchedulesSplat = $ErrorMessage
}

#Display Results
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $StatusCode
    Body       = $SchedulesSplat
}) -Clobber
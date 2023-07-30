using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

$APIName = $TriggerMetadata.FunctionName
Write-LogMessage -user $request.headers.'x-ms-client-principal' -API $APINAME  -message "Accessed this API" -Sev "Debug"
$Tenantfilter = $request.Query.tenantfilter
$Function = $request.Query.Function

$RuleState = New-Object System.Collections.ArrayList

try {
    $Policies = New-ExoRequest -tenantid $Tenantfilter -cmdlet "Get-$($Function)Policy" | Select-Object * -ExcludeProperty *odata*, *data.type*
    New-ExoRequest -tenantid $Tenantfilter -cmdlet "Get-$($Function)Rule" | Select-Object * -ExcludeProperty *odata*, *data.type* | ForEach-Object { $RuleState.add($_) }
    New-ExoRequest -tenantid $Tenantfilter -cmdlet "Get-ATPProtectionPolicyRule" | Select-Object * -ExcludeProperty *odata*, *data.type* | ForEach-Object { $RuleState.add($_) } -ErrorAction SilentlyContinue
    New-ExoRequest -tenantid $Tenantfilter -cmdlet "Get-ATPBuiltInProtectionRule" | Select-Object * -ExcludeProperty *odata*, *data.type* | ForEach-Object { $RuleState.add($_) }
    $Policies = $Policies | Where-Object -FilterScript { $_.name -in $RuleState.name -or $_.IsDefault -eq $true -or $_.IsBuiltInProtection -eq $true }
    
    $GraphRequest = $Policies | Select-Object *,
    @{l = 'ruleState'; e = { if ($_.isDefault -eq $true -or $_.isBuiltInProtection -eq $true) { "Default" }else { ($RuleState | Where-Object name -EQ $_.name).State } } },
    @{l = 'rulePrio'; e = { if ($_.isDefault -eq $true -or $_.isBuiltInProtection -eq $true) { "Lowest" }elseif ($_.name -eq "Standard Preset Security Policy") { -1 }elseif ($_.name -eq "Strict Preset Security Policy") { -2 }elseif ($_.isDefault -eq $true -or $_.isBuiltInProtection -eq $true) { "default" }else { ($RuleState | Where-Object name -EQ $_.name).Priority } } },
    @{l = 'ruleInclAll'; e = { "-Included Users-<br />" + (($RuleState | Where-Object name -EQ $_.name).SentTo -join "<br />") + "<br />-Included Groups-<br />" + (($RuleState | Where-Object name -EQ $_.name).SentToMemberOf -join "<br />") + "<br />-Included Domains-<br />" + (($RuleState | Where-Object name -EQ $_.name).RecipientDomainIs -join "<br />") } },
    @{l = 'ruleInclAllCount'; e = { if ($_.isDefault -eq $true -or $_.isBuiltInProtection -eq $true) { "default" }else { (($RuleState | Where-Object name -EQ $_.name).SentTo + ($RuleState | Where-Object name -EQ $_.name).SentToMemberOf + ($RuleState | Where-Object name -EQ $_.name).RecipientDomainIs) | Measure-Object | Select-Object -ExpandProperty Count } } },
    @{l = 'ruleExclAll'; e = { "-Included Users-<br />" + (($RuleState | Where-Object name -EQ $_.name).ExceptIfSentTo -join "<br />") + "<br />-Included Groups-<br />" + (($RuleState | Where-Object name -EQ $_.name).ExceptIfSentToMemberOf -join "<br />") + "<br />-Included Domains-<br />" + (($RuleState | Where-Object name -EQ $_.name).ExceptIfRecipientDomainIs -join "<br />") } },
    @{l = 'ruleExclAllCount'; e = { (($RuleState | Where-Object name -EQ $_.name).ExceptIfSentTo + ($RuleState | Where-Object name -EQ $_.name).ExceptIfSentToMemberOf + ($RuleState | Where-Object name -EQ $_.name).ExceptIfRecipientDomainIs) | Measure-Object | Select-Object -ExpandProperty Count } },
    @{l = 'ruleOutboundInclAll'; e = { "-Included Users-<br />" + (($RuleState | Where-Object name -EQ $_.name).From -join "<br />") + "<br />-Included Groups-<br />" + (($RuleState | Where-Object name -EQ $_.name).FromMemberOf -join "<br />") + "<br />-Included Domains-<br />" + (($RuleState | Where-Object name -EQ $_.name).SenderDomainIs -join "<br />") } },
    @{l = 'ruleOutboundInclAllCount'; e = { if ($_.isDefault -eq $true -or $_.isBuiltInProtection -eq $true) { "default" }else { (($RuleState | Where-Object name -EQ $_.name).From + ($RuleState | Where-Object name -EQ $_.name).FromMemberOf + ($RuleState | Where-Object name -EQ $_.name).SenderDomainIs) | Measure-Object | Select-Object -ExpandProperty Count } } },
    @{l = 'ruleOutboundExclAll'; e = { "-Included Users-<br />" + (($RuleState | Where-Object name -EQ $_.name).ExceptIfFrom -join "<br />") + "<br />-Included Groups-<br />" + (($RuleState | Where-Object name -EQ $_.name).ExceptIfFromMemberOf -join "<br />") + "<br />-Included Domains-<br />" + (($RuleState | Where-Object name -EQ $_.name).ExceptIfSenderDomainIs -join "<br />") } },
    @{l = 'ruleOutboundExclAllCount'; e = { (($RuleState | Where-Object name -EQ $_.name).ExceptIfFrom + ($RuleState | Where-Object name -EQ $_.name).ExceptIfFromMemberOf + ($RuleState | Where-Object name -EQ $_.name).ExceptIfSenderDomainIs) | Measure-Object | Select-Object -ExpandProperty Count } },
    @{l = 'AllAllowed'; e = { "-Allowed Senders-<br />" + ($($_.AllowedSenders) -join "<br />") + "<br />-Allowed Domains-<br />" + ($($_.AllowedSenderDomains) -join "<br />") } },
    @{l = 'AllAllowedCount'; e = { $($_.AllowedSenders) + $($_.AllowedSenderDomains) | Measure-Object | Select-Object -ExpandProperty Count } },
    @{l = 'AllBlocked'; e = { "-Blocked Senders-<br />" + ($($_.BlockedSenders) -join "<br />") + "<br />-Blocked Domains-<br />" + ($($_.BlockedSenderDomains) -join "<br />") } },
    @{l = 'AllBlockedCount'; e = { $($_.BlockedSenders) + $($_.BlockedSenderDomains) | Measure-Object | Select-Object -ExpandProperty Count } },
    @{l = 'AllPhishExcluded'; e = { "-Trusted Senders-<br />" + ($($_.ExcludedSenders) -join "<br />") + "<br />-Trusted Domains-<br />" + ($($_.ExcludedDomains) -join "<br />") } },
    @{l = 'AllPhishExcludedCount'; e = { $($_.ExcludedSenders) + $($_.ExcludedDomains) | Measure-Object | Select-Object -ExpandProperty Count } }
    $StatusCode = [HttpStatusCode]::OK
}
catch {
    $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
    $StatusCode = [HttpStatusCode]::Forbidden
    $GraphRequest = $ErrorMessage
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = $StatusCode
        Body       = @($GraphRequest)
    })

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
    New-ExoRequest -tenantid $Tenantfilter -cmdlet "Get-ATPProtectionPolicyRule" | Select-Object * -ExcludeProperty *odata*, *data.type* | ForEach-Object { $RuleState.add($_) }
    New-ExoRequest -tenantid $Tenantfilter -cmdlet "Get-ATPBuiltInProtectionRule" | Select-Object * -ExcludeProperty *odata*, *data.type* | ForEach-Object { $RuleState.add($_) }
    $Policies = $Policies | Where-Object -FilterScript { $_.name -in $RuleState.name -or $_.IsDefault -eq $true }
    
    $GraphRequest = $Policies | Select-Object *,
    @{l = 'ruleState'; e = { ($RuleState | Where-Object name -EQ $_.name).State } },
    @{l = 'rulePrio'; e = { if ($_.name -eq "Standard Preset Security Policy") { -1 }elseif ($_.name -eq "Strict Preset Security Policy") { -2 }else { ($RuleState | Where-Object name -EQ $_.name).Priority } } },
    @{l = 'ruleInclUsers'; e = { ($RuleState | Where-Object name -EQ $_.name).SentTo -join "<br />" } },
    @{l = 'ruleInclUsersCount'; e = { ($RuleState | Where-Object name -EQ $_.name).SentTo | Measure-Object | Select-Object -ExpandProperty Count } },
    @{l = 'ruleInclGroups'; e = { ($RuleState | Where-Object name -EQ $_.name).SentToMemberOf -join "<br />" } },
    @{l = 'ruleInclGroupsCount'; e = { ($RuleState | Where-Object name -EQ $_.name).SentToMemberOf  | Measure-Object | Select-Object -ExpandProperty Count } },
    @{l = 'ruleInclDomains'; e = { ($RuleState | Where-Object name -EQ $_.name).RecipientDomainIs -join "<br />" } },
    @{l = 'ruleInclDomainsCount'; e = { ($RuleState | Where-Object name -EQ $_.name).RecipientDomainIs  | Measure-Object | Select-Object -ExpandProperty Count } }, 
    @{l = 'ruleExclUsers'; e = { ($RuleState | Where-Object name -EQ $_.name).ExceptIfSentTo -join "<br />" } },
    @{l = 'ruleExclUsersCount'; e = { ($RuleState | Where-Object name -EQ $_.name).ExceptIfSentTo | Measure-Object | Select-Object -ExpandProperty Count } }, 
    @{l = 'ruleExclGroups'; e = { ($RuleState | Where-Object name -EQ $_.name).ExceptIfSentToMemberOf -join "<br />" } },
    @{l = 'ruleExclGroupCount'; e = { ($RuleState | Where-Object name -EQ $_.name).ExceptIfSentToMemberOf | Measure-Object | Select-Object -ExpandProperty Count } }, 
    @{l = 'ruleExclDomains'; e = { ($RuleState | Where-Object name -EQ $_.name).ExceptIfRecipientDomainIs -join "<br />" } },
    @{l = 'ruleExclDomainsCount'; e = { ($RuleState | Where-Object name -EQ $_.name).ExceptIfRecipientDomainIs | Measure-Object | Select-Object -ExpandProperty Count } }

    $GraphRequest = $GraphRequest | Select-Object *,
    @{l = 'ruleInclAll'; e = { "-Included Users-<br />" + $_.ruleInclUsers + "<br />-Included Groups-<br />" + $_.ruleInclGroups + "<br />-Included Domains-<br />" + $_.ruleInclDomains } },
    @{l = 'ruleInclAllCount'; e = { if ($_.name -eq "Default" -or $_.name -eq "Built-In Protection Policy") { "Default" }else { $_.ruleInclUsersCount + $_.ruleInclGroupsCount + $_.ruleInclDomainsCount } } },
    @{l = 'ruleExclAll'; e = { "-Excluded Users-<br />" + $_.ruleExclUsers + "<br />-Excluded Groups-<br />" + $_.ruleExclGroups + "<br />-Excluded Domains-<br />" + $_.ruleExclDomains } },
    @{l = 'ruleExclAllCount'; e = { $_.ruleExclUsersCount + $_.ruleExclGroupsCount + $_.ruleExclDomainsCount } }
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

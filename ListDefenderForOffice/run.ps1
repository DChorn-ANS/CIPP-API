using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

$APIName = $TriggerMetadata.FunctionName
Write-LogMessage -user $request.headers.'x-ms-client-principal' -API $APINAME  -message "Accessed this API" -Sev "Debug"
$Tenantfilter = $request.Query.tenantfilter
$Function = $request.Query.function

try {
    $Policies = New-ExoRequest -tenantid $Tenantfilter -cmdlet "Get-$($Function)Policy" | Select-Object * -ExcludeProperty *odata*, *data.type*
    $RuleState = New-ExoRequest -tenantid $Tenantfilter -cmdlet "Get-$($Function)Rule" | Select-Object * -ExcludeProperty *odata*, *data.type*
    $GraphRequest = $Policies | Select-Object *,
    @{l = 'ruleState'; e = { $name = $_.name; ($RuleState | Where-Object name -EQ $name).State } },
    @{l = 'rulePrio'; e = { $name = $_.name; {
            (if ($name = "Standard Preset Security Policy") { -1 
                }elseif ($name = "Strict Preset Security Policy") { -2 
                }else { ($RuleState | Where-Object name -EQ $name).Priority }
            ) } }
    },
    @{l = 'ruleInclUsers'; e = { $name = $_.name; ($RuleState | Where-Object name -EQ $name).IncludedSenders -join "<br />" } },
    @{l = 'ruleInclUsersCount'; e = { $name = $_.name; ($RuleState | Where-Object name -EQ $name).IncludedSenders | Measure-Object | Select-Object -ExpandProperty Count } },
    @{l = 'ruleInclGroups'; e = { $name = $_.name; ($RuleState | Where-Object name -EQ $name).IncludedGroups -join "<br />" } },
    @{l = 'ruleInclGroupsCount'; e = { $name = $_.name; ($RuleState | Where-Object name -EQ $name).IncludedGroups  | Measure-Object | Select-Object -ExpandProperty Count } },
    @{l = 'ruleInclDomains'; e = { $name = $_.name; ($RuleState | Where-Object name -EQ $name).IncludedDomains -join "<br />" } },
    @{l = 'ruleInclDomainsCount'; e = { $name = $_.name; ($RuleState | Where-Object name -EQ $name).IncludedDomains  | Measure-Object | Select-Object -ExpandProperty Count } }, 
    @{l = 'ruleExclUsers'; e = { $name = $_.name; ($RuleState | Where-Object name -EQ $name).ExcludedSenders -join "<br />" } },
    @{l = 'ruleInclUsersCount'; e = { $name = $_.name; ($RuleState | Where-Object name -EQ $name).ExcludedSenders | Measure-Object | Select-Object -ExpandProperty Count } }, 
    @{l = 'ruleExclGroups'; e = { $name = $_.name; ($RuleState | Where-Object name -EQ $name).ExcludedGroups -join "<br />" } },
    @{l = 'ruleInclGroupCount'; e = { $name = $_.name; ($RuleState | Where-Object name -EQ $name).ExcludedGroups | Measure-Object | Select-Object -ExpandProperty Count } }, 
    @{l = 'ruleExclDomains'; e = { $name = $_.name; ($RuleState | Where-Object name -EQ $name).ExcludedDomains -join "<br />" } },
    @{l = 'ruleExclDomainsCount'; e = { $name = $_.name; ($RuleState | Where-Object name -EQ $name).ExcludedDomains | Measure-Object | Select-Object -ExpandProperty Count } }
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

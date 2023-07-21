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
    $GraphRequest = $Policies | Select-Object *, @{l = 'ruleState'; e = { $name = $_.name; ($RuleState | Where-Object name -EQ $name).State } }, @{l = 'rulePrio'; e = { $name = $_.name; (if ($name = "Standard Preset Security Policy") { -1 }elseif ($name = "Strict Preset Security Policy") { -2 }else { ($RuleState | Where-Object name -EQ $name).Priority }) } }
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

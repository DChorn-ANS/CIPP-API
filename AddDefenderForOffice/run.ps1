
using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

$APIName = $TriggerMetadata.FunctionName
Write-LogMessage -user $request.headers.'x-ms-client-principal' -API $APINAME  -message "Accessed this API" -Sev "Debug"

$RequestParams = $Request.Body.JSON | ConvertFrom-Json | Select-Object -Property * -ExcludeProperty GUID, comments
$Function = $Request.Body.Type


$Tenants = ($Request.body | Select-Object Select_*).psobject.properties.value

$Result = foreach ($Tenantfilter in $tenants) {
    if ($Function -eq "HostedOutboundSpamFilter" ) {
        try {
            New-ExoRequest -tenantid $Tenantfilter -cmdlet "New-$($Function)Policy" -cmdParams $RequestParams
            $Domains = (New-ExoRequest -tenantid $Tenantfilter -cmdlet "Get-AcceptedDomain").name
            $ruleparams = @{
                "Name"               = "$($RequestParams.name)";
                "$($Function)Policy" = "$($RequestParams.name)";
                "SenderDomainIs"     = @($domains)
            }
            New-ExoRequest -tenantid $Tenantfilter -cmdlet "New-$($Function)Rule" -cmdParams $ruleparams
            "Successfully created $($Function) Policy for $tenantfilter."
            Write-LogMessage -API $APINAME -tenant $tenantfilter -message "Created $($Function) Policy for $($tenantfilter)" -sev Debug
        }
        catch {
            "Could not create $($Function) Policy for $($tenantfilter): $($_.Exception.message)"
        }
    }
    else {
        try {
            New-ExoRequest -tenantid $Tenantfilter -cmdlet "New-$($Function)Policy" -cmdParams $RequestParams
            $Domains = (New-ExoRequest -tenantid $Tenantfilter -cmdlet "Get-AcceptedDomain").name
            $ruleparams = @{
                "Name"               = "$($RequestParams.name)";
                "$($Function)Policy" = "$($RequestParams.name)";
                "RecipientDomainIs"  = @($domains)
            }
            New-ExoRequest -tenantid $Tenantfilter -cmdlet "New-$($Function)Rule" -cmdParams $ruleparams
            "Successfully created $($Function) Policy for $tenantfilter."
            Write-LogMessage -API $APINAME -tenant $tenantfilter -message "Created $($Function) Policy for $($tenantfilter)" -sev Debug
        }
        catch {
            "Could not create $($Function) Policy for $($tenantfilter): $($_.Exception.message)"
        }
    }
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = @{Results = @($Result) }
    })

using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

$APIName = $TriggerMetadata.FunctionName

Write-LogMessage -user $request.headers.'x-ms-client-principal' -API $APINAME -message 'Accessed this API' -Sev 'Debug'

# Restart App
Write-LogMessage -user $request.headers.'x-ms-client-principal' -API $APINAME -message "Restarted the Function App at $(Get-Date)" -Sev 'Alert'
$GraphRequest = [pscustomobject]@{'Results' = "Restart of the Function App has been requested" }
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = $GraphRequest
    })
Restart-AzFunctionApp -Name $($ENV:WEBSITE_SITE_NAME) -ResourceGroupName $($ENV:Website_Resource_Group) -Force



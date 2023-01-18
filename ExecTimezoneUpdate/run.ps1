using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

$APIName = $TriggerMetadata.FunctionName
Write-LogMessage -user $request.headers.'x-ms-client-principal' -API $APINAME  -message "Accessed this API" -Sev "Debug"
try { 
    if ($request.query.timezone) {
        Update-AzFunctionAppSetting -Name $Env:WEBSITE_SITE_NAME -ResourceGroupName $env:WEBSITE_RESOURCE_GROUP -AppSetting @{"WEBSITE_TIME_ZONE" = "$($request.query.timezone)" }
    }
    else {
        
    }
    Write-LogMessage -user $request.headers.'x-ms-client-principal' -API $APINAME  -message "Updated Timezone" -Sev "Debug"

    $body = [pscustomobject]@{
        Timezone = $Env:WEBSITE_SITE_NAME
    }
}
catch {
    Write-LogMessage -user $request.headers.'x-ms-client-principal'  -API $APINAME -message "Failed to update the Timezone: $($_.Exception.Message)" -Sev "Error"
    $body = [pscustomobject]@{"Timezone" = "Timezone failed to apply: $($_.Exception.Message)" }
}


# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = $body
    })

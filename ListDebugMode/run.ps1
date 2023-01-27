using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

$APIName = $TriggerMetadata.FunctionName

Write-LogMessage -user $request.headers.'x-ms-client-principal' -API $APINAME -message 'Accessed this API' -Sev 'Debug'

# Get Debug

if ($env:DebugMode -eq $true) {
    $Body = @{'setDebugMode' = $true }
}
else {
    $Body = @{'setDebugMode' = $false }
}


Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [httpstatusCode]::OK
        Body       = $body
    })

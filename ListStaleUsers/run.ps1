using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

$APIName = $TriggerMetadata.FunctionName
Write-LogMessage -user $request.headers.'x-ms-client-principal' -API $APINAME -message 'Accessed this API' -Sev 'Debug'


# Write to the Azure Functions log stream.
Write-Host 'PowerShell HTTP trigger function processed a request.'

# Interact with query parameters or the body of the request.
$TenantFilter = $Request.Query.TenantFilter
if ($TenantFilter -eq 'AllTenants') {
    Push-OutputBinding -Name Msg -Value (Get-Date).ToString()
    [PSCustomObject]@{
        Tenant   = 'Report does not support all tenants'
        Licenses = 'Report does not support all tenants'
    }
}
#Stale Licensed Users List
try {
    $StaleDate = (get-date).AddDays(-30)
    $StaleUsers = New-GraphGetRequest -uri "https://graph.microsoft.com/beta/users?`$filter=accountEnabled eq true and assignedLicenses/`$count ne 0&`$count=true &`$select=displayName,userPrincipalName,signInActivity" -tenantid $TenantFilter -ComplexFilter
    $AllStaleUsers = @()
    foreach ($StaleUser in $StaleUsers) {
        $StaleUserObject = 
        [PSCustomObject]@{
            DisplayName    = $StaleUser.displayName
            UPN            = $StaleUser.userPrincipalName
            lastSignInDate = $StaleUser.signInActivity.lastSignInDateTime
        }
        if ($null -ne $StaleUserObject.lastSignInDate){
            if((get-date $StaleUserObject.lastSignInDate) -le $StaleDate){$AllStaleUsers += $StaleUserObject}
        }else{$AllStaleUsers += $StaleUserObject}
}
}
catch {
    Write-LogMessage -API 'StaleUserAudit' -tenant $Tenantfilter -message "Stale User List on $($Tenantfilter). Error: $($_.exception.message)" -sev 'Error' 
}
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = @($AllStaleUsers)
    }) -Clobber
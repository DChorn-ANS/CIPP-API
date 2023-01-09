using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host 'PowerShell HTTP trigger function processed a request.'

# Interact with query parameters or the body of the request.
New-NCentralConnection -ServerFQDN "$ENV:NCsite" -JWT "$ENV:NCJWTTOKEN"

$CustomerList = Get-NCCustomerList | Where-Object parentid -eq "50" | select-object customername, customerid


Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = @($CustomerList)
    }) -Clobber
using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host 'PowerShell HTTP trigger function processed a request.'

# Interact with query parameters or the body of the request.
$ClientID = $Request.Query.ClientID
$AppName = $Request.Query.AppName

if (($null -ne $ClientID) -and ($null -ne $AppName)) {

    New-NCentralConnection -ServerFQDN "$ENV:NCSite" -JWT "$ENV:NCJWTTOKEN"

    $devicelist = Get-NCDeviceList -CustomerIDs $ClientID | Select-Object deviceid
    $alldevicesdetails = Get-NCDeviceObject -DeviceIDs $devicelist.deviceid
    $SpecificAppSearch = @()
    foreach ($Device in $alldevicesdetails) {
        if ($device.application.displayname -match $AppName) {
            foreach ($application in $device.application) {
                if ($application.displayname -match $AppName) {
                    $DeviceObj = [PSCustomObject]@{
                        'Customer name'     = $device.customer.customername
                        'Device name'       = $device.longname
                        'Application'       = $application.displayname
                        'Version'           = $application.version
                        'Publisher'         = $application.publisher
                        'Installation Date' = $application.installationdate | out-string
                    }
                    $SpecificAppSearch += $DeviceObj
                }
            }
        }
    }
}

Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = @($SpecificAppSearch)
    }) -Clobber
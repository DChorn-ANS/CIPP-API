using namespace System.Net

# Input bindings are passed in via param block.
param($CustomerID)

# Write to the Azure Functions log stream.
Write-Host 'PowerShell HTTP trigger function processed a request.'


#Build Functions
function Get-NCenDeviceIDList {
    param (
        $CustomerID
    )
    $MySoapRequest = (@"
<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:ei2="http://ei2.nobj.nable.com/">
	<soap:Header/>
	<soap:Body>
		<ei2:deviceList>
			<ei2:username></ei2:username>
			<ei2:password>$ENV:NCJWTTOKEN</ei2:password>
            <ei2:settings>
            <ei2:key>customerID</ei2:key>
            <ei2:value>$CustomerID</ei2:value>
        </ei2:settings>
        <ei2:settings>
            <ei2:key>devices</ei2:key>
            <ei2:value>True</ei2:value>
        </ei2:settings>
        <ei2:settings>
            <ei2:key>probes</ei2:key>
            <ei2:value>False</ei2:value>
        </ei2:settings>
		</ei2:deviceList>
	</soap:Body>
</soap:Envelope>
"@)

    ## Set the Request-properties in a local Dictionary / Hash-table.
    $RequestProps = @{}
    $RequestProps.Method = "Post"
    $RequestProps.Uri = "$ENV:NCsite/dms2/services2/ServerEI2?wsdl HTTP/1.1"
    $RequestProps.TimeoutSec = 10
    $RequestProps.body = $MySoapRequest

    $FullResponse = Invoke-RestMethod @RequestProps
    $IDs = $FullResponse.Envelope.Body.deviceListResponse.return.items | where-object key -eq "device.deviceid" | select-object -ExpandProperty value
    $IDs
}

function Get-NCenDeviceObject {
    param (
        $DeviceIDs
    )
    $SoapDeviceIDS = $DeviceIDs | ForEach-Object { "<ei2:value>$_</ei2:value>" }
    $MySoapRequest = (@"
<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:ei2="http://ei2.nobj.nable.com/">
	<soap:Header/>
	<soap:Body>
		<ei2:deviceAssetInfoExportDeviceWithSettings>
        <ei2:version>0.0</ei2:version>
			<ei2:username></ei2:username>
			<ei2:password>$ENV:NCJWTTOKEN</ei2:password>
            <ei2:settings>
            <ei2:key>TargetByDeviceID</ei2:key>
            $SoapDeviceIDS
            </ei2:settings>
            <ei2:settings>
            <ei2:key>InformationCategoriesInclusion</ei2:key>
            <ei2:value>asset.device</ei2:value>
            <ei2:value>asset.application</ei2:value>
            <ei2:value>asset.customer</ei2:value>
        </ei2:settings>
		</ei2:deviceAssetInfoExportDeviceWithSettings>
	</soap:Body>
</soap:Envelope>
"@)

    ## Set the Request-properties in a local Dictionary / Hash-table.
    $RequestProps = @{}
    $RequestProps.Method = "Post"
    $RequestProps.Uri = "$ENV:NCsite/dms2/services2/ServerEI2?wsdl HTTP/1.1"
    $RequestProps.TimeoutSec = 10
    $RequestProps.body = $MySoapRequest

    $FullResponse = Invoke-RestMethod @RequestProps
    $DeviceObjects = foreach ($return in $($FullResponse.Envelope.Body.deviceAssetInfoExportDeviceWithSettingsResponse.return)) {
        #Application Array Building
        $AppDisplayname = $return.items | where-object key -match "asset.application.displayname" | select-object -ExpandProperty value
        $AppVersion = $return.items | where-object key -match "asset.application.version" | select-object -ExpandProperty value
        $AppPublisher = $return.items | where-object key -match "asset.application.publisher" | select-object -ExpandProperty value
        #Build logic for empty date value
        #$AppInstallationdate = $return.items | where-object key -match "asset.application.installationdate" | select-object -ExpandProperty value
    
        [int]$max = $AppDisplayname.count
        $ApplicationsList = for ($i = 0; $i -lt $max; $i ++) {
            @{
                displayname = $AppDisplayname[$i]
                version     = $AppVersion[$i]
                publisher   = $AppPublisher[$i]
            }
        }
    
        @{
            customername = $return.items | where-object key -eq "asset.customer.customername" | select-object -ExpandProperty value
            devicename   = $return.items | where-object key -eq "asset.device.longname" | select-object -ExpandProperty value
            applications = $ApplicationsList
    
        }
    }
    $DeviceObjects
}

# Interact with query parameters or the body of the request.
$Table = Get-CIPPTable -TableName cacheNCdeviceapps
$DeviceIDList = Get-NCenDeviceIDList -CustomerID $ClientID
$alldevicesdetails = Get-NCenDeviceObject -DeviceIDs $DeviceIDList
$AppCache =
foreach ($Device in $alldevicesdetails) {
    @{
        CustomerName = $device.customername
        DeviceName   = $device.devicename
        Application  = $application.displayname
        Version      = $application.version
        Publisher    = $application.publisher
        PartitionKey = "NCappcache"
        RowKey       = "$($device.customername) - $($device.devicename)"
    }
}
Add-AzDataTableEntity @Table -Entity $AppCache -Force | Out-Null
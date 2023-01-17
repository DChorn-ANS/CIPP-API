using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host 'PowerShell HTTP trigger function processed a request.'

# Interact with query parameters or the body of the request.
$Table = Get-CIPPTable -TableName cacheNCclients
$Rows = Get-AzDataTableEntity @Table | Where-Object -Property Timestamp -GT (Get-Date).AddHours(-8)
if (!$Rows) {

	$MySoapRequest = (@"
<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:ei2="http://ei2.nobj.nable.com/">
	<soap:Header/>
	<soap:Body>
		<ei2:customerListChildren>
			<ei2:username></ei2:username>
			<ei2:password>$ENV:NCJWTTOKEN</ei2:password>
			<ei2:settings>
				<ei2:key>customerID</ei2:key>
				<ei2:value>50</ei2:value>
			</ei2:settings>
		</ei2:customerListChildren>
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

	$Names = $FullResponse.Envelope.body.customerListChildrenResponse.return.items | where-object key -eq "customer.customername" | Select-Object -ExpandProperty value
	$IDs = $FullResponse.Envelope.body.customerListChildrenResponse.return.items | where-object key -eq "customer.customerid" | select-object -ExpandProperty value


	[int]$max = $Names.count
	$CustomerList = for ($i = 0; $i -lt $max; $i ++) {
		@{
			customername = $Names[$i]
			customerid   = $IDs[$i]
			PartitionKey = "NCclients"
			RowKey       = $IDs[$i]
		}
	}
	$Table.Force = $true
	Add-AzDataTableEntity @Table -Entity $CustomerList -Force | Out-Null
}         
else {
	$CustomerList = $Rows
}

Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
		StatusCode = [HttpStatusCode]::OK
		Body       = @($CustomerList)
	}) -Clobber
using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

$APIName = $TriggerMetadata.FunctionName
Write-LogMessage -user $request.headers.'x-ms-client-principal' -API $APINAME  -message "Accessed this API" -Sev "Debug"
$Function = if ($request.Query.function -eq "HostedContentFilter") { "Spamfilter" } { $Request.Query.function }

$ID = $request.query.id
try {
    $Table = Get-CippTable -tablename 'templates'
    $Filter = "PartitionKey eq '$($Function)Template' and RowKey eq '$id'" 
    $ClearRow = Get-AzDataTableEntity @Table -Filter $Filter
    Remove-AzDataTableEntity @Table -Entity $clearRow
    Write-LogMessage -user $request.headers.'x-ms-client-principal'  -API $APINAME  -message "Removed $($Function) Template with ID $ID." -Sev "Info"
    $body = [pscustomobject]@{"Results" = "Successfully removed $($Function) Template" }
}
catch {
    Write-LogMessage -user $request.headers.'x-ms-client-principal'  -API $APINAME  -message "Failed to remove $($Function) template $ID. $($_.Exception.Message)" -Sev "Error"
    $body = [pscustomobject]@{"Results" = "Failed to remove template: $($_.Exception.Message)" }
}


# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = $body
    })

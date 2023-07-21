using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

$APIName = $TriggerMetadata.FunctionName
Write-LogMessage -user $request.headers.'x-ms-client-principal' -API $APINAME  -message "Accessed this API" -Sev "Debug"
$Table = Get-CippTable -tablename 'templates'
$Function = if ($request.Query.function -eq "HostedContentFilter") { "Spamfilter" } else { $Request.Query.function }

if ($null -eq $request.Query.function) {
    $Table = Get-CippTable -tablename 'templates'
    $Filter = "PartitionKey eq 'SpamfilterTemplate' or PartitionKey eq 'HostedOutboundSpamFilterTemplate' or PartitionKey eq 'MalwareFilterTemplate' or PartitionKey eq 'SafeLinksTemplate' or PartitionKey eq 'SafeAttachmentTemplate'or PartitionKey eq 'AntiPhishTemplate'" 
    $Templates = (Get-AzDataTableEntity @Table -Filter $Filter) | ForEach-Object {
        $GUID = $_.RowKey
        $Type = $_.PartitionKey
        $data = $_.JSON | ConvertFrom-Json 
        $data | Add-Member -NotePropertyName "JSON" -NotePropertyValue $JSON
        $data | Add-Member -NotePropertyName "GUID" -NotePropertyValue $GUID
        $data | Add-Member -NotePropertyName "Type" -NotePropertyValue $Type.replace("Template", "")
        $data 
    }
}
else {
    $Table = Get-CippTable -tablename 'templates'
    $Filter = "PartitionKey eq '$($Function)Template'" 
    $Templates = (Get-AzDataTableEntity @Table -Filter $Filter) | ForEach-Object {
        $GUID = $_.RowKey
        $Type = $_.PartitionKey
        $data = $_.JSON | ConvertFrom-Json 
        $data | Add-Member -NotePropertyName "JSON" -NotePropertyValue $_.JSON
        $data | Add-Member -NotePropertyName "GUID" -NotePropertyValue $GUID
        $data | Add-Member -NotePropertyName "Type" -NotePropertyValue $Type.replace("Template", "")
        $data 
    }
}

if ($Request.query.ID) { $Templates = $Templates | Where-Object -Property RowKey -EQ $Request.query.id }


# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = @($Templates)
    })

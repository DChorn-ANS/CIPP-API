using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

$APIName = $TriggerMetadata.FunctionName
Write-LogMessage -user $request.headers.'x-ms-client-principal' -API $APINAME  -message "Accessed this API" -Sev "Debug"
$Tenantfilter = $request.Query.tenantfilter
$Function = $request.Query.function

$Params = @{
    Identity = $request.query.name
}
$AnchorMailbox = New-ExoRequest -tenantid $Tenantfilter -cmdlet "Get-Mailbox" -cmdParams @{Resultsize = 1}

try {
    $cmdlet = "Remove-$($Function)Rule"
    New-ExoRequest -tenantid $Tenantfilter -cmdlet $cmdlet -cmdParams $params -Anchor $($AnchorMailbox).PrimarySmtpAddress
    $cmdlet = "Remove-$($Function)Policy"
    New-ExoRequest -tenantid $Tenantfilter -cmdlet $cmdlet -cmdParams $params -Anchor $($AnchorMailbox).PrimarySmtpAddress
    $Result = "Deleted $($Request.query.name)"
    Write-LogMessage -API $APIName -tenant $tenantfilter -message "Deleted $($Function) rule $($Request.query.name)" -sev Debug
}
catch {
    $ErrorMessage = Get-NormalizedError -Message $_.Exception
    $Result = $ErrorMessage
}



# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = @{Results = $Result }
    })

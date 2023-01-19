param($name)
Set-Location (Get-Item $PSScriptRoot).Parent.FullName

$Table = Get-CIPPTable -TableName cacheNCclients
$Clients = Get-AzDataTableEntity @Table

$object = foreach ($Client in $Clients) {
    $Clients.customerid
}
Write-LogMessage -API 'NCApp' -tenant 'None' -message "running NC App Cache for $($Clients.count) clients" -sev info

$object
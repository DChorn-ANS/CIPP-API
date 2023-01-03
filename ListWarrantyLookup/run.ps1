using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

$APIName = $TriggerMetadata.FunctionName
Write-LogMessage -user $request.headers.'x-ms-client-principal' -API $APINAME -message 'Accessed this API' -Sev 'Debug'


# Write to the Azure Functions log stream.
Write-Host 'PowerShell HTTP trigger function processed a request.'

#Build Functions
function get-AppleWarranty([Parameter(Mandatory = $true)]$SourceDevice, $Client) {
    #Apple warranty check uses estimates, not exacts as they have no API.
    $ManafactureDateEstimate = [PSCustomObject]@{
        "C" = @{ 
            StartDate = "2010 (1st half)"
            EndDate   = "2012 (Estimate)"
        }
        "D" = @{ 
            StartDate = "2010 (2nd half)"
            EndDate   = "2012/2013 (Estimate)"
        }
        
        "F" = @{ 
            StartDate = "2011 (1st half)"
            EndDate   = "2013 (Estimate)"
        }
        "G" = @{ 
            StartDate = "2011 (2nd half)"
            EndDate   = "2013/2014 (Estimate)"
        }
        "H" = @{ 
            StartDate = "2012 (1st half)"
            EndDate   = "2014 (Estimate)"
        }
        "J" = @{ 
            StartDate = "2012 (2nd half)"
            EndDate   = "2014/2015 (Estimate)"
        }
        "K" = @{ 
            StartDate = "2013 (1st half)"
            EndDate   = "2015 (Estimate)"
        }
        "L" = @{ 
            StartDate = "2013 (2nd half)"
            EndDate   = "2015/2016 (Estimate)"
        }
        "M" = @{ 
            StartDate = "2014 (1st half)"
            EndDate   = "2016 (Estimate)"
        }
        "N" = @{ 
            StartDate = "2014 (2nd half)"
            EndDate   = "2016/2017 (Estimate)"
        }
        "P" = @{ 
            StartDate = "2015 (1st half)"
            EndDate   = "2017 (Estimate)"
        }
        "Q" = @{ 
            StartDate = "2015 (2nd half)"
            EndDate   = "2017/2018 (Estimate)"
        }
        "R" = @{ 
            StartDate = "2016 (1st half)"
            EndDate   = "2018 (Estimate)"
        } 
        "S" = @{ 
            StartDate = "2016 (2nd half)"
            EndDate   = "2018/2019 (Estimate)"
        } 
        "T" = @{ 
            StartDate = "2017 (1st half)"
            EndDate   = "2019 (Estimate)"
        } 
        "V" = @{ 
            StartDate = "2017 (2nd half)"
            EndDate   = "2019/2020 (Estimate)"
        }
        "W" = @{ 
            StartDate = "2018 (1st half)"
            EndDate   = "2020 (Estimate)"
        }
        "X" = @{ 
            StartDate = "2018 (2nd half)"
            EndDate   = "2020/2021 (Estimate)"
        }
        "Y" = @{ 
            StartDate = "2019 (1st half)"
            EndDate   = "2021 (Estimate)"
        } 
        "Z" = @{ 
            StartDate = "2019 (2nd half)"
            EndDate   = "2021/2022 (Estimate)"
        }
    }
    $ManafactureDateSerial = $SourceDevice[3]
    $AppleWarranty = $ManafactureDateEstimate.$ManafactureDateSerial
    if ($AppleWarranty -and $script:ExcludeApple -eq $false) {
        $WarObj = [PSCustomObject]@{
            'Serial'                = $SourceDevice
            'Warranty Product name' = "This warranty end date is an estimate."
            'StartDate'             = $AppleWarranty.StartDate
            'EndDate'               = $AppleWarranty.EndDate
            'Warranty Status'       = "Estimate"
        }
    }
    else {
        $WarObj = [PSCustomObject]@{
            'Serial'                = $SourceDevice
            'Warranty Product name' = 'Could not get warranty information'
            'StartDate'             = $null
            'EndDate'               = $null
            'Warranty Status'       = 'Could not get warranty information'
        }
    }
    return $WarObj
}

# This is a list of Service Level Codes that may be returned by the API that are not related to hardware warranties
$SLCBlacklist = @("D", "DL", "PJ", "PR");
function get-DellWarranty([Parameter(Mandatory = $true)]$SourceDevice, $Client) {
    if ($null -eq $Script:DellClientID) {
        write-error "Cannot continue: Dell API information not found. Please run Set-WarrantyAPIKeys before checking Dell Warranty information."
        return  [PSCustomObject]@{
            'Serial'                = $SourceDevice
            'Warranty Product name' = 'Could not get warranty information - No API key'
            'StartDate'             = $null
            'EndDate'               = $null
            'Warranty Status'       = 'Could not get warranty information - No API key'
            
        }
    } 
    $today = Get-Date -Format yyyy-MM-dd
    $AuthURI = "https://apigtwb2c.us.dell.com/auth/oauth/v2/token"
    if ($Script:TokenAge -lt (get-date).AddMinutes(-55)) { $Script:Token = $null }
    If ($null -eq $Script:Token) {
        $OAuth = "$Script:DellClientID`:$Script:DellClientSecret"
        $Bytes = [System.Text.Encoding]::ASCII.GetBytes($OAuth)
        $EncodedOAuth = [Convert]::ToBase64String($Bytes)
        $headersAuth = @{ "authorization" = "Basic $EncodedOAuth" }
        $Authbody = 'grant_type=client_credentials'
        $AuthResult = Invoke-RESTMethod -Method Post -Uri $AuthURI -Body $AuthBody -Headers $HeadersAuth
        $Script:token = $AuthResult.access_token
        $Script:TokenAge = (get-date)
    }

    $headersReq = @{ "Authorization" = "Bearer $Script:Token" }
    $ReqBody = @{ servicetags = $SourceDevice }
    $WarReq = Invoke-RestMethod -Uri "https://apigtwb2c.us.dell.com/PROD/sbil/eapi/v5/asset-entitlements" -Headers $headersReq -Body $ReqBody -Method Get -ContentType "application/json"
    $warEntitlements = $warreq.entitlements | Where-Object { $_.serviceLevelCode -notin $SLCBlacklist }
    $warlatest = $warEntitlements.enddate | sort-object | select-object -last 1 
    $WarrantyState = if ($warlatest -le $today) { "Expired" } else { "OK" }
    if ($warlatest) {
        $StartDate = $warEntitlements.startdate | ForEach-Object { [DateTime]$_ } | sort-object -Descending | select-object -last 1
        $EndDate = $warEntitlements.enddate | ForEach-Object { [DateTime]$_ } | sort-object -Descending | select-object -first 1
        $WarObj = [PSCustomObject]@{
            'Serial'                = $SourceDevice
            'Warranty Product name' = ($warEntitlements.serviceleveldescription | Sort-Object -Unique) -join "`n"
            'StartDate'             = $StartDate
            'EndDate'               = $EndDate
            'Warranty Status'       = $WarrantyState
            
        }
    }
    else {
        $WarObj = [PSCustomObject]@{
            'Serial'                = $SourceDevice
            'Warranty Product name' = 'Could not get warranty information'
            'StartDate'             = $null
            'EndDate'               = $null
            'Warranty Status'       = 'Could not get warranty information'
            
        }
    }
    return $WarObj
}
function get-HPWarranty([Parameter(Mandatory = $true)]$SourceDevice, $Client) {
    try { 
        $HPReq = Invoke-RestMethod -Uri "https://warrantyapiproxy.azurewebsites.net/api/HP?serial=$($SourceDevice)"
    }
    catch {
        $HPReq = $null
    }


    if ($HPreq.StartDate) {
        $today = Get-Date
        $WarrantyState = if ([DateTime]$HPReq.endDate -le $today) { "Expired" } else { "OK" }
        $WarObj = [PSCustomObject]@{
            'Serial'                = $SourceDevice
            'Warranty Product name' = $hpreq.warProduct
            'StartDate'             = [DateTime]$HPReq.StartDate
            'EndDate'               = [DateTime]$HPReq.endDate
            'Warranty Status'       = $WarrantyState
            
        }
    }
    else {
        $WarObj = [PSCustomObject]@{
            'Serial'                = $SourceDevice
            'Warranty Product name' = 'Could not get warranty information'
            'StartDate'             = $null
            'EndDate'               = $null
            'Warranty Status'       = 'Could not get warranty information'
            
        }
    }
    return $WarObj
}
function get-LenovoWarranty([Parameter(Mandatory = $true)]$SourceDevice, $client) {
    $today = Get-Date -Format yyyy-MM-dd
    $APIURL = "https://warrantyapiproxy.azurewebsites.net/api/Lenovo?Serial=$SourceDevice"
    $Req = Invoke-RestMethod -Uri $APIURL -Method get
    if ($req.Warproduct) {
        $warlatest = $Req.EndDate | ForEach-Object { [datetime]$_ } | sort-object | select-object -last 1 
        $WarrantyState = if ($warlatest -le $today) { "Expired" } else { "OK" }
        $WarObj = [PSCustomObject]@{
            'Serial'                = $Req.Serial
            'Warranty Product name' = $Req.WarProduct
            'StartDate'             = [DateTime]($Req.StartDate)
            'EndDate'               = [DateTime]($Req.EndDate)
            'Warranty Status'       = $WarrantyState
            
        }
    }
    else {
        $WarObj = [PSCustomObject]@{
            'Serial'                = $SourceDevice
            'Warranty Product name' = 'Could not get warranty information'
            'StartDate'             = $null
            'EndDate'               = $null
            'Warranty Status'       = 'Could not get warranty information'
            
        }
    }
    return $WarObj
 
 
}
function Get-MSWarranty([Parameter(Mandatory = $true)][string]$SourceDevice, $client) {
    $body = ConvertTo-Json @{
        sku          = "Surface_"
        SerialNumber = "$SourceDevice"
        ForceRefresh = $false
    }
    $today = Get-Date -Format yyyy-MM-dd
    $PublicKey = Invoke-RestMethod -Uri 'https://surfacewarrantyservice.azurewebsites.net/api/key' -Method Get
    $AesCSP = New-Object System.Security.Cryptography.AesCryptoServiceProvider 
    $AesCSP.GenerateIV()
    $AesCSP.GenerateKey()
    $AESIVString = [System.Convert]::ToBase64String($AesCSP.IV)
    $AESKeyString = [System.Convert]::ToBase64String($AesCSP.Key)
    $AesKeyPair = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("$AESIVString,$AESKeyString"))
    $bodybytes = [System.Text.Encoding]::UTF8.GetBytes($body)
    $bodyenc = [System.Convert]::ToBase64String($AesCSP.CreateEncryptor().TransformFinalBlock($bodybytes, 0, $bodybytes.Length))
    $RSA = New-Object System.Security.Cryptography.RSACryptoServiceProvider
    $RSA.ImportCspBlob([System.Convert]::FromBase64String($PublicKey))
    $EncKey = [System.Convert]::ToBase64String($rsa.Encrypt([System.Text.Encoding]::UTF8.GetBytes($AesKeyPair), $false))
     
    $FullBody = @{
        Data = $bodyenc
        Key  = $EncKey
    } | ConvertTo-Json
    
    $WarReq = Invoke-RestMethod -uri "https://surfacewarrantyservice.azurewebsites.net/api/v2/warranty" -Method POST -body $FullBody -ContentType "application/json"
    
    if ($WarReq.warranties) {
        $WarrantyState = foreach ($War in ($WarReq.warranties.effectiveenddate -split 'T')[0]) {
            if ($War -le $today) { "Expired" } else { "OK" }
        }
        $WarObj = [PSCustomObject]@{
            'Serial'                = $SourceDevice
            'Warranty Product name' = $WarReq.warranties.name -join "`n"
            'StartDate'             = [DateTime](($WarReq.warranties.effectivestartdate | sort-object -Descending | select-object -last 1) -split 'T')[0]
            'EndDate'               = [DateTime](($WarReq.warranties.effectiveenddate | sort-object | select-object -last 1) -split 'T')[0]
            'Warranty Status'       = $WarrantyState
            
        }
    }
    else {
        $WarObj = [PSCustomObject]@{
            'Serial'                = $SourceDevice
            'Warranty Product name' = 'Could not get warranty information'
            'StartDate'             = $null
            'EndDate'               = $null
            'Warranty Status'       = 'Could not get warranty information'
            
        }
    }
    return $WarObj
}
function get-ToshibaWarranty
([Parameter(Mandatory = $true)]$SourceDevice, [Parameter(Mandatory = $false)] [string]$ModelNumber, [Parameter(Mandatory = $false)] [string]$client) {
    $today = Get-Date -Format yyyy-MM-dd
    $APIURL = "http://support.toshiba.com/support/warrantyResults?sno=" + $SourceDevice + "&mpn=" + $modelnumber
    $Req = Invoke-RestMethod -Uri $APIURL -Method get
    if ($req.commonBean) {
        #$warlatest = $Req.EndDate | sort-object | select-object -last 1 
        $WarrantyState = if ($req.commonBean.warrantyExpiryDate -le $today) { "Expired" } else { "OK" }   
        $WarObj = [PSCustomObject]@{
            'Serial'                = $req.commonBean.serialNumber
            'Warranty Product name' = ($Req.serviceTypes.Carry.svcDesc -replace '<[^>]+>', '')
            'StartDate'             = [DateTime]::ParseExact($($req.commonBean.warOnsiteDate), 'yyyy-MM-dd HH:mm:ss.f', [Globalization.CultureInfo]::CreateSpecificCulture('en-NL'))
            'EndDate'               = [DateTime]::ParseExact($($req.commonBean.warrantyExpiryDate), 'yyyy-MM-dd HH:mm:ss.f', [Globalization.CultureInfo]::CreateSpecificCulture('en-NL'))
            'Warranty Status'       = $WarrantyState
            
        }
    }
    else {
        $WarObj = [PSCustomObject]@{
            'Serial'                = $SourceDevice
            'Warranty Product name' = 'Could not get warranty information'
            'StartDate'             = $null
            'EndDate'               = $null
            'Warranty Status'       = 'Could not get warranty information'
            
        }
    }
    return $WarObj
 
 
}
function  Get-Warrantyinfo {
    [CmdletBinding()]
    Param(
        [string]$DeviceSerial
    )
    switch ($DeviceSerial.Length) {
        7 { get-DellWarranty -SourceDevice $DeviceSerial -client $Client }
        8 { get-LenovoWarranty -SourceDevice $DeviceSerial -client $Client }
        9 { get-ToshibaWarranty -SourceDevice $DeviceSerial -client $line.client }
        10 { get-HPWarranty  -SourceDevice $DeviceSerial -client $Client }
        12 {
            if ($DeviceSerial -match "^\d+$") {
                Get-MSWarranty  -SourceDevice $DeviceSerial -client $Client 
            }
            else {
                Get-AppleWarranty -SourceDevice $DeviceSerial -client $Client
            } 
        }
        default {
            [PSCustomObject]@{
                'Serial'                = $DeviceSerial
                'Warranty Product name' = 'Could not get warranty information.'
                'StartDate'             = $null
                'EndDate'               = $null
                'Warranty Status'       = 'Could not get warranty information'
            }
        }
    }
}

# Interact with query parameters or the body of the request.
$DeviceSerial = $Request.Query.DeviceSerial

$Warranty = Get-Warrantyinfo -DeviceSerial $DeviceSerial

Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = @($Warranty)
    }) -Clobber
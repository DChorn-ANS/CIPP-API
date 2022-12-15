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

#Build Result Table
$Result = @{
    Tenant                            = "$TenantFilter"
    ATPEnabled                        = ''
    HasAADP1                          = ''
    HasAADP2                          = ''
    AdminMFAV2                        = ''
    MFARegistrationV2                 = ''
    GlobalAdminCount                  = ''
    GlobalAdminList                   = ''
    BlockLegacyAuthentication         = ''
    PasswordHashSync                  = ''
    SigninRiskPolicy                  = ''
    UserRiskPolicy                    = ''
    PWAgePolicyNew                    = ''
    SelfServicePasswordReset          = ''
    enableBannedPassworCheckOnPremise = ''
    accessPackages                    = ''
    SecureDefaultState                = ''
    AdminSessionbyCA                  = ''
    AdminSessionbyCAName              = ''
}

# Starting the ANS Best Practice Analyser
    
# Get the All results needed from the Secure Score
try {
    $SecureScore = New-GraphGetRequest -uri "https://graph.microsoft.com/beta/security/secureScores?`$top=1" -tenantid $Tenantfilter -noPagination $true
    $Result.ATPEnabled = $SecureScore.enabledServices.Contains("HasEOP")
    $Result.HasAADP1 = $SecureScore.enabledServices.Contains("HasAADP1")
    $Result.HasAADP2 = $SecureScore.enabledServices.Contains("HasAADP2")
    $Result.AdminMFAV2 = [int]($SecureScore.controlScores | where-object { $_.controlName -eq "AdminMFAv2" } | Select-Object -ExpandProperty count)
    $Result.MFARegistrationV2 = [int]($SecureScore.controlScores | where-object { $_.controlName -eq "MFARegistrationV2" } | Select-Object -ExpandProperty count)
    $Result.GlobalAdminCount = [int]($SecureScore.controlScores | where-object { $_.controlName -eq "OneAdmin" } | Select-Object -ExpandProperty count)
    $Result.BlockLegacyAuthentication = [int]($SecureScore.controlScores | where-object { $_.controlName -eq "BlockLegacyAuthentication" } | Select-Object -ExpandProperty count)
    $Result.PasswordHashSync = $SecureScore.controlScores | where-object { $_.controlName -eq "PasswordHashSync" } | Select-Object -ExpandProperty on
    $Result.PWAgePolicyNew = [int]($SecureScore.controlScores | where-object { $_.controlName -eq "PWAgePolicyNew" } | Select-Object -ExpandProperty expiry)
    
    #Azure AD Premium P2 required
    if ($null -ne $result.HasAADP2) {
        $Result.SigninRiskPolicy = [int]($SecureScore.controlScores | where-object { $_.controlName -eq "SigninRiskPolicy" } | Select-Object -ExpandProperty count)
        $Result.UserRiskPolicy = [int]($SecureScore.controlScores | where-object { $_.controlName -eq "UserRiskPolicy" } | Select-Object -ExpandProperty count)
    }


}
catch {
    Write-LogMessage -API 'CISstandardsAnalyser' -tenant $Tenantfilter -message "Secure Score Retrieval on $($Tenantfilter). Error: $($_.exception.message)" -sev 'Error' 
}

#Populate Global Admin List
try {
    $GlobalAdminGraph = New-GraphGetRequest -uri "https://graph.microsoft.com/beta/directoryRoles/roleTemplateId=62e90394-69f5-4237-9190-012177145e10/members" -tenantid $Tenantfilter
    $AdminList = ($GlobalAdminGraph | Where-object { ($_.accountEnabled -eq "True") -and ($Null -ne $_.userPrincipalName) } | Select-Object -ExpandProperty userPrincipalName) -join '<br />'
    $ServicePrincipalList = ($GlobalAdminGraph | Where-object { ($_.accountEnabled -eq "True") -and ($Null -ne $_.appDisplayName) } | Select-Object -ExpandProperty appDisplayName) -join '<br />'
    $Result.GlobalAdminList = $AdminList + '<br />' + $ServicePrincipalList
}
catch {
    Write-LogMessage -API 'CISstandardsAnalyser' -tenant $Tenantfilter -message "Global Admin List on $($Tenantfilter). Error: $($_.exception.message)" -sev 'Error' 
}

# Get Self Service Password Reset State
try {
    $SSPRGraph = New-ClassicAPIGetRequest -Resource "74658136-14ec-4630-ad9b-26e160ff0fc6" -TenantID $TenantFilter -uri "https://main.iam.ad.ext.azure.com/api/PasswordReset/PasswordResetPolicies" -Method "GET"    
    If ($SSPRGraph.enablementType -eq 0) { $Result.SelfServicePasswordReset = 'Off' }
    If ($SSPRGraph.enablementType -eq 1) { $Result.SelfServicePasswordReset = 'Specific Users' }
    If ($SSPRGraph.enablementType -eq 2) { $Result.SelfServicePasswordReset = 'On' }
    If ([string]::IsNullOrEmpty($SSPRGraph.enablementType)) { $Result.SelfServicePasswordReset = 'Unknown' }
}
catch {
    Write-LogMessage -API 'CISstandardsAnalyser' -tenant $Tenantfilter -message "Self Service Password Reset on $($Tenantfilter). Error: $($_.exception.message)" -sev 'Error' 
}


# Check On Premise Password Protection
try {
    if ($null -ne $Result.HasAADP1) {
        $OPPPGraph = New-ClassicAPIGetRequest -Resource "74658136-14ec-4630-ad9b-26e160ff0fc6" -TenantID $TenantFilter -uri "https://main.iam.ad.ext.azure.com/api/AuthenticationMethods/PasswordPolicy" -Method "GET"
        $Result.enableBannedPassworCheckOnPremise = $OPPPGraph.enableBannedPasswordCheckOnPremises
    }
}
catch {
    Write-LogMessage -API 'CISstandardsAnalyser' -tenant $Tenantfilter -message "On Premise Password Protection on $($Tenantfilter). Error: $($_.exception.message)" -sev 'Error' 
}

# Check JIT Access Packages
try {
    if ($null -ne $Result.HasAADP2) {
        $JIT = New-GraphGetRequest -Uri 'https://graph.microsoft.com/beta/identityGovernance/entitlementManagement/accessPackages' -tenantid $Tenantfilter
        $JITCount = $JIT | measure-object -Property id | select-object -ExpandProperty count
        $Result.accessPackages = if (!$JitCount) { [int]"0" }else { $JitCount }
    }
}
catch {
    Write-LogMessage -API 'CISstandardsAnalyser' -tenant $Tenantfilter -message "JIT Access Packages on $($Tenantfilter) Error: $($_.exception.message)" -sev 'Error'
}

# Get the Secure Default State
try {
    $SecureDefaultsState = (New-GraphGetRequest -Uri 'https://graph.microsoft.com/beta/policies/identitySecurityDefaultsEnforcementPolicy' -tenantid $Tenantfilter)
    $Result.SecureDefaultState = $SecureDefaultsState.IsEnabled
}
catch {
    Write-LogMessage -API 'CISstandardsAnalyser' -tenant $Tenantfilter -message "Security Defaults State on $($Tenantfilter) Error: $($_.exception.message)" -sev 'Error'
}

# Admin Users Session CA Policy
try {
    if ($null -ne $result.HasAADP1) {
        $CAPolicies = New-GraphGetRequest -Uri 'https://graph.microsoft.com/beta/identity/conditionalAccess/policies' -tenantid $Tenantfilter
        $Result.AdminSessionbyCAName = ($CAPolicies | where-object { $_.conditions.users.includeRoles -ne $null -and $_.conditions.applications.includeApplications -eq "All" -and $_.sessionControls.persistentBrowser.mode -eq "never" -and $_.sessionControls.persistentBrowser.IsEnabled -eq "True" } | Select-object -ExpandProperty Displayname) -join '<br />'
        $Result.AdminSessionbyCA = ($Result.AdminSessionbyCAName | Measure-object).count
    }
}
catch {
    Write-LogMessage -API 'CISstandardsAnalyser' -tenant $Tenantfilter -message "MFA Enforced by CA on $($Tenantfilter) Error: $($_.exception.message)" -sev 'Error'
}

#Display Results
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = @($Result)
    }) -Clobber
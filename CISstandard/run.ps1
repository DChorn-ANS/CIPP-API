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
$Result = @(
    [PSCustomObject]@{Configuration = 'Ensure multifactor authentication is enabled for all users in administrative roles' ; LicenseLevel = 'E3 L1'; Controlv8 = '6.5' ; IGGroup = '1' ; Result = '' }
    [PSCustomObject]@{Configuration = 'Ensure multifactor authentication is enabled for all users in all roles' ; LicenseLevel = 'E3 L2'; Controlv8 = '6.3' ; IGGroup = '2' ; Result = '' } 
    [PSCustomObject]@{Configuration = 'Ensure that between two and four global admins are designated' ; LicenseLevel = 'E3 L1'; Controlv8 = '5.1' ; IGGroup = '1' ; Result = '' } 
    [PSCustomObject]@{Configuration = 'Ensure self-service password reset is enabled' ; LicenseLevel = 'E3 L1'; Controlv8 = '14.3' ; IGGroup = '1' ; Result = '' } 
    [PSCustomObject]@{Configuration = 'Ensure that password protection is enabled for Active Directory' ; LicenseLevel = 'E3 L1'; Controlv8 = '5.2' ; IGGroup = '1' ; Result = '' } 
    [PSCustomObject]@{Configuration = 'Enable Conditional Access policies to block legacy authentication' ; LicenseLevel = 'E3 L1'; Controlv8 = '4.8' ; IGGroup = '2' ; Result = '' } 
    [PSCustomObject]@{Configuration = 'Ensure that password hash sync is enabled for hybrid deployments' ; LicenseLevel = 'E3 L1'; Controlv8 = '6.7' ; IGGroup = '2' ; Result = '' } 
    [PSCustomObject]@{Configuration = 'Enable Azure AD Identity Protection sign-in risk policies' ; LicenseLevel = 'E5 L2'; Controlv8 = '13.3' ; IGGroup = '2' ; Result = '' } 
    [PSCustomObject]@{Configuration = 'Enable Azure AD Identity Protection user risk policies' ; LicenseLevel = 'E5 L2'; Controlv8 = '13.3' ; IGGroup = '2' ; Result = '' } 
    [PSCustomObject]@{Configuration = 'Use Just In Time privileged access to Office 365 roles' ; LicenseLevel = 'E5 L2'; Controlv8 = '6.1, 6.2' ; IGGroup = '1' ; Result = '' } 
    [PSCustomObject]@{Configuration = 'Ensure Security Defaults is disabled on Azure Active Directory' ; LicenseLevel = 'E3 L1'; Controlv8 = '4.8' ; IGGroup = '2' ; Result = '' } 
    [PSCustomObject]@{Configuration = 'Ensure that only organizationally managed/approved public groups exist' ; LicenseLevel = 'E3 L2'; Controlv8 = '3.3' ; IGGroup = '1' ; Result = '' } 
    [PSCustomObject]@{Configuration = 'Ensure that collaboration invitations are sent to allowed domains only' ; LicenseLevel = 'E3 L2'; Controlv8 = '6.1' ; IGGroup = '1' ; Result = '' } 
    [PSCustomObject]@{Configuration = 'Ensure that LinkedIn contact synchronization is disabled' ; LicenseLevel = 'E3 L2'; Controlv8 = '4.8' ; IGGroup = '' ; Result = '2' } 
    [PSCustomObject]@{Configuration = 'Ensure Sign-in frequency is enabled and browser sessions are not persistent for Administrative users' ; LicenseLevel = 'E3 L1'; Controlv8 = '4.3' ; IGGroup = '1' ; Result = '' } 
    [PSCustomObject]@{Configuration = 'Ensure the option to remain signed in is hidden' ; LicenseLevel = 'E3 L2'; Controlv8 = '16.3' ; IGGroup = '2' ; Result = '' } 
    [PSCustomObject]@{Configuration = 'Ensure modern authentication for Exchange Online is enabled' ; LicenseLevel = 'E3 L1'; Controlv8 = '3.10' ; IGGroup = '2' ; Result = '' } 
    [PSCustomObject]@{Configuration = 'Ensure modern authentication for SharePoint applications is required' ; LicenseLevel = 'E3 L1'; Controlv8 = '3.10' ; IGGroup = '2' ; Result = '' } 
    [PSCustomObject]@{Configuration = 'Ensure that Office 365 Passwords Are Not Set to Expire' ; LicenseLevel = 'E3 L1'; Controlv8 = '5.2' ; IGGroup = '1' ; Result = '' } 
    [PSCustomObject]@{Configuration = 'Ensure Administrative accounts are separate and cloud-only' ; LicenseLevel = 'E3 L1'; Controlv8 = '5.4' ; IGGroup = '1' ; Result = '' } 
)

# Starting the CIS Framework Analyser

#Set Unavailable API calls
$Result[12].Result = 'Manual Steps Required'
$Result[13].Result = 'Manual Steps Required'
$Result[15].Result = 'Manual Steps Required'



# Get the All results needed from the Secure Score
try {
    $SecureScore = New-GraphGetRequest -uri "https://graph.microsoft.com/beta/security/secureScores?`$top=1" -tenantid $Tenantfilter -noPagination $true
    $HasEXOP2 = $SecureScore.enabledServices.Contains("HasEXOP2")
    $HasAADP1 = $SecureScore.enabledServices.Contains("HasAADP1")
    $HasAADP2 = $SecureScore.enabledServices.Contains("HasAADP2")
    $Result[0].Result = [int]($SecureScore.controlScores | where-object { $_.controlName -eq "AdminMFAv2" } | Select-Object -ExpandProperty count)
    $Result[1].Result = [int]($SecureScore.controlScores | where-object { $_.controlName -eq "MFARegistrationV2" } | Select-Object -ExpandProperty count)
    $Result[2].Result = [int]($SecureScore.controlScores | where-object { $_.controlName -eq "OneAdmin" } | Select-Object -ExpandProperty count)
    $Result[6].Result = $SecureScore.controlScores | where-object { $_.controlName -eq "PasswordHashSync" } | Select-Object -ExpandProperty on
    $Result[18].Result = [int]($SecureScore.controlScores | where-object { $_.controlName -eq "PWAgePolicyNew" } | Select-Object -ExpandProperty expiry)

    #Azure AD Premium P1 required
    if ($result.HasAADP1 -eq $True) {
        $Result[5].Result = [int]($SecureScore.controlScores | where-object { $_.controlName -eq "BlockLegacyAuthentication" } | Select-Object -ExpandProperty count)
    }
    else {
        $Result[5].Result = "Not Licensed for AADp1"
    }

    #Azure AD Premium P2 required
    if ($result.HasAADP2 -eq $True) {
        $Result[7].Result = [int]($SecureScore.controlScores | where-object { $_.controlName -eq "SigninRiskPolicy" } | Select-Object -ExpandProperty count)
        $Result[8].Result = [int]($SecureScore.controlScores | where-object { $_.controlName -eq "UserRiskPolicy" } | Select-Object -ExpandProperty count)
    }
    else {
        $Result[7].Result = "Not Licensed for AADp2"
        $Result[8].Result = "Not Licensed for AADp2"
    }


}
catch {
    Write-LogMessage -API 'CISstandardsAnalyser' -tenant $Tenantfilter -message "Secure Score Retrieval on $($Tenantfilter). Error: $($_.exception.message)" -sev 'Error' 
}


# Get Self Service Password Reset State
try {
    $SSPRGraph = New-ClassicAPIGetRequest -Resource "74658136-14ec-4630-ad9b-26e160ff0fc6" -TenantID $TenantFilter -uri "https://main.iam.ad.ext.azure.com/api/PasswordReset/PasswordResetPolicies" -Method "GET"    
    If ($SSPRGraph.enablementType -eq 0) { $Result[3].Result = 'Off' }
    If ($SSPRGraph.enablementType -eq 1) { $Result[3].Result = 'Specific Users' }
    If ($SSPRGraph.enablementType -eq 2) { $Result[3].Result = 'On' }
    If ([string]::IsNullOrEmpty($SSPRGraph.enablementType)) { $Result[3].Result = 'Unknown' }
}
catch {
    Write-LogMessage -API 'CISstandardsAnalyser' -tenant $Tenantfilter -message "Self Service Password Reset on $($Tenantfilter). Error: $($_.exception.message)" -sev 'Error' 
}


# Check On Premise Password Protection
try {
    if ($result.HasAADP1 -eq $True) {
        $OPPPGraph = New-ClassicAPIGetRequest -Resource "74658136-14ec-4630-ad9b-26e160ff0fc6" -TenantID $TenantFilter -uri "https://main.iam.ad.ext.azure.com/api/AuthenticationMethods/PasswordPolicy" -Method "GET"
        $Result[4].Result = $OPPPGraph.enableBannedPasswordCheckOnPremises
    }
    else {
        $Result[4].Result = "Not Licensed for AADp1"
    }
}
catch {
    Write-LogMessage -API 'CISstandardsAnalyser' -tenant $Tenantfilter -message "On Premise Password Protection on $($Tenantfilter). Error: $($_.exception.message)" -sev 'Error' 
}

# Check JIT Access Packages
try {
    if ($Result.HasAADP2 -eq $True) {
        $JIT = New-GraphGetRequest -Uri 'https://graph.microsoft.com/beta/roleManagement/directory/roleEligibilitySchedules' -tenantid $Tenantfilter
        $JITCount = $JIT | measure-object -Property id | select-object -ExpandProperty count
        $Result[9].Result = if (!$JitCount) { [int]"0" }else { $JitCount }
    }
    else {
        $Result[9].Result = "Not Licensed for AADp2"
    }
}
catch {
    Write-LogMessage -API 'CISstandardsAnalyser' -tenant $Tenantfilter -message "JIT Access Packages on $($Tenantfilter) Error: $($_.exception.message)" -sev 'Error'
}

# Get the Secure Default State
try {
    $SecureDefaultsState = (New-GraphGetRequest -Uri 'https://graph.microsoft.com/beta/policies/identitySecurityDefaultsEnforcementPolicy' -tenantid $Tenantfilter)
    $Result[10].Result = $SecureDefaultsState.IsEnabled
}
catch {
    Write-LogMessage -API 'CISstandardsAnalyser' -tenant $Tenantfilter -message "Security Defaults State on $($Tenantfilter) Error: $($_.exception.message)" -sev 'Error'
}

# Get the Public Groups
try {
    $Result[11].Result = (New-GraphGetRequest -Uri 'https://graph.microsoft.com/beta/groups?`$select=displayName,visibility' -tenantid $Tenantfilter | Where-Object { $_.visibility -eq "Public" } | Measure-Object).Count
    

}
catch {
    Write-LogMessage -API 'CISstandardsAnalyser' -tenant $Tenantfilter -message "Public Group Audit on $($Tenantfilter) Error: $($_.exception.message)" -sev 'Error'
}

# Admin Users Session CA Policy
try {
    if ($result.HasAADP1 -eq $True) {
        $CAPolicies = New-GraphGetRequest -Uri 'https://graph.microsoft.com/beta/identity/conditionalAccess/policies' -tenantid $Tenantfilter
        $AdminSessionbyCAName = ($CAPolicies | where-object { $_.conditions.users.includeRoles -ne $null -and $_.conditions.applications.includeApplications -eq "All" -and $_.sessionControls.persistentBrowser.mode -eq "never" -and $_.sessionControls.persistentBrowser.IsEnabled -eq "True" } | Select-object -ExpandProperty Displayname) -join '<br />'
        $Result[14].Result = ($AdminSessionbyCAName | Measure-object).count
    }
    else {
        $Result[14].Result = "Not Licensed for AADp1"
    }
}
catch {
    Write-LogMessage -API 'CISstandardsAnalyser' -tenant $Tenantfilter -message "MFA Enforced by CA on $($Tenantfilter) Error: $($_.exception.message)" -sev 'Error'
}

# Get ModernAuth
try {
    $BasicAuthDisable = Invoke-RestMethod -ContentType 'application/json;charset=UTF-8' -Uri 'https://admin.microsoft.com/admin/api/services/apps/modernAuth' -Method GET -Headers @{
        Authorization            = "Bearer $($token.access_token)";
        'x-ms-client-request-id' = [guid]::NewGuid().ToString();
        'x-ms-client-session-id' = [guid]::NewGuid().ToString()
        'x-ms-correlation-id'    = [guid]::NewGuid()
        'X-Requested-With'       = 'XMLHttpRequest' 
    }
    $Result[16].Result = $BasicAuthDisable.EnableModernAuth
}
catch {
    Write-LogMessage -API 'CISstandardsAnalyser' -tenant $tenant -message "Modern Auth State on $($tenant). Error: $($_.exception.message)" -sev 'Error'
}

# Check Sharepoint Sharing Settings
try {
    
    $Sharepoint = New-GraphGetRequest -Uri 'https://graph.microsoft.com/beta/admin/sharepoint/settings' -tenantid $tenantfilter -AsApp $true
    $Result[17].Result = $Sharepoint.isLegacyAuthProtocolsEnabled
}
catch {
    Write-LogMessage -API 'CISstandardsAnalyser' -tenant $tenant -message "Sharepoint Settings on $($tenant) Error: $($_.exception.message)" -sev 'Error'
}

# Check Cloud Only Admins
try {
    
    $CloudAdmins = New-GraphGetRequest -Uri 'https://graph.microsoft.com/v1.0/directoryRoles?`$expand=members' -tenantid $tenantfilter -AsApp $true
    $Result[19].Result = $CloudAdmins.members | where-object {($null -ne $_.userPrincipalName)-and ($null -ne $_.members.onPremisesImmutableId)}
}
catch {
    Write-LogMessage -API 'CISstandardsAnalyser' -tenant $tenant -message "Sharepoint Settings on $($tenant) Error: $($_.exception.message)" -sev 'Error'
}

#Display Results
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = @($Result)
    }) -Clobber
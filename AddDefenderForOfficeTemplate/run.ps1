using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

$APIName = $TriggerMetadata.FunctionName
Write-LogMessage -user $request.headers.'x-ms-client-principal' -API $APINAME  -message "Accessed this API" -Sev "Debug"
Write-Host ($request | ConvertTo-Json -Compress)
$Function = $Request.query.Function

try {        
    $GUID = (New-Guid).GUID
    $JSON = if ($request.body.PowerShellCommand) {
        Write-Host "PowerShellCommand"
        $request.body.PowerShellCommand | ConvertFrom-Json
    }
    else {
        switch ($Function) {
            { $_ -eq "HostedContentFilter" } {
                ([pscustomobject]$Request.body | Select-Object name, AddXHeaderValue, AdminDisplayName, AllowedSenderDomains, AllowedSenders, BlockedSenderDomains, BlockedSenders, BulkQuarantineTag, BulkSpamAction, BulkThreshold, Confirm, DownloadLink, EnableEndUserSpamNotifications, EnableLanguageBlockList, EnableRegionBlockList, EndUserSpamNotificationCustomFromAddress, EndUserSpamNotificationCustomFromName, EndUserSpamNotificationCustomSubject, EndUserSpamNotificationFrequency, EndUserSpamNotificationLanguage, EndUserSpamNotificationLimit, HighConfidencePhishAction, HighConfidencePhishQuarantineTag, HighConfidenceSpamAction, HighConfidenceSpamQuarantineTag, IncreaseScoreWithBizOrInfoUrls, IncreaseScoreWithImageLinks, IncreaseScoreWithNumericIps, IncreaseScoreWithRedirectToOtherPort, InlineSafetyTipsEnabled, LanguageBlockList, MarkAsSpamBulkMail, MarkAsSpamEmbedTagsInHtml, MarkAsSpamEmptyMessages, MarkAsSpamFormTagsInHtml, MarkAsSpamFramesInHtml, MarkAsSpamFromAddressAuthFail, MarkAsSpamJavaScriptInHtml, MarkAsSpamNdrBackscatter, MarkAsSpamObjectTagsInHtml, MarkAsSpamSensitiveWordList, MarkAsSpamSpfRecordHardFail, MarkAsSpamWebBugsInHtml, ModifySubjectValue, PhishQuarantineTag, PhishSpamAction, PhishZapEnabled, QuarantineRetentionPeriod, RecommendedPolicyType, RedirectToRecipients, RegionBlockList, SpamAction, SpamQuarantineTag, SpamZapEnabled, TestModeAction, TestModeBccToRecipients ) | ForEach-Object {
                    $NonEmptyProperties = $_.psobject.Properties | Where-Object { $null -ne $_.Value } | Select-Object -ExpandProperty Name
                    $_ | Select-Object -Property $NonEmptyProperties 
                }
            }
            { $_ -eq "HostedOutboundSpamFilter" } {
                ([pscustomobject]$Request.body | Select-Object name, AdminDisplayName, ActionWhenThresholdReached, AutoForwardingMode, RecipientLimitExternalPerHour, RecipientLimitInternalPerHour, RecipientLimitPerDay, BccSuspiciousOutboundAdditionalRecipients, BccSuspiciousOutboundMail, NotifyOutboundSpam, NotifyOutboundSpamRecipients) | ForEach-Object {
                    $NonEmptyProperties = $_.psobject.Properties | Where-Object { $null -ne $_.Value } | Select-Object -ExpandProperty Name
                    $_ | Select-Object -Property $NonEmptyProperties 
                }
            }
            { $_ -eq "MalwareFilter" } {
                ([pscustomobject]$Request.body | Select-Object name, AdminDisplayName, CustomNotifications, CustomExternalBody , CustomExternalSubject, CustomFromAddress, CustomFromName, CustomInternalBody, CustomInternalSubject, EnableExternalSenderAdminNotifications, EnableFileFilter, EnableInternalSenderAdminNotifications, ExternalSenderAdminAddress, FileTypeAction, FileTypes, InternalSenderAdminAddress, QuarantineTag, ZapEnabled) | ForEach-Object {
                    $NonEmptyProperties = $_.psobject.Properties | Where-Object { $null -ne $_.Value } | Select-Object -ExpandProperty Name
                    $_ | Select-Object -Property $NonEmptyProperties 
                }
            }
            { $_ -eq "SafeLinks" } {
                ([pscustomobject]$Request.body | Select-Object name, AdminDisplayName, AllowClickThrough, CustomNotificationText, DeliverMessageAfterScan, DisableUrlRewrite, DoNotRewriteUrls, EnableForInternalSenders, EnableOrganizationBranding, EnableSafeLinksForEmail, EnableSafeLinksForOffice, EnableSafeLinksForTeams, ScanUrls , TrackClicks ) | ForEach-Object {
                    $NonEmptyProperties = $_.psobject.Properties | Where-Object { $null -ne $_.Value } | Select-Object -ExpandProperty Name
                    $_ | Select-Object -Property $NonEmptyProperties 
                }
            }
            { $_ -eq "SafeAttachment" } {
                ([pscustomobject]$Request.body | Select-Object name, AdminDisplayName, Action, QuarantineTag, Redirect, RedirectAddress) | ForEach-Object {
                    $NonEmptyProperties = $_.psobject.Properties | Where-Object { $null -ne $_.Value } | Select-Object -ExpandProperty Name
                    $_ | Select-Object -Property $NonEmptyProperties 
                }
            }
            { $_ -eq "AntiPhish" } {
                ([pscustomobject]$Request.body | Select-Object name, AdminDisplayName, AuthenticationFailAction, DmarcQuarantineAction, DmarcRejectAction, EnableFirstContactSafetyTips, EnableMailboxIntelligence, EnableMailboxIntelligenceProtection, EnableOrganizationDomainsProtection, EnableSimilarDomainsSafetyTips, EnableSimilarUsersSafetyTips, EnableSpoofIntelligence, EnableSuspiciousSafetyTip, EnableTargetedDomainsProtection, EnableTargetedUserProtection, EnableUnauthenticatedSender, EnableUnusualCharactersSafetyTips, EnableViaTag, HonorDmarcPolicy, MailboxIntelligenceProtectionAction, MailboxIntelligenceQuarantineTag, PhishThresholdLevel, SpoofQuarantineTag, TargetedDomainProtectionAction, TargetedDomainQuarantineTag, TargetedUserProtectionAction, TargetedUserQuarantineTag) | ForEach-Object {
                    $NonEmptyProperties = $_.psobject.Properties | Where-Object { $null -ne $_.Value } | Select-Object -ExpandProperty Name
                    $_ | Select-Object -Property $NonEmptyProperties 
                }
            }
        }
    }
    $JSON = ($JSON | Select-Object @{n = 'name'; e = { $_.name } }, @{n = 'comments'; e = { $_.comments } }, * | ConvertTo-Json -Depth 10)
    $Table = Get-CippTable -tablename 'templates'
    if ($function = "HostedContentFilter") { $Partition = "SpamfilterTemplate" } { $Partition = "$($Function)Template" }
    $Table.Force = $true
    Add-AzDataTableEntity @Table -Entity @{
        JSON         = "$json"
        RowKey       = "$GUID"
        PartitionKey = "$Partition"
    }
    Write-LogMessage -user $request.headers.'x-ms-client-principal' -API $APINAME  -message "Created $($Function) Template $($Request.body.name) with GUID $GUID" -Sev "Debug"
    $body = [pscustomobject]@{"Results" = "Successfully added $($Function) template" }
            
}
catch {
    Write-LogMessage -user $request.headers.'x-ms-client-principal'  -API $APINAME -message "Failed to create $($Function) Template: $($_.Exception.Message)" -Sev "Error"
    $body = [pscustomobject]@{"Results" = "Failed to add $($Function) Template: $($_.Exception.Message)" }
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = $body
    })

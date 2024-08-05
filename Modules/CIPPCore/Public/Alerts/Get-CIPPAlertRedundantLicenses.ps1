function Get-CIPPAlertRedundantLicenses {
    <#
    .FUNCTIONALITY
        Entrypoint
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false)]
        [Alias('input')]
        $InputValue,
        $TenantFilter
    )

    $RedundantList = '[
        {
          "if_name": "Microsoft 365 Business Premium",
          "if_has": "cbdc14ab-d96c-4c30-b9f4-6ada7cdc1d46",
          "not_name": "Microsoft 365 Business Standard",
          "must_not_have": "f245ecc8-75af-4f8e-b61f-27d8114de5f3"
        },
        {
          "if_name": "Microsoft 365 Business Premium",
          "if_has": "cbdc14ab-d96c-4c30-b9f4-6ada7cdc1d46",
          "not_name": "Microsoft 365 Business Basic",
          "must_not_have": "3b555118-da6a-4418-894f-7df1e2096870"
        },
        {
          "if_name": "Microsoft 365 Business Premium",
          "if_has": "cbdc14ab-d96c-4c30-b9f4-6ada7cdc1d46",
          "not_name": "Exchange Online (Plan 1)",
          "must_not_have": "4b9405b0-7788-4568-add1-99614e613b69"
        },
        {
          "if_name": "Microsoft 365 Business Premium",
          "if_has": "cbdc14ab-d96c-4c30-b9f4-6ada7cdc1d46",
          "not_name": "Microsoft Defender for Office 365 (Plan 1)",
          "must_not_have": "4ef96642-f096-40de-a3e9-d83fb2f90211"
        },
        {
          "if_name": "Microsoft 365 Business Premium",
          "if_has": "cbdc14ab-d96c-4c30-b9f4-6ada7cdc1d46",
          "not_name": "Intune",
          "must_not_have": "061f9ace-7d42-4136-88ac-31dc755f143f"
        },
        {
          "if_name": "Microsoft 365 Business Premium",
          "if_has": "cbdc14ab-d96c-4c30-b9f4-6ada7cdc1d46",
          "not_name": "Microsoft Entra ID P1",
          "must_not_have": "078d2b04-f1bd-4111-bbd4-b4b1b354cef4"
        },
        {
          "if_name": "Microsoft 365 Business Standard",
          "if_has": "f245ecc8-75af-4f8e-b61f-27d8114de5f3",
          "not_name": "Microsoft 365 Business Basic",
          "must_not_have": "3b555118-da6a-4418-894f-7df1e2096870"
        },
        {
          "if_name": "Microsoft 365 Business Standard",
          "if_has": "f245ecc8-75af-4f8e-b61f-27d8114de5f3",
          "not_name": "Exchange Online (Plan 1)",
          "must_not_have": "4b9405b0-7788-4568-add1-99614e613b69"
        },
        {
          "if_name": "Microsoft 365 Business Basic",
          "if_has": "3b555118-da6a-4418-894f-7df1e2096870",
          "not_name": "Exchange Online (Plan 1)",
          "must_not_have": "4b9405b0-7788-4568-add1-99614e613b69"
        },
        {
          "if_name": "Exchange Online (Plan 1)",
          "if_has": "4b9405b0-7788-4568-add1-99614e613b69",
          "not_name": "Exchange Online (Plan 2)",
          "must_not_have": "19ec0d23-8335-4cbd-94ac-6050e30712fa"
        }
      ]'| ConvertFrom-Json

    try {
        $Licenses = New-GraphGetRequest -uri 'https://graph.microsoft.com/beta/users?$select=userPrincipalName,assignedLicenses&$filter=assignedLicenses/$count ne 0&$count=true' -ComplexFilter -tenantid $Item.tenant
        foreach ($License in $Licenses) {
            foreach ($RedundantSku in $RedundantList) {
                if ($user.assignedLicenses.skuId -contains $RedundantSku.if_has -and $user.assignedLicenses.skuId -contains $RedundantSku.must_not_have) {
                    Write-AlertMessage -tenant $($Item.tenant) -message "$($User.userPrincipalName) has redundant licenses assigned"
                }
            }
        }
    }
    catch {
        Write-AlertMessage -tenant $($Item.tenant) -message "Redundant License Alert Error occurred: $(Get-NormalizedError -message $_.Exception.message)"
    }
}

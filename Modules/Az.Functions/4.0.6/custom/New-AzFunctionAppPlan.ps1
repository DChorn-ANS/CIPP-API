function New-AzFunctionAppPlan {
    [OutputType([Microsoft.Azure.PowerShell.Cmdlets.Functions.Models.Api20190801.IAppServicePlan])]
    [Microsoft.Azure.PowerShell.Cmdlets.Functions.Description('Creates a function app service plan.')]
    [CmdletBinding(PositionalBinding=$false, SupportsShouldProcess, ConfirmImpact='Medium')]
    param(
        [Parameter(Mandatory=$true, HelpMessage='Name of the App Service plan.')]
        [Microsoft.Azure.PowerShell.Cmdlets.Functions.Category('Path')]
        [ValidateNotNullOrEmpty()]
        [System.String]
        ${Name},

        [Parameter(Mandatory=$true, HelpMessage='Name of the resource group to which the resource belongs.')]
        [Microsoft.Azure.PowerShell.Cmdlets.Functions.Category('Path')]
        [ValidateNotNullOrEmpty()]
        [System.String]
        ${ResourceGroupName},

        [Parameter(HelpMessage='The Azure subscription ID.')]
        [Microsoft.Azure.PowerShell.Cmdlets.Functions.Category('Path')]
        [Microsoft.Azure.PowerShell.Cmdlets.Functions.Runtime.DefaultInfo(Script='(Get-AzContext).Subscription.Id')]
        [ValidateNotNullOrEmpty()]
        [System.String]
        ${SubscriptionId},

        [Parameter(Mandatory=$true, HelpMessage='The plan sku. Valid inputs are: EP1, EP2, EP3')]
        [Microsoft.Azure.PowerShell.Cmdlets.Functions.Category('Body')]
        [ArgumentCompleter([Microsoft.Azure.PowerShell.Cmdlets.Functions.Support.SkuType])]
        [ValidateNotNullOrEmpty()]
        [System.String]
        # Sku (EP1, EP2 or EP3)
        ${Sku},

        [Parameter(Mandatory=$true, HelpMessage='The worker type for the plan. Valid inputs are: Windows or Linux.')]
        [Microsoft.Azure.PowerShell.Cmdlets.Functions.Category('Runtime')]
        [ArgumentCompleter([Microsoft.Azure.PowerShell.Cmdlets.Functions.Support.WorkerType])]
        [ValidateNotNullOrEmpty()]
        [System.String]
        # Worker type (Linux or Windows)
        ${WorkerType},

        [Parameter(Mandatory=$true, HelpMessage='The location for the consumption plan.')]
        [Microsoft.Azure.PowerShell.Cmdlets.Functions.Category('Path')]
        [ValidateNotNullOrEmpty()]
        [System.String]
        ${Location},

        [Parameter(HelpMessage='The maximum number of workers for the app service plan.')]
        [Microsoft.Azure.PowerShell.Cmdlets.Functions.Category('Body')]
        [System.Int32]
        [ValidateRange(1,100)]
        [Alias("MaxBurst")]
        ${MaximumWorkerCount},

        [Parameter(HelpMessage='The minimum number of workers for the app service plan.')]
        [Microsoft.Azure.PowerShell.Cmdlets.Functions.Category('Body')]
        [System.Int32]
        [Alias("MinInstances")]
        [ValidateRange(1,20)]
        ${MinimumWorkerCount},

        [Parameter(HelpMessage='Resource tags.')]
        [Microsoft.Azure.PowerShell.Cmdlets.Functions.Category('Body')]
        [Microsoft.Azure.PowerShell.Cmdlets.Functions.Runtime.Info(PossibleTypes=([Microsoft.Azure.PowerShell.Cmdlets.Functions.Models.Api20190801.IResourceTags]))]
        [System.Collections.Hashtable]
        [ValidateNotNull()]
        ${Tag},

        [Parameter(HelpMessage='Run the command asynchronously.')]
        [Microsoft.Azure.PowerShell.Cmdlets.Functions.Category('Runtime')]
        [System.Management.Automation.SwitchParameter]
        ${NoWait},
        
        [Parameter(HelpMessage='Run the command as a job.')]
        [Microsoft.Azure.PowerShell.Cmdlets.Functions.Category('Runtime')]
        [System.Management.Automation.SwitchParameter]
        ${AsJob},

        [Parameter()]
        [Alias('AzureRMContext', 'AzureCredential')]
        [ValidateNotNull()]
        [Microsoft.Azure.PowerShell.Cmdlets.Functions.Category('Azure')]
        [System.Management.Automation.PSObject]
        ${DefaultProfile},
        
        [Parameter(DontShow)]
        [Microsoft.Azure.PowerShell.Cmdlets.Functions.Category('Runtime')]
        [System.Management.Automation.SwitchParameter]
        # Wait for .NET debugger to attach
        ${Break},

        [Parameter(DontShow)]
        [ValidateNotNull()]
        [Microsoft.Azure.PowerShell.Cmdlets.Functions.Category('Runtime')]
        [Microsoft.Azure.PowerShell.Cmdlets.Functions.Runtime.SendAsyncStep[]]
        # SendAsync Pipeline Steps to be appended to the front of the pipeline
        ${HttpPipelineAppend},

        [Parameter(DontShow)]
        [ValidateNotNull()]
        [Microsoft.Azure.PowerShell.Cmdlets.Functions.Category('Runtime')]
        [Microsoft.Azure.PowerShell.Cmdlets.Functions.Runtime.SendAsyncStep[]]
        # SendAsync Pipeline Steps to be prepended to the front of the pipeline
        ${HttpPipelinePrepend},

        [Parameter(DontShow)]
        [Microsoft.Azure.PowerShell.Cmdlets.Functions.Category('Runtime')]
        [System.Uri]
        # The URI for the proxy server to use
        ${Proxy},

        [Parameter(DontShow)]
        [ValidateNotNull()]
        [Microsoft.Azure.PowerShell.Cmdlets.Functions.Category('Runtime')]
        [System.Management.Automation.PSCredential]
        # Credentials for a proxy server to use for the remote call
        ${ProxyCredential},

        [Parameter(DontShow)]
        [Microsoft.Azure.PowerShell.Cmdlets.Functions.Category('Runtime')]
        [System.Management.Automation.SwitchParameter]
        # Use the default credentials for the proxy
        ${ProxyUseDefaultCredentials}
    )
    process {
        # Remove bound parameters from the dictionary that cannot be process by the intenal cmdlets.
        foreach ($paramName in @("Sku", "WorkerType", "MaximumWorkerCount", "MinimumWorkerCount", "Location", "Tag"))
        {
            if ($PSBoundParameters.ContainsKey($paramName))
            {
                $PSBoundParameters.Remove($paramName)  | Out-Null
            }
        }

        $Sku = NormalizeSku -Sku $Sku
        $tier = GetSkuName -Sku $Sku

        if (($MaximumWorkerCount -gt 0) -and ($tier -ne "ElasticPremium"))
        {
            $errorMessage = "MaximumWorkerCount is only supported for Elastic Premium (EP) plans."
            $exception = [System.InvalidOperationException]::New($errorMessage)
            ThrowTerminatingError -ErrorId "MaximumWorkerCountIsOnlySupportedForElasticPremiumPlan" `
                                -ErrorMessage $errorMessage `
                                -ErrorCategory ([System.Management.Automation.ErrorCategory]::InvalidOperation) `
                                -Exception $exception
        }

        if ($MaximumWorkerCount -lt $MinimumWorkerCount)
        {
            $errorMessage = "MinimumWorkerCount '$($MinimumWorkerCount)' cannot be less than '$($MaximumWorkerCount)'."
            $exception = [System.InvalidOperationException]::New($errorMessage)
            ThrowTerminatingError -ErrorId "MaximumWorkerCountIsOnlySupportedForElasticPremiumPlan" `
                                -ErrorMessage $errorMessage `
                                -ErrorCategory ([System.Management.Automation.ErrorCategory]::InvalidOperation) `
                                -Exception $exception
        }

        # Validate location for a Premium plan
        $OSIsLinux = $WorkerType -eq "Linux"
        $params = GetParameterKeyValues -PSBoundParametersDictionary $PSBoundParameters `
                                        -ParameterList @("SubscriptionId", "HttpPipelineAppend", "HttpPipelinePrepend")
        ValidatePremiumPlanLocation -Location $Location -OSIsLinux:$OSIsLinux @params

        $servicePlan = New-Object -TypeName Microsoft.Azure.PowerShell.Cmdlets.Functions.Models.Api20190801.AppServicePlan

        # Plan settings
        $servicePlan.SkuTier = $tier
        $servicePlan.SkuName = $Sku
        $servicePlan.Location = $Location
        $servicePlan.Reserved = ($WorkerType -eq "Linux")

        if ($Tag.Count -gt 0)
        {
            $resourceTag = NewResourceTag -Tag $Tag
            $servicePlan.Tag = $resourceTag
        }

        if ($MinimumWorkerCount -gt 0)
        {
            $servicePlan.Capacity = $MinimumWorkerCount
        }

        if ($MaximumWorkerCount -gt 0)
        {
            $servicePlan.MaximumElasticWorkerCount = $MaximumWorkerCount
        }

        # Add the service plan definition
        $PSBoundParameters.Add("AppServicePlan", $servicePlan)  | Out-Null

        if ($PsCmdlet.ShouldProcess($Name, "Creating function app plan"))
        {
            # Save the ErrorActionPreference
            $currentErrorActionPreference = $ErrorActionPreference
            $ErrorActionPreference = 'Stop'

            try
            {
                Az.Functions.internal\New-AzFunctionAppPlan @PSBoundParameters
            }
            catch
            {
                $errorMessage = GetErrorMessage -Response $_
                if ($errorMessage)
                {
                    $exception = [System.InvalidOperationException]::New($errorMessage)
                    ThrowTerminatingError -ErrorId "FailedToCreateFunctionAppPlan" `
                                            -ErrorMessage $errorMessage `
                                            -ErrorCategory ([System.Management.Automation.ErrorCategory]::InvalidOperation) `
                                            -Exception $exception
                }

                throw $_
            }
            finally
            {
                # Reset the ErrorActionPreference
                $ErrorActionPreference = $currentErrorActionPreference
            }
        }
    }
}

# SIG # Begin signature block
# MIInrQYJKoZIhvcNAQcCoIInnjCCJ5oCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAUqVqc+fT+GByA
# QP4nLDXwguibfrrEtG0iPah/HizVpqCCDYEwggX/MIID56ADAgECAhMzAAACzI61
# lqa90clOAAAAAALMMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMjIwNTEyMjA0NjAxWhcNMjMwNTExMjA0NjAxWjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQCiTbHs68bADvNud97NzcdP0zh0mRr4VpDv68KobjQFybVAuVgiINf9aG2zQtWK
# No6+2X2Ix65KGcBXuZyEi0oBUAAGnIe5O5q/Y0Ij0WwDyMWaVad2Te4r1Eic3HWH
# UfiiNjF0ETHKg3qa7DCyUqwsR9q5SaXuHlYCwM+m59Nl3jKnYnKLLfzhl13wImV9
# DF8N76ANkRyK6BYoc9I6hHF2MCTQYWbQ4fXgzKhgzj4zeabWgfu+ZJCiFLkogvc0
# RVb0x3DtyxMbl/3e45Eu+sn/x6EVwbJZVvtQYcmdGF1yAYht+JnNmWwAxL8MgHMz
# xEcoY1Q1JtstiY3+u3ulGMvhAgMBAAGjggF+MIIBejAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQUiLhHjTKWzIqVIp+sM2rOHH11rfQw
# UAYDVR0RBEkwR6RFMEMxKTAnBgNVBAsTIE1pY3Jvc29mdCBPcGVyYXRpb25zIFB1
# ZXJ0byBSaWNvMRYwFAYDVQQFEw0yMzAwMTIrNDcwNTI5MB8GA1UdIwQYMBaAFEhu
# ZOVQBdOCqhc3NyK1bajKdQKVMFQGA1UdHwRNMEswSaBHoEWGQ2h0dHA6Ly93d3cu
# bWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY0NvZFNpZ1BDQTIwMTFfMjAxMS0w
# Ny0wOC5jcmwwYQYIKwYBBQUHAQEEVTBTMFEGCCsGAQUFBzAChkVodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY0NvZFNpZ1BDQTIwMTFfMjAx
# MS0wNy0wOC5jcnQwDAYDVR0TAQH/BAIwADANBgkqhkiG9w0BAQsFAAOCAgEAeA8D
# sOAHS53MTIHYu8bbXrO6yQtRD6JfyMWeXaLu3Nc8PDnFc1efYq/F3MGx/aiwNbcs
# J2MU7BKNWTP5JQVBA2GNIeR3mScXqnOsv1XqXPvZeISDVWLaBQzceItdIwgo6B13
# vxlkkSYMvB0Dr3Yw7/W9U4Wk5K/RDOnIGvmKqKi3AwyxlV1mpefy729FKaWT7edB
# d3I4+hldMY8sdfDPjWRtJzjMjXZs41OUOwtHccPazjjC7KndzvZHx/0VWL8n0NT/
# 404vftnXKifMZkS4p2sB3oK+6kCcsyWsgS/3eYGw1Fe4MOnin1RhgrW1rHPODJTG
# AUOmW4wc3Q6KKr2zve7sMDZe9tfylonPwhk971rX8qGw6LkrGFv31IJeJSe/aUbG
# dUDPkbrABbVvPElgoj5eP3REqx5jdfkQw7tOdWkhn0jDUh2uQen9Atj3RkJyHuR0
# GUsJVMWFJdkIO/gFwzoOGlHNsmxvpANV86/1qgb1oZXdrURpzJp53MsDaBY/pxOc
# J0Cvg6uWs3kQWgKk5aBzvsX95BzdItHTpVMtVPW4q41XEvbFmUP1n6oL5rdNdrTM
# j/HXMRk1KCksax1Vxo3qv+13cCsZAaQNaIAvt5LvkshZkDZIP//0Hnq7NnWeYR3z
# 4oFiw9N2n3bb9baQWuWPswG0Dq9YT9kb+Cs4qIIwggd6MIIFYqADAgECAgphDpDS
# AAAAAAADMA0GCSqGSIb3DQEBCwUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0
# ZSBBdXRob3JpdHkgMjAxMTAeFw0xMTA3MDgyMDU5MDlaFw0yNjA3MDgyMTA5MDla
# MH4xCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMT
# H01pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMTEwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQCr8PpyEBwurdhuqoIQTTS68rZYIZ9CGypr6VpQqrgG
# OBoESbp/wwwe3TdrxhLYC/A4wpkGsMg51QEUMULTiQ15ZId+lGAkbK+eSZzpaF7S
# 35tTsgosw6/ZqSuuegmv15ZZymAaBelmdugyUiYSL+erCFDPs0S3XdjELgN1q2jz
# y23zOlyhFvRGuuA4ZKxuZDV4pqBjDy3TQJP4494HDdVceaVJKecNvqATd76UPe/7
# 4ytaEB9NViiienLgEjq3SV7Y7e1DkYPZe7J7hhvZPrGMXeiJT4Qa8qEvWeSQOy2u
# M1jFtz7+MtOzAz2xsq+SOH7SnYAs9U5WkSE1JcM5bmR/U7qcD60ZI4TL9LoDho33
# X/DQUr+MlIe8wCF0JV8YKLbMJyg4JZg5SjbPfLGSrhwjp6lm7GEfauEoSZ1fiOIl
# XdMhSz5SxLVXPyQD8NF6Wy/VI+NwXQ9RRnez+ADhvKwCgl/bwBWzvRvUVUvnOaEP
# 6SNJvBi4RHxF5MHDcnrgcuck379GmcXvwhxX24ON7E1JMKerjt/sW5+v/N2wZuLB
# l4F77dbtS+dJKacTKKanfWeA5opieF+yL4TXV5xcv3coKPHtbcMojyyPQDdPweGF
# RInECUzF1KVDL3SV9274eCBYLBNdYJWaPk8zhNqwiBfenk70lrC8RqBsmNLg1oiM
# CwIDAQABo4IB7TCCAekwEAYJKwYBBAGCNxUBBAMCAQAwHQYDVR0OBBYEFEhuZOVQ
# BdOCqhc3NyK1bajKdQKVMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMAsGA1Ud
# DwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFHItOgIxkEO5FAVO
# 4eqnxzHRI4k0MFoGA1UdHwRTMFEwT6BNoEuGSWh0dHA6Ly9jcmwubWljcm9zb2Z0
# LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY1Jvb0NlckF1dDIwMTFfMjAxMV8wM18y
# Mi5jcmwwXgYIKwYBBQUHAQEEUjBQME4GCCsGAQUFBzAChkJodHRwOi8vd3d3Lm1p
# Y3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dDIwMTFfMjAxMV8wM18y
# Mi5jcnQwgZ8GA1UdIASBlzCBlDCBkQYJKwYBBAGCNy4DMIGDMD8GCCsGAQUFBwIB
# FjNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2RvY3MvcHJpbWFyeWNw
# cy5odG0wQAYIKwYBBQUHAgIwNB4yIB0ATABlAGcAYQBsAF8AcABvAGwAaQBjAHkA
# XwBzAHQAYQB0AGUAbQBlAG4AdAAuIB0wDQYJKoZIhvcNAQELBQADggIBAGfyhqWY
# 4FR5Gi7T2HRnIpsLlhHhY5KZQpZ90nkMkMFlXy4sPvjDctFtg/6+P+gKyju/R6mj
# 82nbY78iNaWXXWWEkH2LRlBV2AySfNIaSxzzPEKLUtCw/WvjPgcuKZvmPRul1LUd
# d5Q54ulkyUQ9eHoj8xN9ppB0g430yyYCRirCihC7pKkFDJvtaPpoLpWgKj8qa1hJ
# Yx8JaW5amJbkg/TAj/NGK978O9C9Ne9uJa7lryft0N3zDq+ZKJeYTQ49C/IIidYf
# wzIY4vDFLc5bnrRJOQrGCsLGra7lstnbFYhRRVg4MnEnGn+x9Cf43iw6IGmYslmJ
# aG5vp7d0w0AFBqYBKig+gj8TTWYLwLNN9eGPfxxvFX1Fp3blQCplo8NdUmKGwx1j
# NpeG39rz+PIWoZon4c2ll9DuXWNB41sHnIc+BncG0QaxdR8UvmFhtfDcxhsEvt9B
# xw4o7t5lL+yX9qFcltgA1qFGvVnzl6UJS0gQmYAf0AApxbGbpT9Fdx41xtKiop96
# eiL6SJUfq/tHI4D1nvi/a7dLl+LrdXga7Oo3mXkYS//WsyNodeav+vyL6wuA6mk7
# r/ww7QRMjt/fdW1jkT3RnVZOT7+AVyKheBEyIXrvQQqxP/uozKRdwaGIm1dxVk5I
# RcBCyZt2WwqASGv9eZ/BvW1taslScxMNelDNMYIZgjCCGX4CAQEwgZUwfjELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9z
# b2Z0IENvZGUgU2lnbmluZyBQQ0EgMjAxMQITMwAAAsyOtZamvdHJTgAAAAACzDAN
# BglghkgBZQMEAgEFAKCBrjAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgor
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQg9CHUuZf2
# /oMCzMXBSWVj6Mc+2JUS/jkb5W75b48qn+cwQgYKKwYBBAGCNwIBDDE0MDKgFIAS
# AE0AaQBjAHIAbwBzAG8AZgB0oRqAGGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbTAN
# BgkqhkiG9w0BAQEFAASCAQA99zPxQt+DG407dhJbbLJn006Vyg/7JBkTPie0Fq5T
# GmADIcn8arpYFtwcG+FnOybSd/cxIJfDFldVq9l+RvpcNZmFDUbBO/5zqGNpIZ+V
# G28QAbYOHU+P8WHo9KipywRZgrVPQ0y3Vpk3Blct2FaLp0fu4tQG+i45E3+pFrn/
# joOdoV4e3TviaVmxfTl+mXW992Nyfo1zayaU/V5AfUpM898aFqsAGHYXlIJf/m29
# 1UNIDCym57Hd9uEj7yfS4H117dCR806kU0HLzSYEMnQN06Q2oB5fu0vT6LHsqmfR
# lAUn4wkKEunRxAvA6veiM6rHRDQ9fMgrkRrzRDXo7UCOoYIXDDCCFwgGCisGAQQB
# gjcDAwExghb4MIIW9AYJKoZIhvcNAQcCoIIW5TCCFuECAQMxDzANBglghkgBZQME
# AgEFADCCAVUGCyqGSIb3DQEJEAEEoIIBRASCAUAwggE8AgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIJTjGOevucVwNetn1adqtmBtmgZNueySV+sPMfPC
# D0B+AgZjTqi2ko8YEzIwMjIxMDI4MDcyNjU1Ljg4OVowBIACAfSggdSkgdEwgc4x
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKTAnBgNVBAsTIE1p
# Y3Jvc29mdCBPcGVyYXRpb25zIFB1ZXJ0byBSaWNvMSYwJAYDVQQLEx1UaGFsZXMg
# VFNTIEVTTjpGN0E2LUUyNTEtMTUwQTElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUt
# U3RhbXAgU2VydmljZaCCEV8wggcQMIIE+KADAgECAhMzAAABpQDeCMRAB3FOAAEA
# AAGlMA0GCSqGSIb3DQEBCwUAMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNo
# aW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29y
# cG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEw
# MB4XDTIyMDMwMjE4NTExOVoXDTIzMDUxMTE4NTExOVowgc4xCzAJBgNVBAYTAlVT
# MRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKTAnBgNVBAsTIE1pY3Jvc29mdCBPcGVy
# YXRpb25zIFB1ZXJ0byBSaWNvMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjpGN0E2
# LUUyNTEtMTUwQTElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2Vydmlj
# ZTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBALqxhuggaki8wuoOMMd7
# rsEQnmAhtV8iU1Y0itsHq30TdCXJDmvZjaZ8yvOHYFVhTyD1b5JGJtwZjWz1fglC
# qsx5qBxP1Wx1CZnsQ1tiRsRWQc12VkETmkY8x46MgHsGyAmhPPpsgRnklGai7HqQ
# FB31x/Qjkx7rbAlr6PblB4tOmaR1nKxl4VIgstDwfneKaoEEw4iN/xTdztZjwyGi
# Y5hNp6beetkcizgJFO3/yRHYh0gtk+bREhrmIgbarrrgbz7MsnA7tlKvGcO9iHc6
# +2symrAVy3CzQ4IMNPFcTTx8wTZ+kpv6lFs1eG8xlfsu2NDWKshrMlKH2JpYzWAW
# 1fCOD5irXsE4LOvixZQvbneQE6+iGfIQwabj+fRdouAU2AiE+iaNsIDapdKab8WL
# xz6VPRbEL+M6MFkcsoiuKHHoshCp7JhmZ9iM0yrEx2XebOha/XQ342KsRGs2h02g
# pX6wByyT8eD3MJVIxSRm4MLIilvWcpd9N3rooawbLU6gdk7goKWS69+w2jtouXCE
# Yt6IPfZq8ldi0L/CwYbtv7mbHmIZ9Oc0JEJc6b9gcVDfoPiemMKcz15BLepyx7np
# Q2MiDKIscOqKhXuZI+PZerNOHhi/vsy2/Fj9lB6kJrMYSfV0F2frvBSBXMB7xjv8
# pgqX5QXUe8nTxb4UfJ0cDAvBAgMBAAGjggE2MIIBMjAdBgNVHQ4EFgQUX6aPAwCX
# rq6tcO773FkXS2ipGt8wHwYDVR0jBBgwFoAUn6cVXQBeYl2D9OXSZacbUzUZ6XIw
# XwYDVR0fBFgwVjBUoFKgUIZOaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jcmwvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3Js
# MGwGCCsGAQUFBwEBBGAwXjBcBggrBgEFBQcwAoZQaHR0cDovL3d3dy5taWNyb3Nv
# ZnQuY29tL3BraW9wcy9jZXJ0cy9NaWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENB
# JTIwMjAxMCgxKS5jcnQwDAYDVR0TAQH/BAIwADATBgNVHSUEDDAKBggrBgEFBQcD
# CDANBgkqhkiG9w0BAQsFAAOCAgEAlpsLF+UwMKKER2p0WJno4G6GGGnfg3qjDdaH
# c5uvXYtG6KmHrqAf/YqHkmNotSr6ZEEnlGCJYR7W3uJ+5bpvj03wFqGefvQsKIR2
# +q6TrzozvP4NsodWTT5SVp/C6TEDGuLC9mOQKA4tyL40HTW7txb0cAdfgnyHFoI/
# BsZo/FaXezQ8hO4xUjhDpyNNeJ6WYvX5NC+Hv9nmTyzjqyEg/L2cXAOmxEWvfPAQ
# 1lfxvrtUwG75jGeUaewkhwtzanCnP3l6YjwJFKB6n7/TXtrfik1xY1kgev1JwQ5a
# UdPxwSdDmGE4XTN2s6pPOi8IO199Of6AEvh41eDxRz+11VUcpuGn7tJUeSTUSHsv
# zQ8ECOj5w77Mv55/F8hWu07egnG8SrWj5+TFxNPCpx/AFNvzz+odTRTZd4LWuomc
# MHUmLFiUGOAdetF6SofHG5EcFn0DTD1apBZzCP8xsGQcZgwVqo7ov23/uIJlMCLA
# yTYZV9ITCP09ciUJbKBVCQNrGEnQ/XLFO9mysyyDRrvHhU5uGPdXz4Jt2/ZN7JQY
# RuVNSuCpNwoK0Jr1s6ciDvHEeLyiczxoIe9GH3SyfbHx6v/phI+iE3DWo1TCK75E
# L6pt6k5i36/kn2uSVXdTH44ZVkh3/ihV3vEws78uGlvsiMcrKBgpo3HdcjDHiHoW
# sUf4GIwwggdxMIIFWaADAgECAhMzAAAAFcXna54Cm0mZAAAAAAAVMA0GCSqGSIb3
# DQEBCwUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4G
# A1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTIw
# MAYDVQQDEylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkgMjAx
# MDAeFw0yMTA5MzAxODIyMjVaFw0zMDA5MzAxODMyMjVaMHwxCzAJBgNVBAYTAlVT
# MRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1l
# LVN0YW1wIFBDQSAyMDEwMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA
# 5OGmTOe0ciELeaLL1yR5vQ7VgtP97pwHB9KpbE51yMo1V/YBf2xK4OK9uT4XYDP/
# XE/HZveVU3Fa4n5KWv64NmeFRiMMtY0Tz3cywBAY6GB9alKDRLemjkZrBxTzxXb1
# hlDcwUTIcVxRMTegCjhuje3XD9gmU3w5YQJ6xKr9cmmvHaus9ja+NSZk2pg7uhp7
# M62AW36MEBydUv626GIl3GoPz130/o5Tz9bshVZN7928jaTjkY+yOSxRnOlwaQ3K
# Ni1wjjHINSi947SHJMPgyY9+tVSP3PoFVZhtaDuaRr3tpK56KTesy+uDRedGbsoy
# 1cCGMFxPLOJiss254o2I5JasAUq7vnGpF1tnYN74kpEeHT39IM9zfUGaRnXNxF80
# 3RKJ1v2lIH1+/NmeRd+2ci/bfV+AutuqfjbsNkz2K26oElHovwUDo9Fzpk03dJQc
# NIIP8BDyt0cY7afomXw/TNuvXsLz1dhzPUNOwTM5TI4CvEJoLhDqhFFG4tG9ahha
# YQFzymeiXtcodgLiMxhy16cg8ML6EgrXY28MyTZki1ugpoMhXV8wdJGUlNi5UPkL
# iWHzNgY1GIRH29wb0f2y1BzFa/ZcUlFdEtsluq9QBXpsxREdcu+N+VLEhReTwDwV
# 2xo3xwgVGD94q0W29R6HXtqPnhZyacaue7e3PmriLq0CAwEAAaOCAd0wggHZMBIG
# CSsGAQQBgjcVAQQFAgMBAAEwIwYJKwYBBAGCNxUCBBYEFCqnUv5kxJq+gpE8RjUp
# zxD/LwTuMB0GA1UdDgQWBBSfpxVdAF5iXYP05dJlpxtTNRnpcjBcBgNVHSAEVTBT
# MFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNodHRwOi8vd3d3Lm1pY3Jv
# c29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5odG0wEwYDVR0lBAwwCgYI
# KwYBBQUHAwgwGQYJKwYBBAGCNxQCBAweCgBTAHUAYgBDAEEwCwYDVR0PBAQDAgGG
# MA8GA1UdEwEB/wQFMAMBAf8wHwYDVR0jBBgwFoAU1fZWy4/oolxiaNE9lJBb186a
# GMQwVgYDVR0fBE8wTTBLoEmgR4ZFaHR0cDovL2NybC5taWNyb3NvZnQuY29tL3Br
# aS9jcmwvcHJvZHVjdHMvTWljUm9vQ2VyQXV0XzIwMTAtMDYtMjMuY3JsMFoGCCsG
# AQUFBwEBBE4wTDBKBggrBgEFBQcwAoY+aHR0cDovL3d3dy5taWNyb3NvZnQuY29t
# L3BraS9jZXJ0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0yMy5jcnQwDQYJKoZIhvcN
# AQELBQADggIBAJ1VffwqreEsH2cBMSRb4Z5yS/ypb+pcFLY+TkdkeLEGk5c9MTO1
# OdfCcTY/2mRsfNB1OW27DzHkwo/7bNGhlBgi7ulmZzpTTd2YurYeeNg2LpypglYA
# A7AFvonoaeC6Ce5732pvvinLbtg/SHUB2RjebYIM9W0jVOR4U3UkV7ndn/OOPcbz
# aN9l9qRWqveVtihVJ9AkvUCgvxm2EhIRXT0n4ECWOKz3+SmJw7wXsFSFQrP8DJ6L
# GYnn8AtqgcKBGUIZUnWKNsIdw2FzLixre24/LAl4FOmRsqlb30mjdAy87JGA0j3m
# Sj5mO0+7hvoyGtmW9I/2kQH2zsZ0/fZMcm8Qq3UwxTSwethQ/gpY3UA8x1RtnWN0
# SCyxTkctwRQEcb9k+SS+c23Kjgm9swFXSVRk2XPXfx5bRAGOWhmRaw2fpCjcZxko
# JLo4S5pu+yFUa2pFEUep8beuyOiJXk+d0tBMdrVXVAmxaQFEfnyhYWxz/gq77EFm
# PWn9y8FBSX5+k77L+DvktxW/tM4+pTFRhLy/AsGConsXHRWJjXD+57XQKBqJC482
# 2rpM+Zv/Cuk0+CQ1ZyvgDbjmjJnW4SLq8CdCPSWU5nR0W2rRnj7tfqAxM328y+l7
# vzhwRNGQ8cirOoo6CGJ/2XBjU02N7oJtpQUQwXEGahC0HVUzWLOhcGbyoYIC0jCC
# AjsCAQEwgfyhgdSkgdEwgc4xCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5n
# dG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xKTAnBgNVBAsTIE1pY3Jvc29mdCBPcGVyYXRpb25zIFB1ZXJ0byBSaWNv
# MSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjpGN0E2LUUyNTEtMTUwQTElMCMGA1UE
# AxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaIjCgEBMAcGBSsOAwIaAxUA
# s8lw20WzmxDKiN1Lhh7mZWXutKiggYMwgYCkfjB8MQswCQYDVQQGEwJVUzETMBEG
# A1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWlj
# cm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFt
# cCBQQ0EgMjAxMDANBgkqhkiG9w0BAQUFAAIFAOcFrR4wIhgPMjAyMjEwMjgwNTIx
# MzRaGA8yMDIyMTAyOTA1MjEzNFowdzA9BgorBgEEAYRZCgQBMS8wLTAKAgUA5wWt
# HgIBADAKAgEAAgIKEAIB/zAHAgEAAgIRYzAKAgUA5wb+ngIBADA2BgorBgEEAYRZ
# CgQCMSgwJjAMBgorBgEEAYRZCgMCoAowCAIBAAIDB6EgoQowCAIBAAIDAYagMA0G
# CSqGSIb3DQEBBQUAA4GBAJK5N7QeOujLpsP8ejP+vJXm2Dzrw3MC3aRWtl5AXJmm
# d7IxepQx8QgbDCvIyfZp0PW59bvLsI672CLWvFMk4xTN2F2eZ52uLTO5k0u0CDR8
# NFltxAwCuB5eHyQQ8Yw8UhpubYFCoNBjKo2YnTzIfe3I3PJV+2oQYKIii78B0fGb
# MYIEDTCCBAkCAQEwgZMwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0
# b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3Jh
# dGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTACEzMA
# AAGlAN4IxEAHcU4AAQAAAaUwDQYJYIZIAWUDBAIBBQCgggFKMBoGCSqGSIb3DQEJ
# AzENBgsqhkiG9w0BCRABBDAvBgkqhkiG9w0BCQQxIgQgassCDXPTf+eoMBAiFBBg
# t1kZDlZx0xGtpAZzpME5uf0wgfoGCyqGSIb3DQEJEAIvMYHqMIHnMIHkMIG9BCC4
# CjhxfmYEsaCt2AU83Khh+6JHlyk3B70vfMHMlBLcXDCBmDCBgKR+MHwxCzAJBgNV
# BAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4w
# HAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29m
# dCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAABpQDeCMRAB3FOAAEAAAGlMCIEIJu0
# CrW1hBqKoeQz2gzbLmhlFVKu00N4yoK3hosS07SqMA0GCSqGSIb3DQEBCwUABIIC
# AD512/PGdgUlGdoYr3w0FRfgpFHKJbxYjFkQWDuK60eBMyKFkM6gq0wOAXst+yXX
# JbXsKOVZkJvO87Kt1iCpIQoMUiDSlLR6/dD6Q5vFhFd96v2bncVXSUfeqMJ0mjPz
# vgG0JYWhypzm2pn313O7aCKi0F+c3ZbLoz7NWEjBYzIqM2V9mc+xd/qikEI8ejP/
# vREPLie/ddH/pKTdVFPPaaAB87D6kUXXUsy+YlZ6T4eQ9Jj37gLJx9YcnoqYD/Hj
# P6KU0WIs6rQOJGKovZEZKJlIU83cFxv6C6Kv0D/yCpSy/jueIxoVSoNZmH0epnSK
# 5YKhZayhqtUQgDj8aRG11fyLRDmv3c9HK6WyN61hZxYha0Ppgm5UmaQbHqc3X6oV
# PTGh49GhNqIIB/UFecJP8jxoUE9pOhJHyYaQwd3fLFiAKCjl1JZEchBkE/39FS+G
# Wsm1TQaDIRyu6NcPf1UH5QLjM+osbdmEFSvkUXd7szN2EBNeXZJfCeDqZoF0E7v6
# J7/C5QOL5dz3cMrjIa5MVfKTWkXV5B2ysLMIPqwQhPUX7bKV/qRej6B1ukqGpSPS
# hLffBs8lg45vFwybR2SM4WiYI2yNQ2Ix/yrCMgctfAU3sT07HIHQDZooOvCnothr
# 67uwkFd4AzXUCaKP+f/GVVHohl34GuC23tyEn0IvkbuC
# SIG # End signature block

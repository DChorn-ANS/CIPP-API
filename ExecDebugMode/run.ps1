using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

$APIName = $TriggerMetadata.FunctionName

Write-LogMessage -user $request.headers.'x-ms-client-principal' -API $APINAME -message 'Accessed this API' -Sev 'Debug'

# Set Debug
if ($request.Query.setDebugMode -and $request.Query.setDebugMode -ne $ENV:DebugMode) {
    Try {
        Update-AZFunctionAppSetting -Name $($ENV:WEBSITE_SITE_NAME) -ResourceGroupName $($ENV:Website_Resource_Group) -AppSetting @{"DebugMode" = "$($request.Query.setDebugMode)" } -Force
        $GraphRequest = [pscustomobject]@{'Results' = "Set Debug Mode to $($Request.Query.setDebugMode)" }
        Write-LogMessage -user $request.headers.'x-ms-client-principal' -API $APINAME -message "Set Debug Mode to $($request.Query.setDebugMode)" -Sev 'info'
    }
    catch {
        Write-LogMessage  -API $APINAME -message "Failed to set Debug Mode. Error: $($_.exception.message)" -sev Error
        $GraphRequest = [pscustomobject]@{'Results' = "Failed to set Debug Mode. Error: $($_.exception.message)" }
    }
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = $GraphRequest
    })
    exit
}


Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [httpstatusCode]::OK
        Body       = [pscustomobject]@{'Results' = 'No change to Debug Mode'}
    })
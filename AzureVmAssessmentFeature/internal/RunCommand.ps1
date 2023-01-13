#Requires -Version 7.0

using namespace Microsoft.Azure.Commands.Compute.Models
using namespace Microsoft.PowerShell.Commands

param(
    [Parameter(Mandatory = $true)]
    [PSVirtualMachineListStatus]$VirtualMachine,

    [Parameter(Mandatory = $true)]
    [String]$ScriptPath,

    [Parameter(Mandatory = $true)]
    $ScriptParameters,

    [Parameter(Mandatory = $true)]
    [String]$Execution,

    [Parameter(Mandatory = $true)]
    [String]$AccessToken
)

begin {
    Write-Debug -Message "[$($VirtualMachine.Name)] Invoke-RunCommand begin processing"
    $uri = `
        "https://management.azure.com" + `
        "$($VirtualMachine.Id)" + `
        "/runCommand?api-version=2022-08-01"

    $headers = @{
        "Authorization" = "Bearer $($accessToken)"
        "Content-Type"  = "application/json"
    }

    $body = @{
        "commandId"  = "RunPowerShellScript"
        "parameters" = $ScriptParameters
        "script"     = ([String[]](Get-Content -Path $ScriptPath))
    } | ConvertTo-Json
}

process {
    # Invocation
    try {
        Invoke-RestMethod `
            -Method Post `
            -Uri $uri `
            -Headers $headers `
            -Body $body `
            -ResponseHeadersVariable responseHeaders `
            -Verbose:$false
    }
    catch [HttpResponseException] {
        if ($PSItem.Exception.Response.StatusCode -eq 409) {
            $VirtualMachine.Assessment.Error = "RunCommand failed due to HTTP 409"
            $virtualMachine.Assessment.Unsupported = $true
            return $virtualMachine
        }
        else {
            $VirtualMachine.Assessment.Error = "RunCommand failed - $($PSItem.ErrorDetails.Message)"
            $virtualMachine.Assessment.Unsupported = $true
            return $virtualMachine
        }
    }
    catch {
        $VirtualMachine.Assessment.Error = "RunCommand failed - $($PSItem.ErrorDetails.Message)"
        $virtualMachine.Assessment.Unsupported = $true
        return $virtualMachine
    }

    # Poller
    $retryCount = 0
    while ($true) {
        try {
            $response = `
                Invoke-RestMethod `
                -Method Get `
                -Uri "$($responseHeaders["Azure-AsyncOperation"])" `
                -Headers $headers `
                -Verbose:$false

            if ($response.status -eq "InProgress") {
                Start-Sleep -Second 5
            }
            else {
                $commandResult = $response.properties.output
                break
            }
        }
        catch {
            if ($retryCount -lt 5) {
                $retryCount = $retryCount + 1
                Start-Sleep -Second 5
            }
            else {
                $VirtualMachine.Assessment.Error = "RunCommand failed due to poller error $($PSItem.ErrorDetails.Message)"
                $virtualMachine.Assessment.Unsupported = $true
                return $virtualMachine
            }
        }
    }

    # Console
    $VirtualMachine.Assessment.Error = ""
    $VirtualMachine.Assessment.Output = ""

    # Parse
    if ($null -eq $commandResult.Value) {
        $VirtualMachine.Assessment.Error = "Run command returned null"
        if ($Execution -eq "Prerequisites") { $virtualMachine.Assessment.Unsupported = $true }
        return $virtualMachine
    }

    if ($commandResult.Value[1].Message) {
        $VirtualMachine.Assessment.Error = $commandResult.Value[1].Message
        if ($Execution -eq "Prerequisites") { $virtualMachine.Assessment.Unsupported = $true }
        return $virtualMachine
    }

    if ($commandResult.Value[0].Message) {
        $VirtualMachine.Assessment.Output = $commandResult.Value[0].Message
        return $VirtualMachine
    }
}

end {
    Write-Debug -Message "[$($VirtualMachine.Name)] Invoke-RunCommand end processing"
}

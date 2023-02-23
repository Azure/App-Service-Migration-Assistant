#Requires -Version 7.0
#Requires -Modules Az.Accounts, Az.Compute

param (
    [Parameter(Mandatory = $false)]
    [String]$SubscriptionId,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [String[]]$VirtualMachineNames,

    [Parameter(Mandatory = $true)]
    [String]$AccountName,

    [Parameter(Mandatory = $true)]
    [String]$AccountKey,

    [Parameter(Mandatory = $true)]
    [String]$ContainerName,

    [Parameter(Mandatory = $false)]
    [bool]$EnableTelemetry = $true,

    [Parameter(Mandatory = $false)]
    [Int]$ThrottleLimit = 10
)

begin {
    Write-Debug -Message "Invoke-Assessment begin processing"

    $virtualMachines = $()
}

process {
    Write-Information -MessageData "Starting assessment processs..." -InformationAction Continue

    # Subscriptions
    if ($PSBoundParameters.ContainsKey('SubscriptionId')) {
        Write-Verbose -Message "Setting context to subscription [$($SubscriptionId)]"
        Set-AzContext -Subscription $SubscriptionId -Debug:$false | Out-Null
    }

    # Resources
    if ($PSBoundParameters.ContainsKey("VirtualMachineNames")) {
        Write-Verbose -Message "Retrieving virtual machines [$($virtualMachineNames)] in resource group [$($ResourceGroupName)]"
        try {
            $virtualMachines = Get-AzVM -ResourceGroupName $ResourceGroupName -Status -Debug:$false `
            | Where-Object { $virtualMachineNames -contains $_.Name }
        }
        catch {
            Write-Error -Message "Assessment failed (resources) $($PSItem.Exception.Message))"
        }
    }
    else {
        Write-Verbose -Message "Retrieving virtual machines in resource group [$($ResourceGroupName)]"
        try {
            $virtualMachines = Get-AzVM -ResourceGroupName $ResourceGroupName -Status -Debug:$false
        }
        catch {
            Write-Error -Message "Assessment failed (resources) $($PSItem.Exception.Message))"
        }
    }

    if ($null -eq $virtualMachines) {
        Write-Error -Message "Assessment failed (null) [Empty virtual machines list return]" -ErrorAction Stop
    }

    # Elgibility
    foreach ($virtualMachine in $virtualMachines) {
        $assessment = [PSCustomObject]@{
            Unsupported = $false;
            Output      = "";
            Error       = "";
        }

        $virtualMachine | Add-Member -MemberType NoteProperty -Name "Assessment" -Value $assessment

        # Power State
        if ($virtualMachine.PowerState -ne "VM running") {
            $virtualMachine.Assessment.Unsupported = $true
            continue
        }
        # Operating System
        if ($virtualMachine.StorageProfile.OsDisk.OsType -ne "Windows") {
            $virtualMachine.Assessment.Unsupported = $true
            continue
        }
    }

    # Credential
    $accessToken = (Get-AzAccessToken -Debug:$false).Token

    # Prerequisites
    $null = $virtualMachines | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {
        if ($PSItem.Assessment.Unsupported -eq $true) { continue }
        Write-Verbose -Message "Starting prerequisites process on virtual machine [$($PSItem.Name)]" -Verbose:$using:VerbosePreference

        . $using:PSScriptRoot\internal\RunCommand.ps1 `
            -VirtualMachine $PSItem `
            -ScriptPath $using:PSScriptRoot\internal\Prerequisites.ps1 `
            -ScriptParameters @() `
            -Execution "Prerequisites" `
            -AccessToken $using:accessToken `
            -Verbose:$using:VerbosePreference `
            -Debug:$using:DebugPreference
    }

    # Assessment
    $null = $virtualMachines | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {
        if ($PSItem.Assessment.Unsupported -eq $true) { continue }
        Write-Verbose -Message "Starting assessment process on virtual machine [$($PSItem.Name)]" -Verbose:$using:VerbosePreference

        $scriptParameters = @(
            @{ "name" = "AccountName"; "value" = "$($using:AccountName)" }
            @{ "name" = "AccountKey"; "value" = "$($using:AccountKey)" }
            @{ "name" = "ContainerName"; "value" = "$($using:ContainerName)" }
        )

        . $using:PSScriptRoot\internal\RunCommand.ps1 `
            -VirtualMachine $PSItem `
            -ScriptPath $using:PSScriptRoot\internal\Assessment.ps1 `
            -ScriptParameters $scriptParameters `
            -Execution "Assessment" `
            -EnableTelemetry $using:EnableTelemetry `
            -AccessToken $using:accessToken `
            -Verbose:$using:VerbosePreference `
            -Debug:$using:DebugPreference
    }

    # Logging
    $dirPath = New-Item -Path "logs" -ItemType Directory -Force
    $filePath = "$($dirPath.FullName)/assessment_$(Get-Date -format "MM_dd_yyyy_HH_mm").log"
    New-Item -Path $filePath -ItemType File | Out-Null
    Add-Content -Path $filePath -Value "App Service Migration Assessment Report"

    $virtualMachines | ForEach-Object {
        Add-Content -Path $filePath -Value ""
        Add-Content -Path $filePath -Value "Time: $(Get-Date -f g)"
        Add-Content -Path $filePath -Value "Resource Group: $($PSItem.ResourceGroupName)"
        Add-Content -Path $filePath -Value "Virtual Machine: $($PSItem.Name)"
        Add-Content -Path $filePath -Value "Power State: $($PSItem.PowerState)"
        Add-Content -Path $filePath -Value "Operating System: $($PSItem.StorageProfile.OsDisk.OsType)"
        Add-Content -Path $filePath -Value "Unsupported: $($PSItem.Assessment.Unsupported)"
        Add-Content -Path $filePath -Value "Output: $($PSItem.Assessment.Output)"
        Add-Content -Path $filePath -Value "Error: $($PSItem.Assessment.Error)"
    }

    Write-Information -MessageData "Completed assessment processs..." -InformationAction Continue
}

end {
    Write-Debug -Message "Invoke-Assessment end processing"
}

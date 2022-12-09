#requires -version 7.0

<#
    .SYNOPSIS
        TODO
#>
function Invoke-Assessment {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        $SubscriptionId,

        [Parameter(Mandatory = $true)]
        $ResourceGroupName,

        [Parameter(Mandatory = $false)]
        $VMList, 

        [Parameter(Mandatory = $false)]
        $ThrottleLimit = 5,

        [Parameter(Mandatory = $true)]
        $AccountName,

        [Parameter(Mandatory = $true)]
        $AccountKey,

        [Parameter(Mandatory = $true)]
        $ContainerName
    )

    begin {
        Write-Debug -Message "Invoke-Assessment begin processing"
    }

    process {
        # Switch to the provided subscription
        if ($SubscriptionId) {
            Write-Verbose "Switching context..."
            Set-AzContext -SubscriptionId $SubscriptionId
        }

        #
        # Prerequisites
        #

        # If user doesn't input list of VMs, grab a list of all VMs in the resource group provided. 
        if(!$VMList){
            $VMList = Get-AzVM -ResourceGroupName $ResourceGroupName | Select-Object -ExpandProperty Name
        }

        $localVMList = $VMList
    
        foreach ($vm in $VMList) {
            $vmStatus = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $vm -Status
            $dictionary = @{}

            # Check if VM exists
            if ($null -eq $vmStatus) {
                $localVMList = $localVMList | Where-Object { $_ -ne $vm }

                $dictionary.$server += "ERROR: VM does not exist. "
            }

            # Check if VM is running Windows
            if ($vmStatus.OsName -notlike '*windows*' -and $null -ne $vmStatus.OsName) {
                $localVMList = $localVMList | Where-Object { $_ -ne $vm }

                $dictionary.$vm += "ERROR: VM is not running Windows."
            }

            # Check if VM is running
            if (($vmStatus.Statuses.DisplayStatus | Where-Object { $_ -eq "VM running" }).Count -eq 0) {
                $localVMList = $localVMList | Where-Object { $_ -ne $vm }

                $dictionary.$vm += "ERROR: VM is not in a running state. "
            }
        }

        $validServers = $localVMList
        $invalidServers = $dictionary
        
        # Error logging for VMs who failed pre-flight checks
        $fileName = "AppAssesssmentErrorLog_$(Get-Date -format "MM_dd_yyyy_HH_mm").log"
        New-Item -Path $fileName -ItemType File

        foreach($server in $invalidServers.Keys){
            Add-Content -Path $fileName -Value $server
            Add-Content -Path $fileName -Value "---------------------------------------------------------------------------"
            Add-Content -Path $fileName -Value $invalidServers.$($server)
            Add-Content -Path $fileName -Value "`n"
        }

        #
        # Assessment
        #

        Write-Verbose "Starting assessment..."
        $scriptPath = "$PSScriptRoot/lib/Assessment.ps1"
        $validServers | Foreach-Object -Parallel {
            $commandResult = Invoke-AzVMRunCommand `
                                -ResourceGroupName $using:ResourceGroupName `
                                -VMName $_ `
                                -CommandId "RunPowerShellScript" `
                                -ScriptPath $using:scriptPath `
                                -Parameter @{AccountName = $using:AccountName; AccountKey = $using:AccountKey; ContainerName = $using:ContainerName; VMResourceGroupName = $using:ResourceGroupName}

            # Check for command result
            if ($null -eq $commandResult) {
                Write-Warning -Message "Run command return null"
                return $null
            }

            # Check for stderr payload
            if ($commandResult.Value[1].Message) {
                Write-Warning -Message "Run command execution failed: $($_.Name) - $($commandResult.Value[1].Message)"
                return $null
            }

            # Check for stdout payload
            if ($commandResult.Value[0].Message) {
                Write-Information -Message "Run command executed - $($commandResult.Value[0].Message)"
            }
        } -ThrottleLimit $ThrottleLimit
    }

    end {
        Write-Debug -Message "Invoke-Assessment begin processing"
    }

}

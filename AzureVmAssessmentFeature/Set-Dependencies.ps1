#requires -version 7.0

<#
    .SYNOPSIS
        TODO
    .DESCRIPTION
        Upload-Dependencies will handle the retrieval of Microsoft artifacts
        Pushing these artifacts to the customer Storage Account
#>
function Set-Dependencies {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $ResourceGroupName,

        [Parameter(Mandatory = $true)]
        $AccountName,

        [Parameter(Mandatory = $false)]
        $ContainerName = "scripts"
    )

    begin {
        Write-Debug -Message "Upload-Dependencies begin processing"
    }

    process {
        ## Download the assessment scripts

        $filePath = ""
        $fileName = "AppServiceMigrationScripts.zip"
        Invoke-WebRequest -Uri $url -OutFile $fileName

        ## Get the storage account  

        $storageAcc = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $AccountName    

        ## Get the storage account context  
        $context=$storageAcc.Context    

        $Scripts = @{
            File             = $filePath
            Container        = $ContainerName
            Blob             = $fileName
            Context          = $context
            Properties       = @{"ContentType" = "application/zip";}
            StandardBlobTier = 'Hot'
          }

          Set-AzStorageBlobContent @Scripts
    }

    end {
        Write-Debug -Message "Upload-Dependencies end processing"
    }

}

Set-Dependencies
#Requires -Version 7.0
#Requires -Modules Az.Accounts, Az.Storage

param (
    [Parameter(Mandatory = $true)]
    $ResourceGroupName,

    [Parameter(Mandatory = $true)]
    $AccountName,

    [Parameter(Mandatory = $true)]
    $ContainerName,

    [Parameter(Mandatory = $true)]
    $FilePath
)

begin {
    Write-Debug -Message "Set-Dependencies begin processing"
}

process {
    try {
        $context = (Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $AccountName).Context
        Set-AzStorageBlobContent -File $filePath -Container $ContainerName -Blob $fileName -Context $context -Properties @{ "ContentType" = "application/zip" } -StandardBlobTier 'Hot'
    }
    catch {
        Write-Error -Message "Error setting dependencies: $($_.Exception.Message)"
    }
}

end {
    Write-Debug -Message "Set-Dependencies end processing"
}

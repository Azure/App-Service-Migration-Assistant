#Requires -Version 4.0

param (
    [Parameter()]
    [String]$AccountName,

    [Parameter()]
    [String]$AccountKey,

    [Parameter()]
    [String]$ContainerName
)

function New-Request {

    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("GET", "PUT")]
        [String]$Method,

        [Parameter(Mandatory = $true)]
        [String]$AccountName,

        [Parameter(Mandatory = $true)]
        [String]$AccountKey,

        [Parameter(Mandatory = $true)]
        [String]$ContainerName,

        [Parameter(Mandatory = $false)]
        [String]$FilePath,

        [Parameter(Mandatory = $true)]
        [String]$BlobName
    )

    process {
        $blobServiceEndpoint = "https://$AccountName.blob.core.windows.net"
        $blobUri = "$blobServiceEndpoint/$containerName/$BlobName"

        $version = "2017-04-17"

        $resource = "$containerName/$BlobName"
        $dateTime = (Get-Date).ToUniversalTime().ToString('R')

        if ($Method -eq "PUT") {
            $body = Get-Content -Path "$FilePath" -Raw
            $bytes = ([System.Text.Encoding]::UTF8.GetBytes($body))
            $contentLength = $bytes.Length
        }

        $canonheaders = "x-ms-blob-type:BlockBlob`nx-ms-date:$dateTime`nx-ms-version:$version`n"
        $stringToSign = "$method`n`n`n$contentLength`n`n`n`n`n`n`n`n`n$canonheaders/$AccountName/$resource"

        $hmacsha = New-Object System.Security.Cryptography.HMACSHA256
        $hmacsha.key = [Convert]::FromBase64String($accountKey)
        $signature = $hmacsha.ComputeHash([Text.Encoding]::UTF8.GetBytes($stringToSign))
        $signature = [Convert]::ToBase64String($signature)

        $headers = @{
            'x-ms-date'      = $dateTime
            Authorization    = "SharedKey $($accountName):$signature"
            "x-ms-version"   = $version
            'x-ms-blob-type' = "BlockBlob"
        }

        if ($method -eq "PUT" ) {
            $props = @{
                Uri     = $blobUri
                Method  = $method
                Headers = $headers
                Body    = $body
            }
        }
        else {
            $props = @{
                Uri     = $blobUri
                Method  = $method
                Headers = $headers
            }
        }

        return $props
    }

}

# Dependencies
try {
    $request = New-Request `
        -Method GET `
        -AccountName $AccountName `
        -AccountKey $AccountKey `
        -ContainerName $ContainerName `
        -BlobName "AppServiceMigrationScripts.zip"

    Invoke-RestMethod @request -OutFile "$PSScriptRoot\AppServiceMigrationScripts.zip"

    Expand-Archive -Path "$PSScriptRoot\AppServiceMigrationScripts.zip" -DestinationPath "$PSScriptRoot" -Force
}
catch {
    $Host.UI.WriteErrorLine("Assessment failed (dependencies) [$($_.Exception.Message)]")
    return
}

# Assessment
try {
    . $PSScriptRoot\Get-SiteReadiness.ps1 | Out-Null
}
catch {
    $Host.UI.WriteErrorLine("Assessment failed (readiness) [$($_.Exception.Message)]")
    return
}

# Metadata
try {
    $metadata = `
        Invoke-RestMethod `
        -Method GET `
        -Headers @{ "Metadata" = "true" } `
        -Uri "http://169.254.169.254/metadata/instance?api-version=2021-02-01"
}
catch {
    $Host.UI.WriteErrorLine("Assessment failed (metadata) [$($_.Exception.Message)]")
    return
}

# Upload
try {
    $request = New-Request `
        -Method PUT `
        -AccountName $AccountName `
        -AccountKey $AccountKey `
        -ContainerName $ContainerName `
        -FilePath "$PSScriptRoot\ReadinessResults.json" `
        -BlobName "$($metadata.compute.resourceGroupName)/ReadinessResults_$($($($env:computername).ToLower()).Trim()).json"

    Invoke-RestMethod @request
}
catch {
    $Host.UI.WriteErrorLine("Assessment failed (upload) [$($_.Exception.Message)]")
    return
}

# Result
$Host.UI.WriteLine("Assessment completed")

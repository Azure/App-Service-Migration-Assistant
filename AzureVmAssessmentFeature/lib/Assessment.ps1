#requires -version 4.0

param (
    [Parameter()]
    $AccountName,

    [Parameter()]
    $AccountKey,

    [Parameter()]
    $ContainerName,

    [Parameter()]
    $VMResourceGroupName
)

#
# Helper
#

function New-Request {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("GET", "PUT")]
        $Method,

        [Parameter(Mandatory = $true)]
        $AccountName,

        [Parameter(Mandatory = $true)]
        $AccountKey,

        [Parameter(Mandatory = $true)]
        $ContainerName,

        [Parameter(Mandatory = $false)]
        $FilePath,

        [Parameter(Mandatory = $true)]
        $BlobName
    )

    process {
        $method = $Method
        $uri = New-Object System.Uri -ArgumentList "https://$AccountName.blob.core.windows.net/$ContainerName/$BlobName"

        $headers = @{}
        $headers.Add("x-ms-version", "2014-02-14")
        $headers.Add("x-ms-date", (Get-Date -Format r).ToString())
        $headers.Add("x-ms-blob-type", "BlockBlob")

        if ( $method -eq "PUT" ) {
            $body = Get-Content -Path "$FilePath" -Raw
            $bytes = ([System.Text.Encoding]::UTF8.GetBytes($body))
            $contentLength = $bytes.Length
        }

        $signatureString = "$method$([char]10)$([char]10)$([char]10)$contentLength$([char]10)$([char]10)$([char]10)$([char]10)$([char]10)$([char]10)$([char]10)$([char]10)$([char]10)"
        $signatureString += "x-ms-blob-type:" + $headers["x-ms-blob-type"] + "$([char]10)"
        $signatureString += "x-ms-date:" + $headers["x-ms-date"] + "$([char]10)"
        $signatureString += "x-ms-version:" + $headers["x-ms-version"] + "$([char]10)"
        $signatureString += "/" + $AccountName + $uri.AbsolutePath

        $dataToMac = [System.Text.Encoding]::UTF8.GetBytes($signatureString)
        $accountKeyBytes = [System.Convert]::FromBase64String($AccountKey)

        $hmac = New-Object System.Security.Cryptography.HMACSHA256((, $accountKeyBytes))
        $signature = [System.Convert]::ToBase64String($hmac.ComputeHash($dataToMac))

        $headers.Add("Authorization", "SharedKey " + $AccountName + ":" + $signature)

        if ($method -eq "PUT" ) {
            $props = @{
                Uri     = $uri
                Method  = $method
                Headers = $headers
                Body    = $body
            }
        }
        else {
            $props = @{
                Uri     = $uri
                Method  = $method
                Headers = $headers
            }
        }

        return $props
    }
}

function Test-Prerequisites {
    process {
        $windowsFeature = Get-WindowsFeature | Where-Object -FilterScript { $_.Name -eq "Web-Server" -and $_.Installed -eq "True" }

        if ($null -eq $windowsFeature) {
            Write-Error "Assessment terminated due to missing Windows Feature"
        }
    }
}

function Get-AssessmentDependencies {
    process {
        # Download assessment scripts from Blob storage and save to local file system

        Write-Output "Downloading assessment scripts from blob..."

        $request = New-Request `
            -Method "GET" `
            -AccountName $accountName `
            -AccountKey $accountKey `
            -ContainerName $containerName `
            -BlobName "AppServiceMigrationScripts.zip"

        try {
            Invoke-RestMethod @request -OutFile ".\AppServiceMigrationScripts.zip"
            Expand-Archive -Path ".\AppServiceMigrationScripts.zip" -DestinationPath ".\" -Force
        }
        catch {
            Write-Error -Message "Unable to download assessment scripts from storage - $($_.Exception.Message)))"
        }
    }
}

function Invoke-AssessmentScripts {
    process {
        $ReadinessResultsPath = .\Get-SiteReadiness.ps1
    }
}

function Set-AssessmentContent {
    process {
        #Get host name
        $hostName = $env:computername
        $hostName = $hostName.ToLower()
        $hostName = $hostName.Trim()

        $request = New-Request `
            -Method "PUT" `
            -AccountName $accountName `
            -AccountKey $accountKey `
            -ContainerName $containerName `
            -FilePath ".\ReadinessResults.json" `
            -BlobName "$($VMResourceGroupName)\ReadinessResults_${hostName}.json"

        Invoke-RestMethod @request

    }
}

function Remove-AssessmentDependencies {
    process {

    }
}

#
# Invocation
#

try {
    Write-Verbose "Running prerequisites tests"
    Test-Prerequisites

    Write-Verbose "Downloading dependencies"
    Get-AssessmentDependencies

    Write-Verbose "Starting assessment"
    Invoke-AssessmentScripts

    Write-Verbose "Uploading assessment artifacts"
    Set-AssessmentContent

    Write-Output "Assessment completed"
}
catch {
    Write-Warning -Message "Assessment terminated"
    Write-Error -Message $_.Exception.Message
}

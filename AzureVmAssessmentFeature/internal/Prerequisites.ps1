#Requires -Version 3.0

$system = Get-WmiObject Win32_OperatingSystem
$shell = $PSVersionTable

# OS Version
if ([System.Version]"$($system.Version)" -lt [System.Version]"6.1") {
    $Host.UI.WriteErrorLine("Unsupported OS Version [$($system.Caption) - $($system.Version)]")
    return
}

# OS Product Type
if ($system.ProductType -ne 3) {
    # TODO: Install WMF 4.0
    $Host.UI.WriteErrorLine("Unsupported OS Product Type [$($system.Caption) - $($system.ProductType)]")
    return
}

# PowerShell Version
if ($shell.PSVersion.Major -lt 5) {
    $Host.UI.WriteErrorLine("Unsupported PowerShell Version [$($shell.PSVersion)]")
    return
}

# Windows Feature
$feature = Get-WindowsFeature | Where-Object -FilterScript { $_.Name -eq "Web-Server" -and $_.Installed -eq "True" }
if ($null -eq $feature) {
    $Host.UI.WriteErrorLine("Missing Windows Feature [Web-Server]")
    return
}

# TLS Version
# try {
#     $response = Invoke-WebRequest -Uri "status.dev.azure.com" -UseBasicParsing
# }
# catch {
#     $Host.UI.WriteErrorLine("Missing TLS 1.2 Support [SecurityProtocol - $([Net.ServicePointManager]::SecurityProtocol)]")
# }

# Result
$Host.UI.WriteLine("Success")

# Vigor Edge Gateway Daemon — Windows Service Installer
# Requires Administrator privileges

$ErrorActionPreference = "Stop"

Write-Host "=== Installing Vigor Edge Gateway Daemon (Windows) ===" -ForegroundColor Green

# Check Administrator Privilege
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Error: Please run install.ps1 from an Administrator PowerShell console."
    exit 1
}

# Directories
$installDir = "C:\Program Files\VigorLabs\Gateway"
$configDir = "C:\ProgramData\VigorLabs\Gateway"
$configFile = "$configDir\config.json"
$binaryPath = "$installDir\gateway.exe"

New-Item -ItemType Directory -Force -Path $installDir | Out-Null
New-Item -ItemType Directory -Force -Path $configDir | Out-Null

# Verify checksum if SHA256SUMS exists
if (Test-Path "SHA256SUMS") {
    Write-Host "Verifying artifact SHA256 checksum..." -ForegroundColor Yellow
    $expectedHash = (Get-Content SHA256SUMS | Select-String "gateway.exe").ToString().Split(" ")[0]
    $actualHash = (Get-FileHash bin\gateway.exe -Algorithm SHA256).Hash.ToLower()
    if ($expectedHash -and ($expectedHash.ToLower() -ne $actualHash)) {
        Write-Error "Checksum verification FAILED for gateway.exe!"
        exit 1
    }
    Write-Host "Checksum verification PASSED." -ForegroundColor Green
}

# Copy Binary
Copy-Item -Path "bin\gateway.exe" -Destination $binaryPath -Force
Write-Host "Installed binary to $binaryPath"

# Copy Config Template
if (-not (Test-Path $configFile)) {
    Copy-Item -Path "config.json.template" -Destination $configFile -Force
    Write-Host "Installed default config to $configFile"
}

# Service Management
$serviceName = "VigorGateway"
$existingService = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

if ($existingService) {
    Write-Host "Stopping existing $serviceName service..." -ForegroundColor Yellow
    Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
    sc.exe delete $serviceName | Out-Null
    Start-Sleep -Seconds 2
}

Write-Host "Registering Windows Service '$serviceName'..." -ForegroundColor Green
New-Service -Name $serviceName `
            -BinaryPathName "`"$binaryPath`" --config `"$configFile`" --service" `
            -DisplayName "Vigor Edge Gateway Service" `
            -Description "Manages Edge RTSP streams and P2P WebRTC connectivity for Vigor Labs." `
            -StartupType Automatic | Out-Null

Write-Host "=== Vigor Edge Gateway Service Installed Successfully ===" -ForegroundColor Green
Write-Host "Next steps:"
Write-Host "1. Configure $configFile with your Gateway Token and camera streams."
Write-Host "2. Start service: Start-Service VigorGateway"

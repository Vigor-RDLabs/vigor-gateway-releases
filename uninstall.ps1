# Vigor Edge Gateway Daemon — Windows Service Uninstaller
# Requires Administrator privileges

param (
    [switch]$Purge
)

$ErrorActionPreference = "Stop"

Write-Host "=== Uninstalling Vigor Edge Gateway Daemon (Windows) ===" -ForegroundColor Green

# Check Administrator Privilege
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Error: Please run uninstall.ps1 from an Administrator PowerShell console."
    exit 1
}

$installDir = "C:\Program Files\VigorLabs\Gateway"
$configDir = "C:\ProgramData\VigorLabs\Gateway"
$serviceName = "VigorGateway"

# 1. Stop and Delete Service
$existingService = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
if ($existingService) {
    Write-Host "Stopping and deleting '$serviceName' service..." -ForegroundColor Yellow
    Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
    sc.exe delete $serviceName | Out-Null
    Start-Sleep -Seconds 2
}

# 2. Remove Binary and Install Directory
if (Test-Path $installDir) {
    Write-Host "Removing installation directory $installDir..." -ForegroundColor Yellow
    Remove-Item -Path $installDir -Recurse -Force
}

# 3. Remove Config Directory (if -Purge is specified)
if (Test-Path $configDir) {
    if ($Purge) {
        Write-Host "Purging config directory $configDir..." -ForegroundColor Yellow
        Remove-Item -Path $configDir -Recurse -Force
    } else {
        Write-Host "Configuration files left in $configDir (run with '-Purge' to delete)." -ForegroundColor White
    }
}

Write-Host "=== Vigor Edge Gateway Service Uninstalled Successfully ===" -ForegroundColor Green

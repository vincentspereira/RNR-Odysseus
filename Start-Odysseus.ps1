#Requires -Version 5.1
<#
  Odysseus - Quick Launcher
  Double-click to start Odysseus and open it in your browser.
  Run Install-Odysseus.ps1 first if you haven't already.
#>

param(
    [int]$Port = 7000,
    [string]$BindHost = "127.0.0.1"
)

$ErrorActionPreference = "Stop"
$ScriptDir = $PSScriptRoot
Set-Location -Path $ScriptDir

$venvPy = Join-Path $ScriptDir "venv\Scripts\python.exe"

if (-not (Test-Path $venvPy)) {
    Write-Host ""
    Write-Host "Odysseus is not installed yet." -ForegroundColor Yellow
    Write-Host "Please run Install-Odysseus.ps1 first." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "  Starting Odysseus AI Workspace..." -ForegroundColor Cyan
Write-Host "  http://localhost:$Port" -ForegroundColor White
Write-Host "  Press Ctrl+C to stop" -ForegroundColor Gray
Write-Host ""

# Open browser after a short delay
$url = "http://localhost:$Port"
Start-Job -ScriptBlock {
    param($u)
    Start-Sleep -Seconds 3
    Start-Process $u
} -ArgumentList $url | Out-Null

& $venvPy -m uvicorn app:app --host $BindHost --port $Port

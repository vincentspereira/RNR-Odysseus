#Requires -Version 5.1
<#
  Odysseus - Windows Installer
  Double-click to install dependencies, then launch the app in your browser.
  Safe to re-run after updates.
#>

param(
    [int]$Port = 7000,
    [string]$BindHost = "127.0.0.1",
    [switch]$SkipBrowser
)

$ErrorActionPreference = "Stop"
$ScriptDir = $PSScriptRoot

function Write-Step($msg) {
    Write-Host ""
    Write-Host ("==> " + $msg) -ForegroundColor Cyan
}

function Write-OK($msg) {
    Write-Host ("    [OK] " + $msg) -ForegroundColor Green
}

function Write-Warn($msg) {
    Write-Host ("    [WARN] " + $msg) -ForegroundColor Yellow
}

function Fail($msg) {
    Write-Host ""
    Write-Host ("ERROR: " + $msg) -ForegroundColor Red
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

# ── BANNER ──
Write-Host ""
Write-Host "  ==========================================" -ForegroundColor DarkCyan
Write-Host "   Odysseus - Self-Hosted AI Workspace" -ForegroundColor Cyan
Write-Host "   Installer / Launcher" -ForegroundColor Cyan
Write-Host "  ==========================================" -ForegroundColor DarkCyan
Write-Host ""

Set-Location -Path $ScriptDir

# ── STEP 1: Find Python 3.11+ ──
Write-Step "Checking Python installation"

function Get-PyVersion($exe, $args_) {
    try { return (& $exe @args_ -c "import sys; print('.'.join(map(str,sys.version_info[:3])))" 2>$null).Trim() }
    catch { return $null }
}

$pyExe = $null; $pyArgs = @(); $pyVersion = $null
$launcher = Get-Command py -ErrorAction SilentlyContinue
if ($launcher) {
    foreach ($v in @("-3.13", "-3.12", "-3.11")) {
        $ver = Get-PyVersion $launcher.Source @($v)
        if ($ver) { $pyExe = $launcher.Source; $pyArgs = @($v); $pyVersion = $ver; break }
    }
}
if (-not $pyExe) {
    $py = Get-Command python -ErrorAction SilentlyContinue
    if ($py) {
        $ver = Get-PyVersion $py.Source @()
        if ($ver) {
            $parts = $ver.Split('.'); $maj = [int]$parts[0]; $min = [int]$parts[1]
            if ($maj -gt 3 -or ($maj -eq 3 -and $min -ge 11)) {
                $pyExe = $py.Source; $pyVersion = $ver
            }
        }
    }
}
if (-not $pyExe) {
    Fail "Python 3.11 or newer is required.`nDownload from https://www.python.org/downloads/`nInstall, then re-run this script."
}
Write-OK "Python $pyVersion found"

# ── STEP 2: Create venv ──
$venvPy = Join-Path $ScriptDir "venv\Scripts\python.exe"
if (-not (Test-Path $venvPy)) {
    Write-Step "Creating virtual environment"
    & $pyExe @pyArgs -m venv venv
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $venvPy)) { Fail "Failed to create virtual environment." }
    Write-OK "Virtual environment created"
} else {
    Write-OK "Virtual environment already exists"
}

# ── STEP 3: Install / update dependencies ──
Write-Step "Installing dependencies (first run takes a few minutes)"
& $venvPy -m pip install --upgrade pip --quiet
& $venvPy -m pip install -r requirements.txt --quiet
if ($LASTEXITCODE -ne 0) { Fail "Dependency install failed. Check the output above for details." }

# Install PyMuPDF for PDF viewer support (optional but recommended)
Write-Host "    Installing PDF viewer support (PyMuPDF)..." -ForegroundColor Gray
& $venvPy -m pip install PyMuPDF --quiet 2>$null
Write-OK "Dependencies installed"

# ── STEP 4: First-time setup ──
Write-Step "Running first-time setup"
& $venvPy setup.py
if ($LASTEXITCODE -ne 0) { Fail "setup.py failed. Check the output above." }

# ── STEP 5: Create desktop shortcut ──
Write-Step "Creating desktop shortcut"
try {
    $desktopPath = [Environment]::GetFolderPath("Desktop")
    $shortcutPath = Join-Path $desktopPath "Odysseus AI.lnk"
    if (-not (Test-Path $shortcutPath)) {
        $shell = New-Object -ComObject WScript.Shell
        $sc = $shell.CreateShortcut($shortcutPath)
        $sc.TargetPath = "powershell.exe"
        $sc.Arguments = "-ExecutionPolicy Bypass -WindowStyle Normal -File `"$ScriptDir\Start-Odysseus.ps1`""
        $sc.WorkingDirectory = $ScriptDir
        $sc.Description = "Launch Odysseus AI Workspace"
        $sc.IconLocation = "powershell.exe,0"
        $sc.Save()
        Write-OK "Desktop shortcut created: Odysseus AI"
    } else {
        Write-OK "Desktop shortcut already exists"
    }
} catch {
    Write-Warn "Could not create desktop shortcut: $_"
}

# ── STEP 6: Launch ──
Write-Step "Starting Odysseus at http://${BindHost}:${Port}"
Write-Host ""
Write-Host "  - Open your browser to: http://localhost:$Port" -ForegroundColor White
Write-Host "  - Log in with your admin credentials" -ForegroundColor White
Write-Host "  - Press Ctrl+C in this window to stop the server" -ForegroundColor White
Write-Host ""

# Open browser after a short delay
if (-not $SkipBrowser) {
    $url = "http://localhost:$Port"
    Start-Job -ScriptBlock {
        param($u)
        Start-Sleep -Seconds 4
        Start-Process $u
    } -ArgumentList $url | Out-Null
}

# Start the server
& $venvPy -m uvicorn app:app --host $BindHost --port $Port

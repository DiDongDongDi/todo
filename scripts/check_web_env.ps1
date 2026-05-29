# Web (Chrome) dev environment check
# Usage: powershell -ExecutionPolicy Bypass -File scripts/check_web_env.ps1

. (Join-Path $PSScriptRoot "_flutter_ps_helpers.ps1")
Initialize-ScriptConsoleUtf8

$ErrorActionPreference = "Continue"
$script:ok = 0
$script:fail = 0
$script:warn = 0

function Test-ItemOk($name, $condition, $hint) {
    if ($condition) {
        Write-Host "[OK]   $name" -ForegroundColor Green
        $script:ok++
    } else {
        Write-Host "[FAIL] $name" -ForegroundColor Red
        if ($hint) { Write-Host "       $hint" -ForegroundColor DarkGray }
        $script:fail++
    }
}

function Test-ItemWarn($name, $condition, $hint) {
    if ($condition) {
        Write-Host "[OK]   $name" -ForegroundColor Green
        $script:ok++
    } else {
        Write-Host "[WARN] $name" -ForegroundColor Yellow
        if ($hint) { Write-Host "       $hint" -ForegroundColor DarkGray }
        $script:warn++
    }
}

Write-Host ""
Write-Host "=== Todo Web (Chrome) Environment Check ===" -ForegroundColor Cyan
Write-Host ""

$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
Test-ItemOk "flutter in PATH" ($null -ne $flutterCmd) "Install Flutter and add to PATH"

if ($flutterCmd) {
    $fv = (Get-FlutterOutput -FlutterArgs @("--version") | Select-Object -First 1)
    if ($fv) { Write-Host "       $fv" -ForegroundColor DarkGray }
}

# Web enabled
$webEnabled = $false
if ($flutterCmd) {
    $cfg = (Get-FlutterOutput -FlutterArgs @("config")) -join "`n"
    $webEnabled = $cfg -match "enable-web:\s*true" -or $cfg -notmatch "enable-web:\s*false"
}
Test-ItemWarn "Flutter web enabled" $webEnabled "Run: flutter config --enable-web"

# Chrome / Edge
$chromePaths = @(
    "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
    "${env:ProgramFiles}\Microsoft\Edge\Application\msedge.exe"
)
$browserFound = $chromePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
Test-ItemOk "Chrome or Edge installed" ($null -ne $browserFound) "Install Google Chrome"

# flutter devices - web
$hasWebDevice = $false
if ($flutterCmd) {
    $devOut = (Get-FlutterOutput -FlutterArgs @("devices")) -join "`n"
    $hasWebDevice = $devOut -match "chrome\s+.*web-javascript" -or $devOut -match "edge\s+.*web-javascript"
}
Test-ItemOk "flutter devices lists web target" $hasWebDevice "Reopen terminal after installing Chrome"

$repoRoot = Split-Path $PSScriptRoot -Parent
$appWeb = Join-Path $repoRoot "app\web\index.html"
$buildWeb = Join-Path $repoRoot "app\build\web\index.html"
Test-ItemOk "app/web/index.html exists" (Test-Path $appWeb) "Run flutter create in app/ if missing"
Test-ItemWarn "build/web exists (optional)" (Test-Path $buildWeb) "Run: cd app; flutter build web"

Write-Host ""
Write-Host "--- flutter doctor (Chrome line) ---" -ForegroundColor Cyan
Write-Host ""
if ($flutterCmd) {
    Get-FlutterOutput -FlutterArgs @("doctor") | Where-Object {
        $_ -match "Chrome|Edge|Web|Flutter"
    } | ForEach-Object {
        if ($_ -match 'Flutter assets will be downloaded from') {
            Write-Host "       $_" -ForegroundColor DarkGray
        } else {
            Write-Host $_
        }
    }
}

Write-Host ""
Write-Host "--- flutter devices ---" -ForegroundColor Cyan
Write-Host ""
if ($flutterCmd) {
    Write-FlutterOutput -FlutterArgs @("devices")
}

Write-Host ""
Write-Host "=== Summary: OK=$($script:ok)  FAIL=$($script:fail)  WARN=$($script:warn) ===" -ForegroundColor Cyan
Write-Host ""

if ($script:fail -gt 0) {
    Write-Host "See docs/WEB-SETUP-CHECKLIST.md user checklist U1-U5" -ForegroundColor Yellow
    exit 1
}
Write-Host "Web env ready. Try: cd app; flutter run -d chrome" -ForegroundColor Green
exit 0

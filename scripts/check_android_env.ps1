# Android dev environment check
# Usage: powershell -ExecutionPolicy Bypass -File scripts/check_android_env.ps1

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
Write-Host "=== Todo Android Environment Check ===" -ForegroundColor Cyan
Write-Host ""

# Flutter
$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
Test-ItemOk "flutter in PATH" ($null -ne $flutterCmd) "Add Flutter bin to PATH"

if ($flutterCmd) {
    $fv = (Get-FlutterOutput -FlutterArgs @("--version") | Select-Object -First 1)
    if ($fv) { Write-Host "       $fv" -ForegroundColor DarkGray }
}

# Java
$javaHome = $env:JAVA_HOME
$javaCmd = Get-Command java -ErrorAction SilentlyContinue
$javaOk = ($javaHome -and (Test-Path $javaHome)) -or ($null -ne $javaCmd)
Test-ItemOk "JAVA_HOME or java" $javaOk "Install Android Studio (includes JDK)"
if ($javaHome) { Write-Host "       JAVA_HOME=$javaHome" -ForegroundColor DarkGray }

# Android Studio JBR hint
$jbr = "C:\Program Files\Android\Android Studio\jbr"
if (-not $javaOk -and (Test-Path $jbr)) {
    Write-Host "       Hint: set JAVA_HOME=$jbr" -ForegroundColor DarkYellow
}

# Android SDK
$sdk = $env:ANDROID_HOME
if (-not $sdk) { $sdk = "$env:LOCALAPPDATA\Android\Sdk" }
$sdkExists = Test-Path $sdk
Test-ItemOk "Android SDK folder" $sdkExists "Install Android Studio with SDK"

$adb = $null
if ($sdkExists) {
    $adb = Join-Path $sdk "platform-tools\adb.exe"
}
Test-ItemOk "adb" (($null -ne $adb) -and (Test-Path $adb)) "Install SDK Platform-Tools"

$cmdlineOk = $false
if ($sdkExists) {
    $cmdlineOk = (Test-Path (Join-Path $sdk "cmdline-tools\latest")) -or
                 (Test-Path (Join-Path $sdk "cmdline-tools\latest\bin\sdkmanager.bat"))
}
Test-ItemOk "cmdline-tools" $cmdlineOk "SDK Manager: Android SDK Command-line Tools"

# Connected devices
if (($null -ne $adb) -and (Test-Path $adb)) {
    $lines = & $adb devices 2>&1
    $deviceLines = $lines | Where-Object { $_ -match "`tdevice$" }
    Test-ItemWarn "Android device connected" ($deviceLines.Count -gt 0) "Enable USB debugging (checklist U4-U7)"
    foreach ($line in $deviceLines) {
        Write-Host "       $line" -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host "--- flutter doctor ---" -ForegroundColor Cyan
Write-Host ""
if ($flutterCmd) {
    Write-FlutterOutput -FlutterArgs @("doctor")
} else {
    Write-Host "Skipped (flutter not found)" -ForegroundColor Yellow
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
    Write-Host "Complete user checklist U1-U3 in docs/ANDROID-SETUP-CHECKLIST.md" -ForegroundColor Yellow
    exit 1
}
if ($script:warn -gt 0) {
    Write-Host "Build env may be OK. After phone connected: cd app; flutter run -d android" -ForegroundColor Yellow
    exit 0
}
Write-Host "Checks passed (device may still be needed). Try: cd app; flutter run -d android" -ForegroundColor Green
exit 0

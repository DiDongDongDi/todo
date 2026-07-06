# 生成本地 Android Release 签名密钥库（仅需执行一次，请妥善保管）
# Usage: powershell -ExecutionPolicy Bypass -File scripts/generate_android_keystore.ps1

$ErrorActionPreference = "Stop"

$keystorePath = Join-Path $PSScriptRoot "..\app\android\app\todo-release.keystore"
$alias = "todo-release"

if (Test-Path $keystorePath) {
    Write-Host "Keystore already exists: $keystorePath" -ForegroundColor Yellow
    Write-Host "Delete it first if you need to regenerate." -ForegroundColor DarkGray
    exit 1
}

$keytool = Get-Command keytool -ErrorAction SilentlyContinue
if (-not $keytool) {
    throw "keytool not found. Install JDK (Android Studio bundled JDK is fine) and add bin to PATH."
}

Write-Host ""
Write-Host "=== Generate Android Release Keystore ===" -ForegroundColor Cyan
Write-Host "Output: $keystorePath"
Write-Host "Alias:  $alias"
Write-Host ""
Write-Host "You will be prompted for keystore password, key password, and certificate info."
Write-Host "Use the SAME password for both if unsure (CI only needs one pair of secrets)."
Write-Host ""

& keytool -genkeypair -v `
    -keystore $keystorePath `
    -alias $alias `
    -keyalg RSA `
    -keysize 2048 `
    -validity 10000

Write-Host ""
Write-Host "[OK] Keystore created." -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Back up todo-release.keystore and passwords offline (loss = cannot update app on Play Store)."
Write-Host "2. For GitHub Actions, base64-encode the keystore and add Secrets (see docs/RELEASE.md):"
Write-Host ""
Write-Host '   [Convert]::ToBase64String([IO.File]::ReadAllBytes("' + $keystorePath + '")) | Set-Clipboard'
Write-Host ""
Write-Host "3. Add Secrets: ANDROID_KEYSTORE_BASE64, ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS, ANDROID_KEY_PASSWORD"

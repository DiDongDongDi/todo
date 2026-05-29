# 初始化 Flutter 多平台目录
# 需已安装 Flutter SDK 并加入 PATH

param(
    [string]$Org = "com.todo.app"
)

$ErrorActionPreference = "Stop"
$appDir = Join-Path $PSScriptRoot "..\app" | Resolve-Path

Push-Location $appDir
try {
    flutter create . --org $Org --project-name todo_app
    flutter pub get
    Write-Host "平台目录已生成。运行: flutter run" -ForegroundColor Green
} finally {
    Pop-Location
}

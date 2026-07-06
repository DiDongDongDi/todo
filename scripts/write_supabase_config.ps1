# 从环境变量生成 app/lib/core/config/supabase_config.dart（供 CI 与本地发布构建使用）
# Usage: $env:SUPABASE_URL="..."; $env:SUPABASE_ANON_KEY="..."; .\scripts\write_supabase_config.ps1

param(
    [string]$OutPath = (Join-Path $PSScriptRoot "..\app\lib\core\config\supabase_config.dart")
)

$ErrorActionPreference = "Stop"

if (-not $env:SUPABASE_URL) { throw "SUPABASE_URL is required" }
if (-not $env:SUPABASE_ANON_KEY) { throw "SUPABASE_ANON_KEY is required" }

$dir = Split-Path $OutPath -Parent
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

$content = @"
/// 由 scripts/write_supabase_config 生成，请勿手动编辑后提交。
class SupabaseConfig {
  static const String url = '$($env:SUPABASE_URL)';
  static const String anonKey = '$($env:SUPABASE_ANON_KEY)';
}
"@

Set-Content -Path $OutPath -Value $content -Encoding UTF8 -NoNewline
Write-Host "Wrote $OutPath"

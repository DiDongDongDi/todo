#!/usr/bin/env bash
# 从环境变量生成 app/lib/core/config/supabase_config.dart（供 CI 与本地发布构建使用）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/app/lib/core/config/supabase_config.dart}"
URL="${SUPABASE_URL:?SUPABASE_URL is required}"
KEY="${SUPABASE_ANON_KEY:?SUPABASE_ANON_KEY is required}"

mkdir -p "$(dirname "$OUT")"

cat > "$OUT" <<EOF
/// 由 scripts/write_supabase_config 生成，请勿手动编辑后提交。
class SupabaseConfig {
  static const String url = '$URL';
  static const String anonKey = '$KEY';
}
EOF

echo "Wrote $OUT"

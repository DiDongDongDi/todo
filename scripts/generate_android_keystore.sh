#!/usr/bin/env bash
# 生成本地 Android Release 签名密钥库（仅需执行一次，请妥善保管）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KEYSTORE="$ROOT/app/android/app/todo-release.keystore"
ALIAS="todo-release"

if [[ -f "$KEYSTORE" ]]; then
  echo "Keystore already exists: $KEYSTORE"
  echo "Delete it first if you need to regenerate."
  exit 1
fi

if ! command -v keytool >/dev/null 2>&1; then
  echo "keytool not found. Install JDK and add bin to PATH."
  exit 1
fi

echo ""
echo "=== Generate Android Release Keystore ==="
echo "Output: $KEYSTORE"
echo "Alias:  $ALIAS"
echo ""
echo "You will be prompted for keystore password, key password, and certificate info."
echo ""

keytool -genkeypair -v \
  -keystore "$KEYSTORE" \
  -alias "$ALIAS" \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000

echo ""
echo "[OK] Keystore created."
echo ""
echo "Next: base64-encode for GitHub Secrets (see docs/RELEASE.md):"
echo "  base64 -w0 $KEYSTORE"

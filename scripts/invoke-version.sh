#!/usr/bin/env bash
# バージョン番号またはAlias名を指定して裏から直接invokeする(本番ルーティングを経由しない)。
# Usage: scripts/invoke-version.sh <version-or-alias> [payload-json] [function-name]
set -euo pipefail
QUALIFIER="${1:?Usage: $0 <version-or-alias> [payload-json] [function-name]}"
PAYLOAD="${2:-{}}"
FUNCTION_NAME="${3:-${FUNCTION_NAME:-lambda-blue-green-demo}}"

OUT_FILE="$(mktemp)"
trap 'rm -f "$OUT_FILE"' EXIT

aws lambda invoke \
  --function-name "$FUNCTION_NAME" \
  --qualifier "$QUALIFIER" \
  --cli-binary-format raw-in-base64-out \
  --payload "$PAYLOAD" \
  "$OUT_FILE"

echo "qualifier=$QUALIFIER"
cat "$OUT_FILE"
echo

#!/usr/bin/env bash
# 現在の$LATESTから新バージョン(blue/greenの実体)を発行する。
# Usage: scripts/publish-version.sh [function-name]
set -euo pipefail
FUNCTION_NAME="${1:-${FUNCTION_NAME:-lambda-blue-green-demo}}"

aws lambda publish-version \
  --function-name "$FUNCTION_NAME" \
  --query '{FunctionName:FunctionName,Version:Version,CodeSha256:CodeSha256}' \
  --output table

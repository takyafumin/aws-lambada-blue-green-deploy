#!/usr/bin/env bash
# liveエイリアスを初回作成する(初回のみ実行。以降の切替はswitch-alias.shを使う)。
# Usage: scripts/create-alias.sh <version> [alias-name] [function-name]
set -euo pipefail
VERSION="${1:?Usage: $0 <version> [alias-name] [function-name]}"
ALIAS_NAME="${2:-${ALIAS_NAME:-live}}"
FUNCTION_NAME="${3:-${FUNCTION_NAME:-lambda-blue-green-demo}}"

aws lambda create-alias \
  --function-name "$FUNCTION_NAME" \
  --name "$ALIAS_NAME" \
  --function-version "$VERSION" \
  --query '{FunctionVersion:FunctionVersion,AliasName:Name,AliasArn:AliasArn}' \
  --output table

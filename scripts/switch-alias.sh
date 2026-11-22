#!/usr/bin/env bash
# liveエイリアスの向き先を切り替える(blue→greenの一括切替、またはロールバック)。
# Usage: scripts/switch-alias.sh <version> [alias-name] [function-name]
set -euo pipefail
VERSION="${1:?Usage: $0 <version> [alias-name] [function-name]}"
ALIAS_NAME="${2:-${ALIAS_NAME:-live}}"
FUNCTION_NAME="${3:-${FUNCTION_NAME:-lambda-blue-green-demo}}"

aws lambda update-alias \
  --function-name "$FUNCTION_NAME" \
  --name "$ALIAS_NAME" \
  --function-version "$VERSION" \
  --query '{FunctionVersion:FunctionVersion,AliasName:Name,AliasArn:AliasArn}' \
  --output table

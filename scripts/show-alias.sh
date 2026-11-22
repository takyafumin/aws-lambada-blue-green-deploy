#!/usr/bin/env bash
# liveエイリアスが現在どのバージョンを指しているか確認する。
# Usage: scripts/show-alias.sh [alias-name] [function-name]
set -euo pipefail
ALIAS_NAME="${1:-${ALIAS_NAME:-live}}"
FUNCTION_NAME="${2:-${FUNCTION_NAME:-lambda-blue-green-demo}}"

aws lambda get-alias \
  --function-name "$FUNCTION_NAME" \
  --name "$ALIAS_NAME" \
  --query '{FunctionVersion:FunctionVersion,AliasName:Name,AliasArn:AliasArn}' \
  --output table

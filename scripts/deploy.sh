#!/usr/bin/env bash
# SAMでLambda関数のコード($LATEST)を更新する。
# この時点ではVersionもliveエイリアスも変わらない(blueはそのまま動き続ける)。
set -euo pipefail
cd "$(dirname "$0")/.."

sam build
sam deploy

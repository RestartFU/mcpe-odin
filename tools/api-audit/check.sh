#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
LOCK="$ROOT_DIR/upstream.lock.toml"
LOCKED=$(awk '
    $0 == "[go_raknet]" { found=1; next }
    found && /^\[/ { exit }
    found && /^commit = / { gsub(/^commit = "|".*$/, ""); print; exit }
' "$LOCK")
REPOSITORY=$(awk '
    $0 == "[go_raknet]" { found=1; next }
    found && /^\[/ { exit }
    found && /^repository = / { gsub(/^repository = "|".*$/, ""); print; exit }
' "$LOCK")
SOURCE=${GO_RAKNET_SOURCE:-"$ROOT_DIR/.cache/upstream/go-raknet"}
TEMP_DIR=
USE_SOURCE=false

if [[ -d "$SOURCE/.git" ]] &&
   [[ "$(git -C "$SOURCE" rev-parse HEAD 2>/dev/null || true)" == "$LOCKED" ]] &&
   [[ -z "$(git -C "$SOURCE" status --porcelain --untracked-files=all -- ':(top,glob)*.go')" ]]; then
    USE_SOURCE=true
fi

if [[ "$USE_SOURCE" != true ]]; then
    TEMP_DIR=$(mktemp -d /tmp/mcpe-odin-api-audit.XXXXXX)
    trap 'rm -rf -- "$TEMP_DIR"' EXIT
    SOURCE="$TEMP_DIR/go-raknet"
    GIT_CONFIG_GLOBAL=/dev/null git clone --quiet "$REPOSITORY" "$SOURCE"
    git -C "$SOURCE" checkout --quiet "$LOCKED"
fi

go run "$ROOT_DIR/tools/api-audit/main.go" \
    -source "$SOURCE" \
    -api-map "$ROOT_DIR/api-map.toml"

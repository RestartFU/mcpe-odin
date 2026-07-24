#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
UPSTREAM_DIR="$ROOT_DIR/.cache/upstream/go-raknet"
LOCKED_COMMIT=$(awk '
    $0 == "[go_raknet]" { found=1; next }
    found && /^commit = / { gsub(/^commit = "|".*$/, ""); print; exit }
' "$ROOT_DIR/upstream.lock.toml")

if [[ ! -d "$UPSTREAM_DIR/.git" ]]; then
    mkdir -p "$(dirname "$UPSTREAM_DIR")"
    git clone --filter=blob:none \
        https://github.com/Sandertv/go-raknet.git \
        "$UPSTREAM_DIR"
fi
git -C "$UPSTREAM_DIR" fetch --quiet origin "$LOCKED_COMMIT"
git -C "$UPSTREAM_DIR" checkout --quiet --detach "$LOCKED_COMMIT"

ORACLE_PACKAGE="$UPSTREAM_DIR/cmd/mcpe-odin-oracle"
mkdir -p "$ORACLE_PACKAGE"
cp "$ROOT_DIR/tests/differential/go-raknet-oracle/main.go" \
    "$ORACLE_PACKAGE/main.go"

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

(
    cd "$UPSTREAM_DIR"
    go build -trimpath -o "$WORK_DIR/go-oracle" ./cmd/mcpe-odin-oracle
)
"$ROOT_DIR/tools/odinw" build raknet-fixtures \
    -out:"$WORK_DIR/odin-oracle"

"$WORK_DIR/go-oracle" >"$WORK_DIR/go.txt"
"$WORK_DIR/odin-oracle" >"$WORK_DIR/odin.txt"
diff -u "$WORK_DIR/go.txt" "$WORK_DIR/odin.txt"
printf 'RakNet message differential fixtures match %s\n' "$LOCKED_COMMIT"

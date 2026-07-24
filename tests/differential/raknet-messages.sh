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
if ! git -C "$UPSTREAM_DIR" cat-file -e "${LOCKED_COMMIT}^{commit}" 2>/dev/null; then
    git -C "$UPSTREAM_DIR" fetch --quiet origin "$LOCKED_COMMIT"
fi
git -C "$UPSTREAM_DIR" checkout --quiet --detach "$LOCKED_COMMIT"

ORACLE_PACKAGE="$UPSTREAM_DIR/cmd/mcpe-odin-oracle"
WIRE_FIXTURE="$UPSTREAM_DIR/mcpe_odin_wire_fixtures_test.go"
mkdir -p "$ORACLE_PACKAGE"
cp "$ROOT_DIR/tests/differential/go-raknet-oracle/main.go" \
    "$ORACLE_PACKAGE/main.go"
cp "$ROOT_DIR/tests/differential/go-raknet-wire-fixtures_test.go" \
    "$WIRE_FIXTURE"

WORK_DIR=$(mktemp -d)
cleanup() {
    rm -rf "$WORK_DIR"
    rm -f "$WIRE_FIXTURE"
}
trap cleanup EXIT

(
    cd "$UPSTREAM_DIR"
    go build -trimpath -o "$WORK_DIR/go-oracle" ./cmd/mcpe-odin-oracle
)
"$ROOT_DIR/tools/odinw" build raknet-fixtures \
    -out:"$WORK_DIR/odin-oracle"

"$WORK_DIR/go-oracle" >"$WORK_DIR/go.txt"
"$WORK_DIR/odin-oracle" >"$WORK_DIR/odin.txt"
diff -u "$WORK_DIR/go.txt" "$WORK_DIR/odin.txt"
while read -r name encoded; do
    "$WORK_DIR/odin-oracle" round-trip "$name" "$encoded"
done <"$WORK_DIR/go.txt" >"$WORK_DIR/odin-round-trip.txt"
diff -u "$WORK_DIR/go.txt" "$WORK_DIR/odin-round-trip.txt"
(
    cd "$UPSTREAM_DIR"
    go test -run '^TestMcpeOdinWireFixtures$' -v
) | awk '
    /^(encapsulated_packet|reserved_reliability_packet|acknowledgement) / {
        print
    }
' >"$WORK_DIR/go-wire.txt"
"$WORK_DIR/odin-oracle" wire >"$WORK_DIR/odin-wire.txt"
diff -u "$WORK_DIR/go-wire.txt" "$WORK_DIR/odin-wire.txt"
printf 'RakNet message differential fixtures match %s\n' "$LOCKED_COMMIT"

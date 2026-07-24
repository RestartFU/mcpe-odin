#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
UPSTREAM_DIR="$ROOT_DIR/.cache/upstream/go-raknet"
LOCKED_COMMIT=$(awk '
    $0 == "[go_raknet]" { found=1; next }
    found && /^commit = / { gsub(/^commit = "|".*$/, ""); print; exit }
' "$ROOT_DIR/upstream.lock.toml")
ORACLE_PACKAGE="$UPSTREAM_DIR/cmd/mcpe-odin-oracle"
WORK_DIR=$(mktemp -d /tmp/mcpe-odin-network-benchmark.XXXXXX)
SERVER_PID=

cleanup() {
    if [[ -n "$SERVER_PID" ]]; then
        kill "$SERVER_PID" 2>/dev/null || true
    fi
    rm -rf -- "$WORK_DIR"
}
trap cleanup EXIT

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
mkdir -p "$ORACLE_PACKAGE"
cp "$ROOT_DIR/tests/differential/go-raknet-oracle/main.go" \
    "$ORACLE_PACKAGE/main.go"
(
    cd "$UPSTREAM_DIR"
    go build -trimpath -o "$WORK_DIR/go-oracle" ./cmd/mcpe-odin-oracle
)
"$ROOT_DIR/tools/odinw" build raknet-cross \
    -o:speed \
    -out:"$WORK_DIR/odin-cross"

run_stack() {
    local name=$1
    local binary=$2
    stdbuf -oL "$binary" serve-benchmark \
        >"$WORK_DIR/$name.address" 2>"$WORK_DIR/$name.err" &
    SERVER_PID=$!
    for _ in $(seq 1 100); do
        [[ -s "$WORK_DIR/$name.address" ]] && break
        sleep 0.02
    done
    if [[ ! -s "$WORK_DIR/$name.address" ]]; then
        printf '%s benchmark server failed to publish its address\n' "$name"
        cat "$WORK_DIR/$name.err"
        return 1
    fi
    local address
    address=$(head -n 1 "$WORK_DIR/$name.address")
    timeout 30 "$binary" dial-benchmark "$address" \
        >"$WORK_DIR/$name.result"
    awk '/^VmHWM:/ { print $2 }' "/proc/$SERVER_PID/status" \
        >"$WORK_DIR/$name.rss"
    wait "$SERVER_PID"
    SERVER_PID=
}

run_stack go "$WORK_DIR/go-oracle"
run_stack odin "$WORK_DIR/odin-cross"

GO_P95=$(sed -n 's/.*p95_ns=\([0-9]*\).*/\1/p' "$WORK_DIR/go.result")
ODIN_P95=$(sed -n 's/.*p95_ns=\([0-9]*\).*/\1/p' "$WORK_DIR/odin.result")
GO_RSS=$(cat "$WORK_DIR/go.rss")
ODIN_RSS=$(cat "$WORK_DIR/odin.rss")
P95_RATIO=$(awk -v go="$GO_P95" -v odin="$ODIN_P95" \
    'BEGIN { printf "%.2f", odin / go * 100 }')
RSS_RATIO=$(awk -v go="$GO_RSS" -v odin="$ODIN_RSS" \
    'BEGIN { printf "%.2f", odin / go * 100 }')

cat "$WORK_DIR/go.result"
cat "$WORK_DIR/odin.result"
printf 'p95 latency ratio: %.2f%%\n' "$P95_RATIO"
printf 'peak server RSS: Go %s KiB, Odin %s KiB, %.2f%%\n' \
    "$GO_RSS" "$ODIN_RSS" "$RSS_RATIO"

failed=0
if ! awk -v ratio="$P95_RATIO" 'BEGIN { exit !(ratio <= 110) }'; then
    printf 'warning: p95 latency exceeds release threshold on this host\n'
    failed=1
fi
if ! awk -v ratio="$RSS_RATIO" 'BEGIN { exit !(ratio <= 115) }'; then
    printf 'warning: peak RSS exceeds release threshold on this host\n'
    failed=1
fi
if [[ "$failed" == 1 && ${MCPE_ODIN_ENFORCE_BENCHMARKS:-0} == 1 ]]; then
    exit 1
fi
printf 'RakNet network comparison matches %s\n' "$LOCKED_COMMIT"

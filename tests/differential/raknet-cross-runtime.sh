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
GO_SERVER_PID=
ODIN_SERVER_PID=
PROXY_PID=
cleanup() {
    if [[ -n "$GO_SERVER_PID" ]]; then kill "$GO_SERVER_PID" 2>/dev/null || true; fi
    if [[ -n "$ODIN_SERVER_PID" ]]; then kill "$ODIN_SERVER_PID" 2>/dev/null || true; fi
    if [[ -n "$PROXY_PID" ]]; then kill "$PROXY_PID" 2>/dev/null || true; fi
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

(
    cd "$UPSTREAM_DIR"
    go build -trimpath -o "$WORK_DIR/go-oracle" ./cmd/mcpe-odin-oracle
)
"$ROOT_DIR/tools/odinw" build raknet-cross \
    -out:"$WORK_DIR/odin-cross"

stdbuf -oL "$WORK_DIR/go-oracle" serve-echo \
    >"$WORK_DIR/go-server.txt" 2>"$WORK_DIR/go-server.err" &
GO_SERVER_PID=$!
for _ in $(seq 1 100); do
    [[ -s "$WORK_DIR/go-server.txt" ]] && break
    sleep 0.02
done
GO_ADDRESS=$(head -n 1 "$WORK_DIR/go-server.txt")
timeout 5 "$WORK_DIR/odin-cross" dial-echo "$GO_ADDRESS"
wait "$GO_SERVER_PID"
GO_SERVER_PID=

stdbuf -oL "$WORK_DIR/odin-cross" serve-echo \
    >"$WORK_DIR/odin-server.txt" 2>"$WORK_DIR/odin-server.err" &
ODIN_SERVER_PID=$!
for _ in $(seq 1 100); do
    [[ -s "$WORK_DIR/odin-server.txt" ]] && break
    sleep 0.02
done
ODIN_ADDRESS=$(head -n 1 "$WORK_DIR/odin-server.txt")
timeout 5 "$WORK_DIR/go-oracle" dial-echo "$ODIN_ADDRESS"
wait "$ODIN_SERVER_PID"
ODIN_SERVER_PID=

stdbuf -oL "$WORK_DIR/go-oracle" serve-echo \
    >"$WORK_DIR/go-loss-server.txt" 2>"$WORK_DIR/go-loss-server.err" &
GO_SERVER_PID=$!
for _ in $(seq 1 100); do
    [[ -s "$WORK_DIR/go-loss-server.txt" ]] && break
    sleep 0.02
done
GO_LOSS_ADDRESS=$(head -n 1 "$WORK_DIR/go-loss-server.txt")
stdbuf -oL "$WORK_DIR/go-oracle" udp-proxy "$GO_LOSS_ADDRESS" 5 \
    >"$WORK_DIR/go-loss-proxy.txt" 2>"$WORK_DIR/go-loss-proxy.err" &
PROXY_PID=$!
for _ in $(seq 1 100); do
    [[ -s "$WORK_DIR/go-loss-proxy.txt" ]] && break
    sleep 0.02
done
GO_PROXY_ADDRESS=$(head -n 1 "$WORK_DIR/go-loss-proxy.txt")
timeout 12 "$WORK_DIR/odin-cross" dial-echo "$GO_PROXY_ADDRESS"
wait "$GO_SERVER_PID"
GO_SERVER_PID=
kill "$PROXY_PID"
wait "$PROXY_PID" 2>/dev/null || true
PROXY_PID=

stdbuf -oL "$WORK_DIR/odin-cross" serve-echo \
    >"$WORK_DIR/odin-loss-server.txt" 2>"$WORK_DIR/odin-loss-server.err" &
ODIN_SERVER_PID=$!
for _ in $(seq 1 100); do
    [[ -s "$WORK_DIR/odin-loss-server.txt" ]] && break
    sleep 0.02
done
ODIN_LOSS_ADDRESS=$(head -n 1 "$WORK_DIR/odin-loss-server.txt")
stdbuf -oL "$WORK_DIR/go-oracle" udp-proxy "$ODIN_LOSS_ADDRESS" 5 \
    >"$WORK_DIR/odin-loss-proxy.txt" 2>"$WORK_DIR/odin-loss-proxy.err" &
PROXY_PID=$!
for _ in $(seq 1 100); do
    [[ -s "$WORK_DIR/odin-loss-proxy.txt" ]] && break
    sleep 0.02
done
ODIN_PROXY_ADDRESS=$(head -n 1 "$WORK_DIR/odin-loss-proxy.txt")
timeout 12 "$WORK_DIR/go-oracle" dial-echo "$ODIN_PROXY_ADDRESS"
wait "$ODIN_SERVER_PID"
ODIN_SERVER_PID=
kill "$PROXY_PID"
wait "$PROXY_PID" 2>/dev/null || true
PROXY_PID=

printf 'RakNet cross-runtime echo matches %s\n' "$LOCKED_COMMIT"

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

GO_BENCHMARK="$UPSTREAM_DIR/mcpe_odin_benchmark_test.go"
cleanup() {
    rm -f "$GO_BENCHMARK"
}
trap cleanup EXIT
cp "$ROOT_DIR/tests/benchmarks/go-raknet-benchmark_test.go" "$GO_BENCHMARK"

GO_OUTPUT=$(
    cd "$UPSTREAM_DIR"
    go test -run '^$' \
        -bench 'Benchmark(PacketDecode1KiB|Fragment64KiB)$' \
        -benchtime=500ms \
        -count=3
)
ODIN_OUTPUT=$(
    for _ in 1 2 3; do
        "$ROOT_DIR/tools/odinw" benchmark -o:speed
    done
)

median() {
    sort -n | sed -n '2p'
}

GO_DECODE=$(
    awk '/BenchmarkPacketDecode1KiB-/ {
        for (field = 1; field <= NF; field++) {
            if ($field == "MB/s") print $(field - 1) * 1000000 / 1048576
        }
    }' <<<"$GO_OUTPUT" | median
)
GO_FRAGMENT=$(
    awk '/BenchmarkFragment64KiB-/ {
        for (field = 1; field <= NF; field++) {
            if ($field == "MB/s") print $(field - 1) * 1000000 / 1048576
        }
    }' <<<"$GO_OUTPUT" | median
)
ODIN_DECODE=$(
    awk '/raknet packet decode 1 KiB:/ {
        for (field = 1; field <= NF; field++) {
            if ($field ~ /^MiB\/s/) print $(field - 1)
        }
    }' <<<"$ODIN_OUTPUT" | median
)
ODIN_FRAGMENT=$(
    awk '/raknet fragment 64 KiB:/ {
        for (field = 1; field <= NF; field++) {
            if ($field ~ /^MiB\/s/) print $(field - 1)
        }
    }' <<<"$ODIN_OUTPUT" | median
)

compare() {
    local name=$1
    local go_rate=$2
    local odin_rate=$3
    local ratio
    ratio=$(awk -v go_rate="$go_rate" -v odin_rate="$odin_rate" \
        'BEGIN { printf "%.2f", odin_rate / go_rate * 100 }')
    printf '%s: Go %.2f MiB/s, Odin %.2f MiB/s, %.2f%%\n' \
        "$name" "$go_rate" "$odin_rate" "$ratio"
    awk -v ratio="$ratio" 'BEGIN { exit !(ratio >= 90) }'
}

compare "packet decode 1 KiB" "$GO_DECODE" "$ODIN_DECODE"
compare "fragment 64 KiB" "$GO_FRAGMENT" "$ODIN_FRAGMENT"
printf 'RakNet throughput smoke gate matches %s\n' "$LOCKED_COMMIT"

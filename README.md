# mcpe-odin

Unofficial Odin ports of go-raknet, gophertunnel, and Dragonfly for Minecraft:
Bedrock Edition.

Current implementation target:

- go-raknet `0d1fd09e2cf6d50dbc7c0764731109196ed9e248`
- gophertunnel `0a2ecd5633ea1466ff97f6d4718df66ec14d054f`
- Dragonfly `11e6c74c87f1e775ae28856117f075302c4fa814`
- Minecraft `1.26.30`, protocol `1001`
- Odin `dev-2026-07a`
- Linux x86-64

This repository is under active construction. Stable release tags are created
only after their corresponding compatibility gate passes. Missing features are
tracked explicitly in `api-map.toml`; package presence does not imply parity.

## Commands

```sh
./tools/odinw test
./tools/odinw check
./tools/odinw benchmark -o:speed
./tests/benchmarks/raknet-compare.sh
MCPE_ODIN_ENFORCE_BENCHMARKS=1 ./tests/benchmarks/raknet-compare.sh
./tests/benchmarks/raknet-network-compare.sh
MCPE_ODIN_RELEASE_BENCHMARKS=1 ./tests/benchmarks/raknet-compare.sh
MCPE_ODIN_RELEASE_BENCHMARKS=1 ./tests/benchmarks/raknet-network-compare.sh
./tests/differential/raknet-messages.sh
./tests/differential/raknet-cross-runtime.sh
./tests/differential/gophertunnel-codec.sh
./tools/api-audit/check.sh
./tools/release-raknet
./tools/odinw build dragonfly
./tools/odinw run dragonfly
```

## RakNet benchmarks

Latest release-gate run on 2026-07-24 used five warm runs and ten measured
runs. Results compare this Odin port against pinned go-raknet
`0d1fd09e2cf6d50dbc7c0764731109196ed9e248`.

| Benchmark | Go | Odin | Odin / Go |
| --- | ---: | ---: | ---: |
| Packet decode, 1 KiB | 6,287.40 MiB/s | 81,186.40 MiB/s | 1,291.26% |
| Fragment, 64 KiB | 291,482.00 MiB/s | 393,493.00 MiB/s | 135.00% |
| Network p95 latency | 33,450 ns | 31,500 ns | 94.17% |
| Peak server RSS | 8,728 KiB | 4,028 KiB | 46.15% |

Host: AMD Ryzen 9 7950X, 16 cores/32 threads, NixOS 26.05, Linux 6.18.39,
Go 1.26.5, Odin `dev-2026-07-nightly:819fdc7`. Network and RSS rows report
the median of each measured run's p95 latency and peak RSS. Results vary by
host; release gates require at least 90% Go throughput, at most 110% Go p95
latency, and at most 115% Go peak RSS.

`./tools/release-raknet [output-directory]` requires a clean Git tree and
creates a provenance-complete Linux x86-64 source/binary archive, detached
SHA-256, and manifest. The manifest records exact source, upstream, Odin
archive, Odin binary, build tools, embedded assets, native dependencies, and
packaged-file hashes.

Pinned Odin `dev-2026-07a` currently emits different valid code/type-info
orderings across identical builds, even with its threaded checker disabled.
Archive metadata is normalized, but binary bundles are not yet claimed to be
byte-for-byte reproducible. Each produced bundle remains internally
checksummed and exactly attributable; this known gap keeps the stable RakNet
release gate partial.

RakNet examples:

```sh
./tools/odinw odin build examples/raknet-echo-server
./tools/odinw odin build examples/raknet-echo-client
./tools/odinw odin build examples/raknet-ping
```

Use packages from another Odin project:

```sh
odin build . -collection:mcpe=/path/to/mcpe-odin/packages
```

```odin
import raknet "mcpe:raknet"
```

The gophertunnel protocol foundation is available at:

```odin
import protocol "mcpe:gophertunnel/minecraft/protocol"
```

It currently includes byte-compatible little/big-endian primitives, signed
and unsigned varints, strings and byte slices, vectors, block/chunk positions,
UUID wire order, colours, and allocation guards. The differential fixture
compares the combined Odin encoding byte-for-byte with pinned gophertunnel.
The `mcpe:gophertunnel/minecraft/nbt` package adds tagged `Value` trees and
Network Little Endian, Little Endian, Network Big Endian, and Big Endian
binary NBT with upstream depth, string, and network-byte limits. Network
encoding and decoding also share a 65,536-node heap-amplification ceiling.
`nbt.dump` reproduces upstream's human-readable tagged tree format.

The protocol `packet` slice includes header/sub-client framing, a tagged
`Packet` union, unknown-payload preservation, and 186 login, network, and game
state packet codecs for protocol 1001. `protocol.Optional(T)` preserves
presence separately from zero values for newer packet fields. Pinned-Go
differential fixtures cover every modeled packet plus uncompressed batch
framing. Batch decoding enforces upstream's 812-packet client-side limit.
Modeled login/resource-pack flow includes login claims bytes, pack inventory
and stack negotiation, client responses, metadata, chunk requests, and chunk
payloads.
Chat support includes all upstream `Text` variants, category framing,
translation parameters, platform identifiers, and optional filtered messages.
UI coverage includes titles, store offers and receipts, modal responses,
server-settings forms, and settings-issued commands.
The `mcpe:gophertunnel/minecraft/protocol/login` package now exposes
`Identity_Data` and byte-compatible upstream identity validation, including
the legacy username-regex quirks used by authenticated and offline clients.
It also exposes the complete `Client_Data`/persona/animation records, the
15-value `Device_OS` catalog, and compatible Device ID classification,
platform expectations, and cryptographic generation.
Raw DEFLATE compression is interoperable in both directions: Odin decodes Go
level-6 streams and emits standards-compliant stored blocks. Compressed batch
framing supports upstream's per-batch algorithm byte, threshold no-op marker,
algorithm validation, and borrowed/owned payload lifetimes. Decompression is
bounded to 64 MiB while tuned encoding remains in progress. Safe hostile-stream
decoding uses the pinned four-symbol zlib ABI; no local zlib build is performed.

## Compatibility policy

Upstream behaviour is authoritative, including quirks. Public Odin APIs keep
upstream concepts and names recognizable while using Odin procedures, result
tuples, explicit ownership, and context allocators. See `compatibility.md`.

This project is not affiliated with Mojang Studios, Microsoft, Sandertv, or
Dragonfly contributors. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)
for source-port and toolchain attribution.

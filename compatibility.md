# Go-to-Odin compatibility

Upstream behaviour is oracle. Odin changes syntax and ownership, not wire or
game semantics.

## Common mappings

| Go | Odin |
| --- | --- |
| `(*T).Method(args)` | `package.method(t, args)` |
| `(T, error)` | `(T, Error)` with `nil` success |
| `context.Context` | `runtime.Cancel_Token` plus deadline |
| `*slog.Logger` error sink | `runtime.Error_Logger` callback record |
| interface | `{user_data: rawptr, vtable: ^VTable}` |
| goroutine | reactor task or bounded worker-pool job |
| channel | bounded queue with explicit close |
| garbage-collected slice | borrowed slice or explicit owned clone |
| `defer obj.Close()` | `defer package.close(obj)` |

Constructors use `context.allocator` unless an explicit allocator overload is
provided. Long-lived objects retain their construction allocator. Borrowed
data is valid only for the documented operation window.

`raknet.read_packet` returns bytes borrowed from its `Conn`; the next
successful `read` or `read_packet` call on that connection invalidates them.
`clone_packet` creates an allocator-owned copy when data must outlive that
window.

`Upstream_Dialer_VTable.dial` is the `DialContext` mapping. It returns an
owned `Packet_Transport` plus its connected remote endpoint. RakNet applies
the absolute handshake deadline through `set_deadline`, caps individual
handshake reads at 100 ms for retransmission and cancellation, clears the
deadline with zero after connecting, and closes the transport exactly once.
Connected transports may return a zero remote endpoint from `read`; RakNet
substitutes the remote endpoint returned by `dial`. `set_deadline` is required
for dial transports only; packet-listener transports may omit it.

`close` is overloaded for `Conn` and `Listener`. Closing starts shutdown;
`conn_destroy` and `destroy_listener` additionally release Odin-owned storage.

`Error` is a nil-able pointer to rich `Error_Detail`, allowing Odin
`or_return`. A non-nil terminal error must eventually be released with
`runtime.destroy_error`.

Error-logger callbacks borrow their `Error` only for the callback. Default
zero-value loggers discard errors, matching upstream's disabled default.

## RakNet safety deviations

Pinned go-raknet admits a seventeenth concurrent split assembly, then rejects
all later split fragments. Odin rejects only new assemblies after sixteen
records while allowing existing assemblies to finish. This deliberate
malformed-input safety exception prevents a peer-triggered permanent
split-processing denial of service.

## Naming

Types retain recognizable upstream names. Procedures use Odin snake case:
`DialContext` becomes `dial_context`; `Conn.Read` becomes `read`.

## Stability

`api-map.toml` is the source of truth. `missing` means not implemented,
`partial` means unusable for a stable compatibility gate, and `complete` means
differentially verified against the locked upstream commit.

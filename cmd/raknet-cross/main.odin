package raknet_cross

import "core:fmt"
import "core:net"
import "core:os"
import "core:slice"
import "core:time"
import raknet "mcpe:raknet"
import mcpe_runtime "mcpe:runtime"

CROSS_RUNTIME_PAYLOAD: string = "mcpe-odin-cross-runtime"

fail :: proc(operation: string, err: mcpe_runtime.Error) {
    if err != nil {
        fmt.eprintf("%s: %s\n", operation, err.message)
        mcpe_runtime.destroy_error(err)
    } else {
        fmt.eprintln(operation)
    }
    os.exit(1)
}

serve_echo :: proc() {
    listener, listen_err := raknet.listen("127.0.0.1:0")
    if listen_err != nil {
        fail("listen", listen_err)
    }
    defer raknet.destroy_listener(listener)
    fmt.println(net.endpoint_to_string(raknet.listener_address(listener)))

    conn, accept_err := raknet.accept(listener)
    if accept_err != nil {
        fail("accept", accept_err)
    }
    defer raknet.conn_destroy(conn)
    buffer: [1500]u8
    count, read_err := raknet.read(conn, buffer[:])
    if read_err != nil {
        fail("read", read_err)
    }
    expected := transmute([]u8)CROSS_RUNTIME_PAYLOAD
    if !slice.equal(buffer[:count], expected) {
        fail("unexpected Go payload", nil)
    }
    if _, write_err := raknet.write(conn, buffer[:count]); write_err != nil {
        fail("write", write_err)
    }
    // Keep the oracle endpoint alive long enough to prove retransmission when
    // the proxy drops the first echo datagram.
    time.sleep(1500 * time.Millisecond)
}

dial_echo :: proc(address: string) {
    conn, dial_err := raknet.dial_timeout(address, 3 * time.Second)
    if dial_err != nil {
        fail("dial", dial_err)
    }
    defer raknet.conn_destroy(conn)
    expected := transmute([]u8)CROSS_RUNTIME_PAYLOAD
    if _, write_err := raknet.write(conn, expected); write_err != nil {
        fail("write", write_err)
    }
    buffer: [1500]u8
    count, read_err := raknet.read(conn, buffer[:])
    if read_err != nil {
        fail("read", read_err)
    }
    if !slice.equal(buffer[:count], expected) {
        fail("unexpected Go echo", nil)
    }
    fmt.println("odin-client-ok")
}

main :: proc() {
    if len(os.args) < 2 {
        fail("usage: raknet-cross <serve-echo|dial-echo> [address]", nil)
    }
    switch os.args[1] {
    case "serve-echo":
        serve_echo()
    case "dial-echo":
        if len(os.args) != 3 {
            fail("usage: raknet-cross dial-echo <address>", nil)
        }
        dial_echo(os.args[2])
    case:
        fail("unknown operation", nil)
    }
}

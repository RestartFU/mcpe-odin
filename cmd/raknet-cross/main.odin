package raknet_cross

import "core:fmt"
import "core:net"
import "core:os"
import "core:slice"
import "core:time"
import raknet "mcpe:raknet"
import mcpe_runtime "mcpe:runtime"

DEFAULT_PAYLOAD_SIZE :: len("mcpe-odin-cross-runtime")
MAX_PAYLOAD_SIZE     :: 65536
BENCHMARK_WARMUPS    :: 50
BENCHMARK_ITERATIONS :: 1000
BENCHMARK_PAYLOAD    :: 1024

fill_payload :: proc(payload: []u8) {
    for &value, index in payload {
        value = u8(index * 31 + 7)
    }
}

payload_matches :: proc(payload: []u8) -> bool {
    for value, index in payload {
        if value != u8(index * 31 + 7) {
            return false
        }
    }
    return true
}

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
    buffer: [MAX_PAYLOAD_SIZE]u8
    count, read_err := raknet.read(conn, buffer[:])
    if read_err != nil {
        fail("read", read_err)
    }
    if !payload_matches(buffer[:count]) {
        fail("unexpected Go payload", nil)
    }
    if _, write_err := raknet.write(conn, buffer[:count]); write_err != nil {
        fail("write", write_err)
    }
    // Keep the oracle endpoint alive long enough to prove retransmission when
    // the proxy drops the first echo datagram.
    time.sleep(1500 * time.Millisecond)
}

dial_echo :: proc(address: string, payload_size: int) {
    conn, dial_err := raknet.dial_timeout(address, 3 * time.Second)
    if dial_err != nil {
        fail("dial", dial_err)
    }
    defer raknet.conn_destroy(conn)
    expected := make([]u8, payload_size)
    defer delete(expected)
    fill_payload(expected)
    if _, write_err := raknet.write(conn, expected); write_err != nil {
        fail("write", write_err)
    }
    buffer: [MAX_PAYLOAD_SIZE]u8
    count, read_err := raknet.read(conn, buffer[:])
    if read_err != nil {
        fail("read", read_err)
    }
    if !slice.equal(buffer[:count], expected) {
        fail("unexpected Go echo", nil)
    }
    fmt.println("odin-client-ok")
}

serve_benchmark :: proc() {
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
    buffer: [BENCHMARK_PAYLOAD]u8
    for _ in 0..<BENCHMARK_WARMUPS + BENCHMARK_ITERATIONS {
        count, read_err := raknet.read(conn, buffer[:])
        if read_err != nil {
            fail("read", read_err)
        }
        if count != BENCHMARK_PAYLOAD {
            fail("unexpected benchmark payload size", nil)
        }
        if _, write_err := raknet.write(conn, buffer[:count]); write_err != nil {
            fail("write", write_err)
        }
    }
    time.sleep(1500 * time.Millisecond)
}

dial_benchmark :: proc(address: string) {
    conn, dial_err := raknet.dial_timeout(address, 3 * time.Second)
    if dial_err != nil {
        fail("dial", dial_err)
    }
    defer raknet.conn_destroy(conn)
    payload: [BENCHMARK_PAYLOAD]u8
    fill_payload(payload[:])
    buffer: [BENCHMARK_PAYLOAD]u8

    for _ in 0..<BENCHMARK_WARMUPS {
        if _, write_err := raknet.write(conn, payload[:]); write_err != nil {
            fail("write", write_err)
        }
        count, read_err := raknet.read(conn, buffer[:])
        if read_err != nil {
            fail("read", read_err)
        }
        if !slice.equal(buffer[:count], payload[:]) {
            fail("unexpected benchmark echo", nil)
        }
    }

    latencies := make([]i64, BENCHMARK_ITERATIONS)
    defer delete(latencies)
    started := time.now()
    for index in 0..<BENCHMARK_ITERATIONS {
        sample_started := time.now()
        if _, write_err := raknet.write(conn, payload[:]); write_err != nil {
            fail("write", write_err)
        }
        count, read_err := raknet.read(conn, buffer[:])
        if read_err != nil {
            fail("read", read_err)
        }
        if !slice.equal(buffer[:count], payload[:]) {
            fail("unexpected benchmark echo", nil)
        }
        latencies[index] = i64(time.since(sample_started))
    }
    elapsed := time.since(started)
    slice.sort(latencies)
    p95_index := (BENCHMARK_ITERATIONS * 95 + 99) / 100 - 1
    fmt.printf(
        "raknet benchmark: p95_ns=%d messages_per_second=%.2f\n",
        latencies[p95_index],
        f64(BENCHMARK_ITERATIONS) / time.duration_seconds(elapsed),
    )
}

main :: proc() {
    if len(os.args) < 2 {
        fail("usage: raknet-cross <serve-echo|dial-echo> [address]", nil)
    }
    switch os.args[1] {
    case "serve-echo":
        serve_echo()
    case "serve-benchmark":
        serve_benchmark()
    case "dial-echo":
        if len(os.args) != 3 && len(os.args) != 4 {
            fail("usage: raknet-cross dial-echo <address> [payload-size]", nil)
        }
        payload_size := DEFAULT_PAYLOAD_SIZE
        if len(os.args) == 4 {
            if os.args[3] != "65536" {
                fail("supported payload-size is 65536", nil)
            }
            payload_size = MAX_PAYLOAD_SIZE
        }
        dial_echo(os.args[2], payload_size)
    case "dial-benchmark":
        if len(os.args) != 3 {
            fail("usage: raknet-cross dial-benchmark <address>", nil)
        }
        dial_benchmark(os.args[2])
    case:
        fail("unknown operation", nil)
    }
}

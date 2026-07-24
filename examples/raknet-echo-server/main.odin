package raknet_echo_server

import "core:fmt"
import "core:net"
import "core:os"
import raknet "mcpe:raknet"
import mcpe_runtime "mcpe:runtime"

report_error :: proc(operation: string, err: mcpe_runtime.Error) {
    defer mcpe_runtime.destroy_error(err)
    fmt.eprintf("%s failed during %s: %s\n", operation, err.operation, err.message)
}

main :: proc() {
    address := "0.0.0.0:19132"
    if len(os.args) == 2 {
        address = os.args[1]
    } else if len(os.args) != 1 {
        fmt.eprintln("usage: raknet-echo-server [host:port]")
        return
    }

    listener, err := raknet.listen(address)
    if err != nil {
        report_error("listen", err)
        return
    }
    defer raknet.destroy_listener(listener)
    fmt.printf(
        "listening on %s\n",
        net.endpoint_to_string(raknet.listener_address(listener)),
    )

    buffer: [65536]u8
    for {
        conn, accept_err := raknet.accept(listener)
        if accept_err != nil {
            report_error("accept", accept_err)
            return
        }

        count, read_err := raknet.read(conn, buffer[:])
        if read_err != nil {
            report_error("read", read_err)
            raknet.conn_destroy(conn)
            continue
        }
        if _, write_err := raknet.write(conn, buffer[:count]); write_err != nil {
            report_error("write", write_err)
        }
        raknet.conn_destroy(conn)
    }
}

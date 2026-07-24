package raknet_echo_client

import "core:fmt"
import "core:os"
import "core:slice"
import raknet "mcpe:raknet"
import mcpe_runtime "mcpe:runtime"

report_error :: proc(operation: string, err: mcpe_runtime.Error) {
    defer mcpe_runtime.destroy_error(err)
    fmt.eprintf("%s failed during %s: %s\n", operation, err.operation, err.message)
}

main :: proc() {
    if len(os.args) != 2 && len(os.args) != 3 {
        fmt.eprintln("usage: raknet-echo-client <host:port> [message]")
        return
    }
    message := "Hello World!"
    if len(os.args) == 3 {
        message = os.args[2]
    }

    conn, err := raknet.dial(os.args[1])
    if err != nil {
        report_error("dial", err)
        return
    }
    defer raknet.conn_destroy(conn)

    expected := transmute([]u8)message
    if _, write_err := raknet.write(conn, expected); write_err != nil {
        report_error("write", write_err)
        return
    }

    response := make([]u8, len(expected))
    defer delete(response)
    count, read_err := raknet.read(conn, response)
    if read_err != nil {
        report_error("read", read_err)
        return
    }
    if !slice.equal(response[:count], expected) {
        fmt.eprintln("echo response did not match request")
        return
    }
    fmt.println(string(response[:count]))
}

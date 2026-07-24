package raknet

import "core:net"
import "core:sync"
import "core:time"
import message "mcpe:raknet/message"
import mcpe_runtime "mcpe:runtime"

PROTOCOL_VERSION :: u8(11)
MIN_MTU_SIZE     :: u16(400)
MAX_MTU_SIZE     :: u16(1492)
MAX_WINDOW_SIZE  :: UInt24(2048)

START_TIME := time.now()
DIALER_ID: i64 = -1

timestamp :: proc() -> i64 {
    return i64(time.duration_milliseconds(time.since(START_TIME)))
}

next_dialer_id :: proc() -> i64 {
    return sync.atomic_add(&DIALER_ID, -1)
}

network_error :: proc(operation: string, kind: mcpe_runtime.Error_Kind = .Network) -> mcpe_runtime.Error {
    return mcpe_runtime.make_error(
        kind,
        operation,
        net.last_platform_error_string(),
        i64(net.last_platform_error()),
    )
}

resolve_endpoint :: proc(address: string) -> (endpoint: net.Endpoint, err: mcpe_runtime.Error) {
    ep4, ep6, resolve_err := net.resolve(address)
    if resolve_err != nil {
        err = network_error("raknet.resolve", .Address)
        return
    }
    if ep4.address != nil {
        return ep4, nil
    }
    if ep6.address != nil {
        return ep6, nil
    }
    err = mcpe_runtime.make_error(.Address, "raknet.resolve", "no address found")
    return
}

ping :: proc(address: string) -> (response: []u8, err: mcpe_runtime.Error) {
    return ping_timeout(address, 5 * time.Second)
}

ping_context :: proc(
    token: ^mcpe_runtime.Cancel_Token,
    address: string,
    timeout: time.Duration = 5 * time.Second,
) -> (response: []u8, err: mcpe_runtime.Error) {
    return ping_timeout_internal(address, timeout, token)
}

ping_timeout :: proc(
    address: string,
    timeout: time.Duration,
) -> (response: []u8, err: mcpe_runtime.Error) {
    return ping_timeout_internal(address, timeout, nil)
}

ping_timeout_internal :: proc(
    address: string,
    timeout: time.Duration,
    token: ^mcpe_runtime.Cancel_Token,
) -> (response: []u8, err: mcpe_runtime.Error) {
    if timeout <= 0 {
        err = mcpe_runtime.make_error(.Invalid_Argument, "raknet.ping", "timeout must be positive")
        return
    }
    if mcpe_runtime.is_cancelled(token) {
        err = mcpe_runtime.make_error(.Cancelled, "raknet.ping")
        return
    }
    endpoint := resolve_endpoint(address) or_return
    socket, socket_err := net.make_unbound_udp_socket(net.family_from_address(endpoint.address))
    if socket_err != nil {
        err = network_error("raknet.ping.socket")
        return
    }
    defer net.close(socket)

    if option_err := net.set_option(
        socket,
        .Receive_Timeout,
        min(timeout, 100 * time.Millisecond),
    ); option_err != nil {
        err = network_error("raknet.ping.deadline")
        return
    }

    request := message.marshal_unconnected_ping({
        ping_time = timestamp(),
        client_guid = next_dialer_id(),
    })
    if _, send_err := net.send_udp(socket, request[:], endpoint); send_err != nil {
        err = network_error("raknet.ping.send")
        return
    }

    deadline_ns := mcpe_runtime.system_now_ns(nil) + i64(timeout)
    buffer: [MAX_MTU_SIZE]u8
    for mcpe_runtime.system_now_ns(nil) < deadline_ns {
        if mcpe_runtime.is_cancelled(token) {
            err = mcpe_runtime.make_error(.Cancelled, "raknet.ping")
            return
        }
        received, remote, receive_err := net.recv_udp(socket, buffer[:])
        if receive_err != nil {
            if receive_err == .Timeout {
                continue
            }
            if mcpe_runtime.is_cancelled(token) {
                err = mcpe_runtime.make_error(.Cancelled, "raknet.ping")
                return
            }
            err = network_error("raknet.ping.receive")
            return
        }
        if remote != endpoint {
            continue
        }
        if received == 0 || buffer[0] != message.ID_UNCONNECTED_PONG {
            continue
        }
        pong := message.unmarshal_unconnected_pong(buffer[1:received]) or_return
        response = make([]u8, len(pong.data))
        copy(response, pong.data)
        return
    }
    if mcpe_runtime.is_cancelled(token) {
        err = mcpe_runtime.make_error(.Cancelled, "raknet.ping")
    } else {
        err = mcpe_runtime.make_error(.Timeout, "raknet.ping.receive")
    }
    return
}

dialer_ping :: proc(
    dialer: Dialer,
    address: string,
) -> (response: []u8, err: mcpe_runtime.Error) {
    _ = dialer
    return ping(address)
}

dialer_ping_timeout :: proc(
    dialer: Dialer,
    address: string,
    timeout: time.Duration,
) -> (response: []u8, err: mcpe_runtime.Error) {
    _ = dialer
    return ping_timeout(address, timeout)
}

dialer_ping_context :: proc(
    dialer: Dialer,
    token: ^mcpe_runtime.Cancel_Token,
    address: string,
    timeout: time.Duration = 5 * time.Second,
) -> (response: []u8, err: mcpe_runtime.Error) {
    _ = dialer
    return ping_context(token, address, timeout)
}

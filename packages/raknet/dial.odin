package raknet

import "core:net"
import "core:sys/linux"
import channel "core:sync/chan"
import "core:time"
import message "mcpe:raknet/message"
import mcpe_runtime "mcpe:runtime"

Upstream_Dial_Proc :: proc "odin" (
    user_data: rawptr,
    remote: net.Endpoint,
) -> (socket: net.UDP_Socket, err: mcpe_runtime.Error)

Upstream_Dialer_VTable :: struct {
    dial: Upstream_Dial_Proc,
}

Upstream_Dialer :: struct {
    user_data: rawptr,
    vtable:    ^Upstream_Dialer_VTable,
}

Dialer :: struct {
    max_transient_errors: int,
    max_mtu:              u16,
    upstream_dialer:      Upstream_Dialer,
    error_log:            mcpe_runtime.Error_Logger,
}

MIN_SUPPORTED_MTU :: u16(576)

handshake_wait_error :: proc(
    token: ^mcpe_runtime.Cancel_Token,
    deadline_ns: i64,
    operation: string,
) -> mcpe_runtime.Error {
    if mcpe_runtime.is_cancelled(token) {
        return mcpe_runtime.make_error(.Cancelled, operation)
    }
    if mcpe_runtime.system_now_ns(nil) >= deadline_ns {
        return mcpe_runtime.make_error(.Timeout, operation)
    }
    return nil
}

dialer_receive :: proc(
    socket: net.UDP_Socket,
    buffer: []u8,
    deadline_ns: i64,
) -> (
    count: int,
    remote: net.Endpoint,
    err: mcpe_runtime.Error,
) {
    remaining_ns := deadline_ns - mcpe_runtime.system_now_ns(nil)
    if remaining_ns <= 0 {
        err = mcpe_runtime.make_error(.Timeout, "raknet.dial.receive")
        return
    }
    receive_timeout := min(time.Duration(remaining_ns), 100 * time.Millisecond)
    if option_err := net.set_option(
        socket,
        .Receive_Timeout,
        receive_timeout,
    ); option_err != nil {
        err = network_error("raknet.dial.receive.deadline")
        return
    }
    receive_err: net.UDP_Recv_Error
    count, remote, receive_err = net.recv_udp(socket, buffer)
    if receive_err != nil {
        kind := mcpe_runtime.Error_Kind.Network
        if receive_err == .Timeout || receive_err == .Would_Block {
            kind = .Timeout
        }
        err = network_error("raknet.dial.receive", kind)
    }
    return
}

dialer_retry_receive_error :: proc(
    dialer: Dialer,
    transient_error_count: ^int,
    receive_err: mcpe_runtime.Error,
) -> (retry: bool, terminal: mcpe_runtime.Error) {
    if receive_err.kind == .Timeout {
        mcpe_runtime.destroy_error(receive_err)
        return true, nil
    }
    errno := linux.Errno(receive_err.native_code)
    #partial switch errno {
    case .ECONNREFUSED, .EHOSTUNREACH, .ENETUNREACH, .ECONNRESET:
    case:
        return false, receive_err
    }
    if dialer.max_transient_errors == -1 ||
       transient_error_count^ < dialer.max_transient_errors {
        transient_error_count^ += 1
        mcpe_runtime.destroy_error(receive_err)
        return true, nil
    }
    return false, receive_err
}

dialer_make_socket :: proc(
    dialer: Dialer,
    remote: net.Endpoint,
) -> (socket: net.UDP_Socket, err: mcpe_runtime.Error) {
    if dialer.upstream_dialer.vtable != nil {
        if dialer.upstream_dialer.vtable.dial == nil {
            err = mcpe_runtime.make_error(
                .Invalid_Argument,
                "raknet.dial.socket",
                "upstream dialer has no dial procedure",
            )
            return
        }
        return dialer.upstream_dialer.vtable.dial(
            dialer.upstream_dialer.user_data,
            remote,
        )
    }
    native_socket, socket_err := net.make_unbound_udp_socket(
        net.family_from_address(remote.address),
    )
    if socket_err != nil {
        err = network_error("raknet.dial.socket")
        return
    }
    return native_socket, nil
}

dialer_discover_mtu :: proc(
    dialer: Dialer,
    socket: net.UDP_Socket,
    remote: net.Endpoint,
    token: ^mcpe_runtime.Cancel_Token,
    deadline_ns: i64,
    transient_error_count: ^int,
) -> (
    mtu: u16,
    server_security: bool,
    cookie: u32,
    err: mcpe_runtime.Error,
) {
    maximum := clamp_mtu(dialer.max_mtu, MIN_SUPPORTED_MTU)
    sizes: [3]u16
    size_count := 0
    sizes[size_count] = maximum
    size_count += 1
    if 1200 < maximum {
        sizes[size_count] = 1200
        size_count += 1
    }
    if MIN_SUPPORTED_MTU < maximum {
        sizes[size_count] = MIN_SUPPORTED_MTU
        size_count += 1
    }

    buffer: [MAX_MTU_SIZE]u8
    for size in sizes[:size_count] {
        for _ in 0..<4 {
            if wait_err := handshake_wait_error(token, deadline_ns, "raknet.dial.discover_mtu"); wait_err != nil {
                return 0, false, 0, wait_err
            }
            request, request_err := message.marshal_open_connection_request_1({
                client_protocol = PROTOCOL_VERSION,
                mtu = size,
            })
            if request_err != nil {
                return 0, false, 0, request_err
            }
            if _, send_err := net.send_udp(socket, request.data[:], remote); send_err != nil {
                writer_destroy(&request)
                continue
            }
            writer_destroy(&request)

            retry_deadline := min(
                deadline_ns,
                mcpe_runtime.system_now_ns(nil) + i64(500 * time.Millisecond),
            )
            for mcpe_runtime.system_now_ns(nil) < retry_deadline {
                count, packet_remote, receive_err := dialer_receive(
                    socket,
                    buffer[:],
                    deadline_ns,
                )
                if receive_err != nil {
                    retry, terminal := dialer_retry_receive_error(
                        dialer,
                        transient_error_count,
                        receive_err,
                    )
                    if !retry {
                        return 0, false, 0, terminal
                    }
                    if terminal != nil {
                        mcpe_runtime.destroy_error(terminal)
                        break
                    }
                    if wait_err := handshake_wait_error(token, deadline_ns, "raknet.dial.discover_mtu"); wait_err != nil {
                        return 0, false, 0, wait_err
                    }
                    continue
                }
                if count == 0 {
                    continue
                }
                if packet_remote != remote {
                    continue
                }
                switch buffer[0] {
                case message.ID_OPEN_CONNECTION_REPLY_1:
                    reply := message.unmarshal_open_connection_reply_1(buffer[1:count]) or_return
                    if reply.server_guid == 0 ||
                       reply.mtu < MIN_MTU_SIZE ||
                       reply.mtu > 1500 {
                        continue
                    }
                    // Pinned go-raknet trusts a valid fixed-range server MTU
                    // even when it exceeds the current MaxMTU probe.
                    return reply.mtu, reply.server_has_security, reply.cookie, nil
                case message.ID_INCOMPATIBLE_PROTOCOL_VERSION:
                    reply := message.unmarshal_incompatible_protocol_version(buffer[1:count]) or_return
                    _ = reply
                    err = mcpe_runtime.make_error(.Protocol, "raknet.dial", "incompatible RakNet protocol")
                    return
                }
            }
        }
    }
    err = mcpe_runtime.make_error(.Timeout, "raknet.dial", "MTU discovery timed out")
    return
}

dialer_open_connection :: proc(
    dialer: Dialer,
    socket: net.UDP_Socket,
    remote: net.Endpoint,
    client_id: i64,
    mtu: u16,
    server_security: bool,
    cookie: u32,
    token: ^mcpe_runtime.Cancel_Token,
    deadline_ns: i64,
    transient_error_count: ^int,
) -> (negotiated_mtu: u16, err: mcpe_runtime.Error) {
    buffer: [MAX_MTU_SIZE]u8
    for {
        if wait_err := handshake_wait_error(token, deadline_ns, "raknet.dial.open_connection"); wait_err != nil {
            return 0, wait_err
        }
        request := message.marshal_open_connection_request_2({
            server_address = message_address_from_endpoint(remote),
            mtu = mtu,
            client_guid = client_id,
            server_has_security = server_security,
            cookie = cookie,
        })
        if _, send_err := net.send_udp(socket, request.data[:], remote); send_err != nil {
            writer_destroy(&request)
            continue
        }
        writer_destroy(&request)

        retry_deadline := min(
            deadline_ns,
            mcpe_runtime.system_now_ns(nil) + i64(500 * time.Millisecond),
        )
        for mcpe_runtime.system_now_ns(nil) < retry_deadline {
            count, packet_remote, receive_err := dialer_receive(
                socket,
                buffer[:],
                deadline_ns,
            )
            if receive_err != nil {
                retry, terminal := dialer_retry_receive_error(
                    dialer,
                    transient_error_count,
                    receive_err,
                )
                if !retry {
                    return 0, terminal
                }
                if terminal != nil {
                    mcpe_runtime.destroy_error(terminal)
                    break
                }
                if wait_err := handshake_wait_error(token, deadline_ns, "raknet.dial.open_connection"); wait_err != nil {
                    return 0, wait_err
                }
                continue
            }
            if count == 0 || buffer[0] != message.ID_OPEN_CONNECTION_REPLY_2 {
                continue
            }
            if packet_remote != remote {
                continue
            }
            reply := message.unmarshal_open_connection_reply_2(buffer[1:count]) or_return
            // Pinned go-raknet likewise accepts Reply 2's MTU verbatim.
            return reply.mtu, nil
        }
    }
}

dial_config :: proc(
    dialer: Dialer,
    address: string,
    timeout: time.Duration = 10 * time.Second,
    token: ^mcpe_runtime.Cancel_Token = nil,
) -> (conn: ^Conn, err: mcpe_runtime.Error) {
    if timeout <= 0 {
        err = mcpe_runtime.make_error(.Invalid_Argument, "raknet.dial", "timeout must be positive")
        return
    }
    configured_dialer := dialer
    if configured_dialer.max_transient_errors == 0 {
        configured_dialer.max_transient_errors = 10
    }
    deadline_ns := mcpe_runtime.system_now_ns(nil) + i64(timeout)
    if wait_err := handshake_wait_error(token, deadline_ns, "raknet.dial"); wait_err != nil {
        err = wait_err
        return
    }
    remote := resolve_endpoint(address) or_return
    socket := dialer_make_socket(configured_dialer, remote) or_return
    keep_socket := false
    defer if !keep_socket {
        net.close(socket)
    }
    client_id := next_dialer_id()
    transient_error_count := 0
    mtu, security, cookie := dialer_discover_mtu(
        configured_dialer,
        socket,
        remote,
        token,
        deadline_ns,
        &transient_error_count,
    ) or_return
    mtu = dialer_open_connection(
        configured_dialer,
        socket,
        remote,
        client_id,
        mtu,
        security,
        cookie,
        token,
        deadline_ns,
        &transient_error_count,
    ) or_return
    conn = conn_create(socket, remote, mtu, .Client, true) or_return
    conn.error_log = configured_dialer.error_log
    keep_socket = true
    conn_start_threads(conn, false)

    request := message.marshal_connection_request({
        client_guid = client_id,
        request_time = timestamp(),
    })
    if send_err := conn_send_control(conn, request[:]); send_err != nil {
        conn_destroy(conn)
        conn = nil
        err = send_err
        return
    }

    buffer: [1500]u8
    connected := false
    for !connected {
        if wait_err := handshake_wait_error(token, deadline_ns, "raknet.dial.connect"); wait_err != nil {
            conn_destroy(conn)
            conn = nil
            err = wait_err
            return
        }
        count, packet_remote, receive_err := dialer_receive(
            socket,
            buffer[:],
            deadline_ns,
        )
        if receive_err != nil {
            if receive_err.kind == .Timeout {
                mcpe_runtime.destroy_error(receive_err)
                continue
            }
            conn_destroy(conn)
            conn = nil
            err = receive_err
            return
        }
        if packet_remote != remote {
            continue
        }
        if process_err := conn_receive(conn, buffer[:count]); process_err != nil {
            conn_destroy(conn)
            conn = nil
            err = process_err
            return
        }
        _, connected = channel.try_recv(conn.connected_event)
    }

    _ = net.set_option(socket, .Receive_Timeout, 100 * time.Millisecond)
    conn_start_threads(conn, true)
    return
}

dial :: proc(address: string) -> (conn: ^Conn, err: mcpe_runtime.Error) {
    return dial_config({}, address)
}

dial_timeout :: proc(address: string, timeout: time.Duration) -> (
    conn: ^Conn,
    err: mcpe_runtime.Error,
) {
    return dial_config({}, address, timeout)
}

dial_context :: proc(
    token: ^mcpe_runtime.Cancel_Token,
    address: string,
    timeout: time.Duration = 10 * time.Second,
) -> (conn: ^Conn, err: mcpe_runtime.Error) {
    if mcpe_runtime.is_cancelled(token) {
        return nil, mcpe_runtime.make_error(.Cancelled, "raknet.dial")
    }
    return dial_config({}, address, timeout, token)
}

dialer_dial :: proc(
    dialer: Dialer,
    address: string,
) -> (conn: ^Conn, err: mcpe_runtime.Error) {
    return dial_config(dialer, address)
}

dialer_dial_timeout :: proc(
    dialer: Dialer,
    address: string,
    timeout: time.Duration,
) -> (conn: ^Conn, err: mcpe_runtime.Error) {
    return dial_config(dialer, address, timeout)
}

dialer_dial_context :: proc(
    dialer: Dialer,
    token: ^mcpe_runtime.Cancel_Token,
    address: string,
    timeout: time.Duration = 10 * time.Second,
) -> (conn: ^Conn, err: mcpe_runtime.Error) {
    return dial_config(dialer, address, timeout, token)
}

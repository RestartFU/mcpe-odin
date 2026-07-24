package raknet

import "core:net"
import "core:sys/linux"
import channel "core:sync/chan"
import "core:time"
import message "mcpe:raknet/message"
import mcpe_runtime "mcpe:runtime"

// Upstream_Dial_Proc is the Odin equivalent of UpstreamDialer.DialContext.
// On success it transfers ownership of a connected packet transport to
// RakNet. connected_remote is the transport's RemoteAddr equivalent.
Upstream_Dial_Proc :: proc "odin" (
    user_data: rawptr,
    token: ^mcpe_runtime.Cancel_Token,
    deadline_ns: i64,
    remote: net.Endpoint,
) -> (
    transport: Packet_Transport,
    connected_remote: net.Endpoint,
    err: mcpe_runtime.Error,
)

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

Dial_Transport :: struct {
    socket:    net.UDP_Socket,
    transport: Packet_Transport,
    remote:    net.Endpoint,
}

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
    connection: Dial_Transport,
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
    if connection.transport.vtable == nil {
        receive_timeout := min(time.Duration(remaining_ns), 100 * time.Millisecond)
        if option_err := net.set_option(
            connection.socket,
            .Receive_Timeout,
            receive_timeout,
        ); option_err != nil {
            err = network_error("raknet.dial.receive.deadline")
            return
        }
    } else {
        poll_deadline_ns := min(
            deadline_ns,
            mcpe_runtime.system_now_ns(nil) + i64(100 * time.Millisecond),
        )
        if deadline_err := packet_transport_set_deadline(
            connection.transport,
            poll_deadline_ns,
        ); deadline_err != nil {
            err = deadline_err
            return
        }
    }
    count, remote, err = packet_transport_read(
        connection.transport,
        connection.socket,
        buffer,
    )
    // A connected transport has no source address on Read. Its RemoteAddr
    // equivalent is captured when the upstream dial procedure returns.
    if err == nil && remote.address == nil {
        remote = connection.remote
    }
    return
}

dialer_send :: proc(
    connection: Dial_Transport,
    data: []u8,
    deadline_ns: i64,
) -> mcpe_runtime.Error {
    if connection.transport.vtable != nil {
        if deadline_err := packet_transport_set_deadline(
            connection.transport,
            deadline_ns,
        ); deadline_err != nil {
            return deadline_err
        }
    }
    _, _, err := packet_transport_write(
        connection.transport,
        connection.socket,
        data,
        connection.remote,
    )
    return err
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

dialer_make_transport :: proc(
    dialer: Dialer,
    remote: net.Endpoint,
    token: ^mcpe_runtime.Cancel_Token = nil,
    deadline_ns: i64 = 0,
) -> (connection: Dial_Transport, err: mcpe_runtime.Error) {
    if dialer.upstream_dialer.vtable != nil {
        if dialer.upstream_dialer.vtable.dial == nil {
            err = mcpe_runtime.make_error(
                .Invalid_Argument,
                "raknet.dial.socket",
                "upstream dialer has no dial procedure",
            )
            return
        }
        transport, connected_remote, dial_err := dialer.upstream_dialer.vtable.dial(
            dialer.upstream_dialer.user_data,
            token,
            deadline_ns,
            remote,
        )
        if dial_err != nil {
            err = dial_err
            return
        }
        if transport.vtable == nil {
            err = mcpe_runtime.make_error(
                .Invalid_Argument,
                "raknet.dial.transport",
                "upstream dialer returned no packet transport",
            )
            return
        }
        if transport_err := packet_transport_validate(
            transport,
            "raknet.dial.transport",
        ); transport_err != nil {
            if transport.vtable.close != nil {
                if close_err := transport.vtable.close(
                    transport.user_data,
                ); close_err != nil {
                    mcpe_runtime.destroy_error(close_err)
                }
            }
            err = transport_err
            return
        }
        if transport.vtable.set_deadline == nil {
            if close_err := transport.vtable.close(
                transport.user_data,
            ); close_err != nil {
                mcpe_runtime.destroy_error(close_err)
            }
            err = mcpe_runtime.make_error(
                .Invalid_Argument,
                "raknet.dial.transport",
                "upstream dial transport has no deadline procedure",
            )
            return
        }
        if connected_remote.address == nil {
            if close_err := packet_transport_close(transport, {}); close_err != nil {
                mcpe_runtime.destroy_error(close_err)
            }
            err = mcpe_runtime.make_error(
                .Invalid_Argument,
                "raknet.dial.transport",
                "upstream dialer returned no remote endpoint",
            )
            return
        }
        if deadline_err := packet_transport_set_deadline(
            transport,
            deadline_ns,
        ); deadline_err != nil {
            if close_err := packet_transport_close(transport, {}); close_err != nil {
                mcpe_runtime.destroy_error(close_err)
            }
            err = deadline_err
            return
        }
        connection = {
            transport = transport,
            remote = connected_remote,
        }
        return
    }
    native_socket, socket_err := net.make_unbound_udp_socket(
        net.family_from_address(remote.address),
    )
    if socket_err != nil {
        err = network_error("raknet.dial.socket")
        return
    }
    connection = {
        socket = native_socket,
        remote = remote,
    }
    return
}

dialer_discover_mtu :: proc(
    dialer: Dialer,
    connection: Dial_Transport,
    client_id: i64,
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
            // Pinned go-raknet's request1 discards every net.Conn.Write
            // error. The read side observes a closed transport and exits.
            if send_err := dialer_send(
                connection,
                request.data[:],
                deadline_ns,
            ); send_err != nil {
                mcpe_runtime.destroy_error(send_err)
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
                    connection,
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
                if packet_remote != connection.remote {
                    continue
                }
                switch buffer[0] {
                case message.ID_OPEN_CONNECTION_REPLY_1:
                    reply := message.unmarshal_open_connection_reply_1(buffer[1:count]) or_return
                    if reply.server_guid == 0 ||
                       reply.mtu < MIN_MTU_SIZE ||
                       reply.mtu > 1500 {
                        // Pinned go-raknet sends Request2 even for this broken
                        // Reply1. OVH protection can require that packet before
                        // allowing the next valid Reply1 through.
                        workaround := message.marshal_open_connection_request_2({
                            server_address = message_address_from_endpoint(connection.remote),
                            mtu = reply.mtu,
                            client_guid = client_id,
                            server_has_security = reply.server_has_security,
                            cookie = reply.cookie,
                        })
                        if workaround_err := dialer_send(
                            connection,
                            workaround.data[:],
                            deadline_ns,
                        ); workaround_err != nil {
                            mcpe_runtime.destroy_error(workaround_err)
                        }
                        writer_destroy(&workaround)
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
    connection: Dial_Transport,
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
            server_address = message_address_from_endpoint(connection.remote),
            mtu = mtu,
            client_guid = client_id,
            server_has_security = server_security,
            cookie = cookie,
        })
        // Pinned go-raknet's openConnectionRequest2 likewise discards every
        // net.Conn.Write error. Preserve that offline-handshake quirk.
        if send_err := dialer_send(
            connection,
            request.data[:],
            deadline_ns,
        ); send_err != nil {
            mcpe_runtime.destroy_error(send_err)
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
                connection,
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
            if packet_remote != connection.remote {
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
    connection := dialer_make_transport(
        configured_dialer,
        remote,
        token,
        deadline_ns,
    ) or_return
    keep_transport := false
    defer if !keep_transport {
        if close_err := packet_transport_close(
            connection.transport,
            connection.socket,
        ); close_err != nil {
            mcpe_runtime.destroy_error(close_err)
        }
    }
    client_id := next_dialer_id()
    transient_error_count := 0
    mtu, security, cookie := dialer_discover_mtu(
        configured_dialer,
        connection,
        client_id,
        token,
        deadline_ns,
        &transient_error_count,
    ) or_return
    mtu = dialer_open_connection(
        configured_dialer,
        connection,
        client_id,
        mtu,
        security,
        cookie,
        token,
        deadline_ns,
        &transient_error_count,
    ) or_return
    conn = conn_create(
        connection.socket,
        connection.remote,
        mtu,
        .Client,
        true,
        context.allocator,
        connection.transport,
    ) or_return
    conn.error_log = configured_dialer.error_log
    keep_transport = true
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
            connection,
            buffer[:],
            deadline_ns,
        )
        if receive_err != nil {
            if receive_err.kind == .Timeout {
                mcpe_runtime.destroy_error(receive_err)
                continue
            }
            conn_log_receive_error(conn, receive_err)
            continue
        }
        if packet_remote != connection.remote {
            continue
        }
        if process_err := conn_receive(conn, buffer[:count]); process_err != nil {
            conn_log_receive_error(conn, process_err)
            continue
        }
        _, connected = channel.try_recv(conn.connected_event)
    }

    if connection.transport.vtable == nil {
        _ = net.set_option(
            connection.socket,
            .Receive_Timeout,
            100 * time.Millisecond,
        )
    } else if deadline_err := packet_transport_set_deadline(
        connection.transport,
        0,
    ); deadline_err != nil {
        conn_destroy(conn)
        conn = nil
        err = deadline_err
        return
    }
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

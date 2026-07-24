package raknet

import "core:net"
import "core:slice"
import "core:sync"
import channel "core:sync/chan"
import "core:testing"
import "core:thread"
import "core:time"
import message "mcpe:raknet/message"
import mcpe_runtime "mcpe:runtime"

cancel_after_delay :: proc(worker: ^thread.Thread) {
    time.sleep(50 * time.Millisecond)
    mcpe_runtime.cancel((^mcpe_runtime.Cancel_Token)(worker.data))
}

test_pong_data_proc :: proc "odin" (
    user_data: rawptr,
    remote: net.Endpoint,
) -> []u8 {
    _ = user_data
    _ = remote
    return transmute([]u8)string("MCPE;dynamic;1001;1.26.30")
}

test_upstream_dial :: proc "odin" (
    user_data: rawptr,
    remote: net.Endpoint,
) -> (socket: net.UDP_Socket, err: mcpe_runtime.Error) {
    _ = remote
    (^bool)(user_data)^ = true
    native_socket, socket_err := net.make_bound_udp_socket(net.IP4_Loopback, 0)
    if socket_err != nil {
        err = network_error("raknet.test_upstream_dial")
        return
    }
    return native_socket, nil
}

TEST_UPSTREAM_DIALER_VTABLE := Upstream_Dialer_VTable{
    dial = test_upstream_dial,
}

test_upstream_listen :: proc "odin" (
    user_data: rawptr,
    endpoint: net.Endpoint,
) -> (socket: net.UDP_Socket, err: mcpe_runtime.Error) {
    (^bool)(user_data)^ = true
    native_socket, socket_err := net.make_bound_udp_socket(
        endpoint.address,
        endpoint.port,
    )
    if socket_err != nil {
        err = network_error("raknet.test_upstream_listen")
        return
    }
    return native_socket, nil
}

TEST_UPSTREAM_LISTENER_VTABLE := Upstream_Packet_Listener_VTable{
    listen = test_upstream_listen,
}

Test_Error_Log :: struct {
    count: i64,
    kind:  mcpe_runtime.Error_Kind,
}

test_error_report :: proc "odin" (
    user_data: rawptr,
    err: mcpe_runtime.Error,
) {
    log := (^Test_Error_Log)(user_data)
    log.kind = err.kind
    _ = sync.atomic_add(&log.count, 1)
}

@(test)
uint24_round_trip :: proc(t: ^testing.T) {
    values := [?]UInt24{0, 1, 0xff, 0xffff, 0xff_ffff}
    for expected in values {
        bytes: [3]u8
        store_u24_le(bytes[:], expected)
        testing.expect_value(t, load_u24_le(bytes[:]), expected)
    }
}

@(test)
uint24_wraps_at_wire_width :: proc(t: ^testing.T) {
    value := UInt24(UINT24_MASK)
    testing.expect_value(t, uint24_inc(&value), UInt24(UINT24_MASK))
    testing.expect_value(t, value, UInt24(0))
    testing.expect(t, uint24_before(UInt24(UINT24_MASK), UInt24(0)))
    testing.expect_value(
        t,
        uint24_forward_distance(UInt24(UINT24_MASK - 1), UInt24(1)),
        u32(3),
    )
}

@(test)
binary_endian_round_trip :: proc(t: ^testing.T) {
    w := writer()
    defer writer_destroy(&w)
    write_u16_be(&w, 0x1234)
    write_u32_be(&w, 0x5678_9abc)
    write_u64_be(&w, 0xdef0_1234_5678_9abc)

    r := reader(w.data[:])
    a, a_err := read_u16_be(&r)
    b, b_err := read_u32_be(&r)
    c, c_err := read_u64_be(&r)
    testing.expect(t, a_err == nil)
    testing.expect(t, b_err == nil)
    testing.expect(t, c_err == nil)
    testing.expect_value(t, a, 0x1234)
    testing.expect_value(t, b, 0x5678_9abc)
    testing.expect_value(t, c, 0xdef0_1234_5678_9abc)
}

@(test)
connection_reliable_echo :: proc(t: ^testing.T) {
    listener, listen_err := listen("127.0.0.1:0")
    testing.expect(t, listen_err == nil)
    if listen_err != nil {
        return
    }
    defer destroy_listener(listener)

    address := net.endpoint_to_string(listener_address(listener))
    client, dial_err := dial_timeout(address, 3 * time.Second)
    testing.expect(t, dial_err == nil)
    if dial_err != nil {
        return
    }
    defer conn_destroy(client)

    server, accept_err := accept(listener)
    testing.expect(t, accept_err == nil)
    if accept_err != nil {
        return
    }
    defer conn_destroy(server)

    expected := make([]u8, 4096)
    defer delete(expected)
    for &value, index in expected {
        value = u8(index + 0x80)
    }

    written, write_err := write(client, expected)
    testing.expect(t, write_err == nil)
    testing.expect_value(t, written, len(expected))
    if write_err != nil {
        return
    }

    received := make([]u8, len(expected))
    defer delete(received)
    read_count, read_err := read(server, received)
    testing.expect(t, read_err == nil)
    testing.expect_value(t, read_count, len(expected))
    testing.expect(t, slice.equal(received, expected))
    if read_err != nil {
        return
    }

    written, write_err = write(server, received)
    testing.expect(t, write_err == nil)
    testing.expect_value(t, written, len(expected))
    if write_err != nil {
        return
    }

    for &value in received {
        value = 0
    }
    read_count, read_err = read(client, received)
    testing.expect(t, read_err == nil)
    testing.expect_value(t, read_count, len(expected))
    testing.expect(t, slice.equal(received, expected))
}

@(test)
listener_ping_round_trip :: proc(t: ^testing.T) {
    listener, listen_err := listen("127.0.0.1:0")
    testing.expect(t, listen_err == nil)
    if listen_err != nil {
        return
    }
    defer destroy_listener(listener)

    expected := transmute([]u8)string("MCPE;mcpe-odin;1001;1.26.30")
    pong_err := set_pong_data(listener, expected)
    testing.expect(t, pong_err == nil)
    if pong_err != nil {
        return
    }

    address := net.endpoint_to_string(listener_address(listener))
    actual, ping_err := ping_timeout(address, time.Second)
    testing.expect(t, ping_err == nil)
    if ping_err != nil {
        return
    }
    defer delete(actual)
    testing.expect(t, slice.equal(actual, expected))
}

@(test)
listener_dynamic_pong_provider :: proc(t: ^testing.T) {
    listener, listen_err := listen("127.0.0.1:0")
    testing.expect(t, listen_err == nil)
    if listen_err != nil {
        return
    }
    defer destroy_listener(listener)

    set_pong_data_proc(listener, test_pong_data_proc)
    expected := test_pong_data_proc(nil, {})
    address := net.endpoint_to_string(listener_address(listener))
    actual, ping_err := ping_timeout(address, time.Second)
    testing.expect(t, ping_err == nil)
    if ping_err != nil {
        return
    }
    defer delete(actual)
    testing.expect(t, slice.equal(actual, expected))
}

@(test)
deadline_methods_match_upstream_not_supported :: proc(t: ^testing.T) {
    errors := [?]mcpe_runtime.Error{
        set_read_deadline(nil, {}),
        set_write_deadline(nil, {}),
        set_deadline(nil, {}),
    }
    for err in errors {
        testing.expect(t, err != nil)
        if err != nil {
            testing.expect_value(
                t,
                err.kind,
                mcpe_runtime.Error_Kind.Not_Supported,
            )
            mcpe_runtime.destroy_error(err)
        }
    }
}

@(test)
custom_upstream_dialer_connects :: proc(t: ^testing.T) {
    listener, listen_err := listen("127.0.0.1:0")
    testing.expect(t, listen_err == nil)
    if listen_err != nil {
        return
    }
    defer destroy_listener(listener)

    called := false
    dialer := Dialer{
        upstream_dialer = {
            user_data = &called,
            vtable = &TEST_UPSTREAM_DIALER_VTABLE,
        },
    }
    address := net.endpoint_to_string(listener_address(listener))
    client, dial_err := dialer_dial_timeout(dialer, address, 3 * time.Second)
    testing.expect(t, dial_err == nil)
    testing.expect(t, called)
    if dial_err != nil {
        return
    }
    defer conn_destroy(client)
    server, accept_err := accept(listener)
    testing.expect(t, accept_err == nil)
    if accept_err == nil {
        conn_destroy(server)
    }
}

@(test)
custom_upstream_packet_listener_binds :: proc(t: ^testing.T) {
    called := false
    listener, listen_err := listen_config(
        {
            upstream_packet_listener = {
                user_data = &called,
                vtable = &TEST_UPSTREAM_LISTENER_VTABLE,
            },
        },
        "127.0.0.1:0",
    )
    testing.expect(t, listen_err == nil)
    testing.expect(t, called)
    if listen_err != nil {
        return
    }
    defer destroy_listener(listener)

    address := net.endpoint_to_string(listener_address(listener))
    response, ping_err := ping_timeout(address, time.Second)
    testing.expect(t, ping_err == nil)
    if ping_err == nil {
        delete(response)
    }
}

@(test)
listener_reports_decode_errors :: proc(t: ^testing.T) {
    log: Test_Error_Log
    listener, listen_err := listen_config(
        {
            block_duration = -1,
            error_log = {
                user_data = &log,
                report = test_error_report,
            },
        },
        "127.0.0.1:0",
    )
    testing.expect(t, listen_err == nil)
    if listen_err != nil {
        return
    }
    defer destroy_listener(listener)

    sender, socket_err := net.make_bound_udp_socket(net.IP4_Loopback, 0)
    testing.expect(t, socket_err == nil)
    if socket_err != nil {
        return
    }
    defer net.close(sender)
    _, send_err := net.send_udp(
        sender,
        []u8{0x7f},
        listener_address(listener),
    )
    testing.expect(t, send_err == nil)
    if send_err != nil {
        return
    }

    for _ in 0..<100 {
        if sync.atomic_load(&log.count) != 0 {
            break
        }
        time.sleep(5 * time.Millisecond)
    }
    testing.expect_value(t, sync.atomic_load(&log.count), i64(1))
    testing.expect_value(t, log.kind, mcpe_runtime.Error_Kind.Protocol)
}

@(test)
dialer_logs_malformed_packets_without_closing :: proc(t: ^testing.T) {
    listener, listen_err := listen("127.0.0.1:0")
    testing.expect(t, listen_err == nil)
    if listen_err != nil {
        return
    }
    defer destroy_listener(listener)

    log: Test_Error_Log
    dialer := Dialer{
        error_log = {
            user_data = &log,
            report = test_error_report,
        },
    }
    address := net.endpoint_to_string(listener_address(listener))
    client, dial_err := dialer_dial_timeout(
        dialer,
        address,
        3 * time.Second,
    )
    testing.expect(t, dial_err == nil)
    if dial_err != nil {
        return
    }
    defer conn_destroy(client)
    server, accept_err := accept(listener)
    testing.expect(t, accept_err == nil)
    if accept_err != nil {
        return
    }
    defer conn_destroy(server)

    _, malformed_err := net.send_udp(
        listener.socket,
        []u8{BIT_FLAG_ACK | BIT_FLAG_DATAGRAM},
        client.local,
    )
    testing.expect(t, malformed_err == nil)
    if malformed_err != nil {
        return
    }
    for _ in 0..<100 {
        if sync.atomic_load(&log.count) != 0 {
            break
        }
        time.sleep(5 * time.Millisecond)
    }
    testing.expect_value(t, sync.atomic_load(&log.count), i64(1))
    testing.expect_value(
        t,
        log.kind,
        mcpe_runtime.Error_Kind.Unexpected_EOF,
    )

    expected := []u8{0x41, 0x42, 0x43}
    _, write_err := write(server, expected)
    testing.expect(t, write_err == nil)
    if write_err != nil {
        mcpe_runtime.destroy_error(write_err)
        return
    }
    response: [3]u8
    count, read_err := read(client, response[:])
    testing.expect(t, read_err == nil)
    if read_err != nil {
        mcpe_runtime.destroy_error(read_err)
        return
    }
    testing.expect_value(t, count, len(expected))
    testing.expect(t, slice.equal(response[:count], expected))
}

@(test)
duplicate_handshake_completion_is_rejected :: proc(t: ^testing.T) {
    server := Conn{
        mode = .Server,
        connected = true,
    }
    handled, server_err := conn_handle_control(
        &server,
        []u8{message.ID_NEW_INCOMING_CONNECTION},
    )
    testing.expect(t, handled)
    testing.expect(t, server_err != nil)
    if server_err != nil {
        testing.expect_value(
            t,
            server_err.kind,
            mcpe_runtime.Error_Kind.Protocol,
        )
        mcpe_runtime.destroy_error(server_err)
    }

    accepted := message.marshal_connection_request_accepted({})
    defer writer_destroy(&accepted)
    client := Conn{
        mode = .Client,
        connected = true,
    }
    client_err: mcpe_runtime.Error
    handled, client_err = conn_handle_control(
        &client,
        accepted.data[:],
    )
    testing.expect(t, handled)
    testing.expect(t, client_err != nil)
    if client_err != nil {
        testing.expect_value(
            t,
            client_err.kind,
            mcpe_runtime.Error_Kind.Protocol,
        )
        mcpe_runtime.destroy_error(client_err)
    }
}

@(test)
connected_pong_rejects_future_ping_time :: proc(t: ^testing.T) {
    pong := message.marshal_connected_pong({
        ping_time = timestamp() + 10_000,
    })
    conn: Conn
    handled, err := conn_handle_control(&conn, pong[:])
    testing.expect(t, handled)
    testing.expect(t, err != nil)
    if err != nil {
        testing.expect_value(
            t,
            err.kind,
            mcpe_runtime.Error_Kind.Protocol,
        )
        mcpe_runtime.destroy_error(err)
    }
}

@(test)
connected_pong_send_is_unreliable :: proc(t: ^testing.T) {
    sink, sink_err := net.make_bound_udp_socket(net.IP4_Loopback, 0)
    testing.expect(t, sink_err == nil)
    if sink_err != nil {
        return
    }
    defer net.close(sink)
    remote, remote_err := net.bound_endpoint(sink)
    testing.expect(t, remote_err == nil)
    if remote_err != nil {
        return
    }
    sender, sender_err := net.make_bound_udp_socket(net.IP4_Loopback, 0)
    testing.expect(t, sender_err == nil)
    if sender_err != nil {
        return
    }
    defer net.close(sender)

    conn := Conn{
        socket = sender,
        remote = remote,
        mtu = MAX_MTU_SIZE,
        allocator = context.allocator,
        resend = resend_map_init(),
    }
    defer resend_map_destroy(&conn.resend)
    pong := message.marshal_connected_pong({})
    err := conn_send_unreliable_control(&conn, pong[:])
    testing.expect(t, err == nil)
    testing.expect_value(t, len(conn.resend.unacknowledged), 0)
}

@(test)
close_drains_before_disconnect :: proc(t: ^testing.T) {
    listener, listen_err := listen("127.0.0.1:0")
    testing.expect(t, listen_err == nil)
    if listen_err != nil {
        return
    }
    defer destroy_listener(listener)

    address := net.endpoint_to_string(listener_address(listener))
    client, dial_err := dial_timeout(address, 3 * time.Second)
    testing.expect(t, dial_err == nil)
    if dial_err != nil {
        return
    }
    server, accept_err := accept(listener)
    testing.expect(t, accept_err == nil)
    if accept_err != nil {
        conn_destroy(client)
        return
    }
    defer conn_destroy(server)

    started := time.now()
    close_err := close(client)
    testing.expect(t, close_err == nil)
    testing.expect(t, time.since(started) < 100 * time.Millisecond)
    testing.expect(t, !sync.atomic_load(&server.closed))

    for !sync.atomic_load(&server.closed) &&
        time.since(started) < 2500 * time.Millisecond {
        time.sleep(10 * time.Millisecond)
    }
    testing.expect(t, sync.atomic_load(&server.closed))
    testing.expect(t, time.since(started) < 2500 * time.Millisecond)
}

@(test)
connection_context_outlives_connection_storage :: proc(t: ^testing.T) {
    listener, listen_err := listen("127.0.0.1:0")
    testing.expect(t, listen_err == nil)
    if listen_err != nil {
        return
    }
    defer destroy_listener(listener)

    address := net.endpoint_to_string(listener_address(listener))
    client, dial_err := dial_timeout(address, 3 * time.Second)
    testing.expect(t, dial_err == nil)
    if dial_err != nil {
        return
    }
    server, accept_err := accept(listener)
    testing.expect(t, accept_err == nil)
    if accept_err != nil {
        conn_destroy(client)
        return
    }
    defer conn_destroy(server)

    lifecycle := connection_context(client)
    defer destroy_context(&lifecycle)
    testing.expect(t, !context_cancelled(lifecycle))
    conn_destroy(client)
    testing.expect(t, context_cancelled(lifecycle))
}

@(test)
dial_context_observes_pre_cancelled_token :: proc(t: ^testing.T) {
    token: mcpe_runtime.Cancel_Token
    mcpe_runtime.cancel(&token)
    conn, err := dial_context(&token, "127.0.0.1:1", time.Second)
    testing.expect(t, conn == nil)
    testing.expect(t, err != nil)
    if err != nil {
        testing.expect_value(t, err.kind, mcpe_runtime.Error_Kind.Cancelled)
        mcpe_runtime.destroy_error(err)
    }
}

@(test)
dial_timeout_honours_deadline :: proc(t: ^testing.T) {
    started := time.now()
    conn, err := dial_timeout("127.0.0.1:1", 250 * time.Millisecond)
    elapsed := time.since(started)
    testing.expect(t, conn == nil)
    testing.expect(t, err != nil)
    testing.expect(t, elapsed < time.Second)
    if err != nil {
        testing.expect_value(t, err.kind, mcpe_runtime.Error_Kind.Timeout)
        mcpe_runtime.destroy_error(err)
    }
}

@(test)
ping_context_observes_cancellation_while_waiting :: proc(t: ^testing.T) {
    sink, socket_err := net.make_bound_udp_socket(net.IP4_Loopback, 0)
    testing.expect(t, socket_err == nil)
    if socket_err != nil {
        return
    }
    defer net.close(sink)
    endpoint, endpoint_err := net.bound_endpoint(sink)
    testing.expect(t, endpoint_err == nil)
    if endpoint_err != nil {
        return
    }

    token: mcpe_runtime.Cancel_Token
    worker := thread.create(cancel_after_delay)
    worker.data = &token
    thread.start(worker)
    started := time.now()
    response, err := ping_context(
        &token,
        net.endpoint_to_string(endpoint),
        time.Second,
    )
    elapsed := time.since(started)
    thread.join(worker)
    thread.destroy(worker)

    testing.expect(t, response == nil)
    testing.expect(t, err != nil)
    testing.expect(t, elapsed < 500 * time.Millisecond)
    if err != nil {
        testing.expect_value(t, err.kind, mcpe_runtime.Error_Kind.Cancelled)
        mcpe_runtime.destroy_error(err)
    }
}

@(test)
ping_timeout_treats_linux_eagain_as_timeout :: proc(t: ^testing.T) {
    sink, socket_err := net.make_bound_udp_socket(net.IP4_Loopback, 0)
    testing.expect(t, socket_err == nil)
    if socket_err != nil {
        return
    }
    defer net.close(sink)
    endpoint, endpoint_err := net.bound_endpoint(sink)
    testing.expect(t, endpoint_err == nil)
    if endpoint_err != nil {
        return
    }

    started := time.now()
    response, err := ping_timeout(
        net.endpoint_to_string(endpoint),
        250 * time.Millisecond,
    )
    elapsed := time.since(started)
    testing.expect(t, response == nil)
    testing.expect(t, err != nil)
    testing.expect(t, elapsed >= 200 * time.Millisecond)
    testing.expect(t, elapsed < time.Second)
    if err != nil {
        testing.expect_value(t, err.kind, mcpe_runtime.Error_Kind.Timeout)
        mcpe_runtime.destroy_error(err)
    }
}

@(test)
listener_destroy_releases_unaccepted_connection :: proc(t: ^testing.T) {
    listener, listen_err := listen("127.0.0.1:0")
    testing.expect(t, listen_err == nil)
    if listen_err != nil {
        return
    }

    address := net.endpoint_to_string(listener_address(listener))
    client, dial_err := dial_timeout(address, 3 * time.Second)
    testing.expect(t, dial_err == nil)
    if dial_err != nil {
        destroy_listener(listener)
        return
    }

    started := time.now()
    for channel.len(listener.incoming) == 0 &&
        time.since(started) < 500 * time.Millisecond {
        time.sleep(time.Millisecond)
    }
    testing.expect(t, channel.len(listener.incoming) == 1)
    destroy_listener(listener)
    conn_destroy(client)
}

@(test)
write_rejects_more_splits_than_receiver_accepts :: proc(t: ^testing.T) {
    listener, listen_err := listen("127.0.0.1:0")
    testing.expect(t, listen_err == nil)
    if listen_err != nil {
        return
    }
    defer destroy_listener(listener)

    address := net.endpoint_to_string(listener_address(listener))
    client, dial_err := dial_timeout(address, 3 * time.Second)
    testing.expect(t, dial_err == nil)
    if dial_err != nil {
        return
    }
    defer conn_destroy(client)

    server, accept_err := accept(listener)
    testing.expect(t, accept_err == nil)
    if accept_err != nil {
        return
    }
    defer conn_destroy(server)

    split_payload_size :=
        int(effective_mtu(client)) -
        PACKET_ADDITIONAL_SIZE -
        SPLIT_ADDITIONAL_SIZE
    payload := make([]u8, split_payload_size * MAX_SPLIT_COUNT + 1)
    defer delete(payload)
    written, write_err := write(client, payload)
    testing.expect_value(t, written, 0)
    testing.expect(t, write_err != nil)
    if write_err != nil {
        testing.expect_value(
            t,
            write_err.kind,
            mcpe_runtime.Error_Kind.Limit_Exceeded,
        )
        mcpe_runtime.destroy_error(write_err)
    }
}

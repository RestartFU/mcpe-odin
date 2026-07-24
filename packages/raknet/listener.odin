package raknet

import "core:crypto"
import "core:hash"
import "core:mem"
import "core:net"
import "core:sync"
import channel "core:sync/chan"
import "core:thread"
import "core:time"
import message "mcpe:raknet/message"
import mcpe_runtime "mcpe:runtime"

Pong_Data_Proc :: proc "odin" (
    user_data: rawptr,
    remote: net.Endpoint,
) -> []u8

Upstream_Listen_Proc :: proc "odin" (
    user_data: rawptr,
    endpoint: net.Endpoint,
) -> (socket: net.UDP_Socket, err: mcpe_runtime.Error)

Upstream_Packet_Listener_VTable :: struct {
    listen: Upstream_Listen_Proc,
}

Upstream_Packet_Listener :: struct {
    user_data: rawptr,
    vtable:    ^Upstream_Packet_Listener_VTable,
}

MAX_BLOCK_ENTRIES         :: 4096
MAX_HALF_OPEN_CONNECTIONS :: 128
MAX_LISTENER_CONNECTIONS  :: 4096

Listen_Config :: struct {
    disable_cookies: bool,
    max_mtu:         u16,
    block_duration:  time.Duration,
    error_log:       mcpe_runtime.Error_Logger,
    pong_data:       []u8,
    pong_data_proc:  Pong_Data_Proc,
    pong_user_data:  rawptr,
    upstream_packet_listener: Upstream_Packet_Listener,
}

Listener :: struct {
    allocator:   mem.Allocator,
    config:      Listen_Config,
    socket:      net.UDP_Socket,
    endpoint:    net.Endpoint,
    id:          i64,
    cookie_salt: u64,
    previous_salt: u64,
    closed:      bool,
    mutex:       sync.Mutex,
    incoming:    channel.Chan(^Conn),
    connections: map[net.Endpoint]^Conn,
    owned:       map[^Conn]bool,
    retired:     [dynamic]^Conn,
    half_open_count: int,
    blocks:      map[[16]u8]i64,
    last_security_tick: i64,
    security_ticks:     u64,
    worker:      ^thread.Thread,
    pong_data:   []u8,
}

random_u64 :: proc() -> u64 {
    bytes: [8]u8
    crypto.rand_bytes(bytes[:])
    return load_u64_be(bytes[:])
}

listener_cookie :: proc(listener: ^Listener, remote: net.Endpoint, salt: u64) -> u32 {
    if listener.config.disable_cookies {
        return 0
    }
    data: [26]u8
    store_u16_le(data[8:10], u16(remote.port))
    for index in 0..<8 {
        data[index] = u8(salt >> (u64(index) * 8))
    }
    address: [16]u8
    bytes := endpoint_ip_bytes(remote, &address)
    copy(data[10:], bytes)
    // Pinned go-raknet deliberately uses CRC32 here. Cookie generation is
    // protocol-observable, so replacing it would violate oracle parity.
    return hash.crc32(data[:10 + len(bytes)])
}

listener_ip_key :: proc(remote: net.Endpoint) -> [16]u8 {
    key: [16]u8
    _ = endpoint_ip_bytes(remote, &key)
    return key
}

listener_blocked :: proc(listener: ^Listener, remote: net.Endpoint) -> bool {
    key := listener_ip_key(remote)
    expires, exists := listener.blocks[key]
    if !exists {
        return false
    }
    now := mcpe_runtime.system_now_ns(nil)
    if now >= expires {
        delete_key(&listener.blocks, key)
        return false
    }
    return true
}

listener_gc_blocks_locked :: proc(listener: ^Listener, now: i64) {
    for key, expires in listener.blocks {
        if now >= expires {
            delete_key(&listener.blocks, key)
        }
    }
}

block_for :: proc(listener: ^Listener, remote: net.Endpoint, duration: time.Duration) {
    if duration <= 0 {
        return
    }
    if sync.mutex_guard(&listener.mutex) {
        now := mcpe_runtime.system_now_ns(nil)
        key := listener_ip_key(remote)
        if _, exists := listener.blocks[key]; !exists &&
           len(listener.blocks) >= MAX_BLOCK_ENTRIES {
            listener_gc_blocks_locked(listener, now)
            if len(listener.blocks) >= MAX_BLOCK_ENTRIES {
                return
            }
        }
        listener.blocks[key] = now + i64(duration)
    }
}

block :: proc(listener: ^Listener, remote: net.Endpoint) {
    block_for(listener, remote, listener.config.block_duration)
}

listener_on_connected :: proc "odin" (user_data: rawptr, conn: ^Conn) {
    listener := (^Listener)(user_data)
    if sync.mutex_guard(&listener.mutex) {
        listener.half_open_count = max(0, listener.half_open_count - 1)
    }
    if !channel.try_send(listener.incoming, conn) {
        conn_destroy(conn)
    }
}

listener_on_conn_closed :: proc "odin" (user_data: rawptr, conn: ^Conn) {
    listener := (^Listener)(user_data)
    if sync.mutex_guard(&listener.mutex) {
        delete_key(&listener.connections, conn.remote)
    }
    conn_release(conn)
}

listener_on_conn_released :: proc "odin" (user_data: rawptr, conn: ^Conn) {
    listener := (^Listener)(user_data)
    if sync.mutex_guard(&listener.mutex) {
        if !sync.atomic_load(&conn.connected) {
            listener.half_open_count = max(0, listener.half_open_count - 1)
        }
        delete_key(&listener.owned, conn)
        append(&listener.retired, conn)
    }
}

listener_reap_retired :: proc(listener: ^Listener) {
    for {
        conn: ^Conn
        if sync.mutex_guard(&listener.mutex) {
            for candidate, index in listener.retired {
                // Callback dispatch touches Conn after returning. Do not
                // finalize its storage until all dispatch wrappers are done.
                if sync.atomic_load(&candidate.release_finished) &&
                   sync.atomic_load(&candidate.callback_count) == 0 {
                    conn = candidate
                    unordered_remove(&listener.retired, index)
                    break
                }
            }
        }
        if conn == nil {
            return
        }
        conn_finalize(conn)
    }
}

listener_maintenance :: proc(listener: ^Listener) {
    listener_reap_retired(listener)
    now := mcpe_runtime.system_now_ns(nil)
    if sync.mutex_guard(&listener.mutex) {
        if now - listener.last_security_tick < i64(time.Second) {
            return
        }
        listener.last_security_tick = now
        listener.security_ticks += 1
        listener_gc_blocks_locked(listener, now)
        if listener.security_ticks % 2 == 0 {
            listener.previous_salt = listener.cookie_salt
            listener.cookie_salt = random_u64()
        }
    }
}

listen_config :: proc(config: Listen_Config, address: string) -> (
    listener: ^Listener,
    err: mcpe_runtime.Error,
) {
    endpoint := listen_endpoint(address) or_return
    socket: net.UDP_Socket
    if config.upstream_packet_listener.vtable != nil {
        if config.upstream_packet_listener.vtable.listen == nil {
            err = mcpe_runtime.make_error(
                .Invalid_Argument,
                "raknet.listen",
                "upstream packet listener has no listen procedure",
            )
            return
        }
        socket = config.upstream_packet_listener.vtable.listen(
            config.upstream_packet_listener.user_data,
            endpoint,
        ) or_return
    } else {
        native_socket, socket_err := net.make_bound_udp_socket(
            endpoint.address,
            endpoint.port,
        )
        if socket_err != nil {
            err = network_error("raknet.listen")
            return
        }
        socket = native_socket
    }
    keep_socket := false
    defer if !keep_socket {
        net.close(socket)
    }
    bound, bound_err := net.bound_endpoint(socket)
    if bound_err != nil {
        err = network_error("raknet.listen.bound_endpoint")
        return
    }
    if option_err := net.set_option(socket, .Receive_Timeout, 100 * time.Millisecond); option_err != nil {
        err = network_error("raknet.listen.deadline")
        return
    }

    listener = new(Listener, context.allocator)
    listener.allocator = context.allocator
    listener.config = config
    if listener.config.block_duration == 0 {
        listener.config.block_duration = 10 * time.Second
    }
    listener.config.max_mtu = clamp_mtu(listener.config.max_mtu, MIN_MTU_SIZE)
    listener.socket = socket
    listener.endpoint = bound
    listener.id = i64(random_u64())
    listener.cookie_salt = random_u64()
    listener.previous_salt = random_u64()
    listener.connections = make(map[net.Endpoint]^Conn, listener.allocator)
    listener.owned = make(map[^Conn]bool, listener.allocator)
    listener.retired = make([dynamic]^Conn, 0, 16, listener.allocator)
    listener.blocks = make(map[[16]u8]i64, listener.allocator)
    listener.last_security_tick = mcpe_runtime.system_now_ns(nil)
    listener.pong_data = make([]u8, len(config.pong_data), listener.allocator)
    copy(listener.pong_data, config.pong_data)

    incoming, incoming_err := channel.create(channel.Chan(^Conn), 64, context.allocator)
    if incoming_err != .None {
        delete(listener.connections)
        delete(listener.owned)
        delete(listener.retired)
        delete(listener.blocks)
        delete(listener.pong_data, listener.allocator)
        free(listener, listener.allocator)
        listener = nil
        err = mcpe_runtime.make_error(.Internal, "raknet.listen", "create incoming channel")
        return
    }
    listener.incoming = incoming
    listener.worker = thread.create(listener_thread)
    listener.worker.data = listener
    thread.start(listener.worker)
    keep_socket = true
    return
}

listen :: proc(address: string) -> (listener: ^Listener, err: mcpe_runtime.Error) {
    return listen_config({}, address)
}

accept :: proc(listener: ^Listener) -> (conn: ^Conn, err: mcpe_runtime.Error) {
    if listener == nil {
        err = mcpe_runtime.make_error(.Invalid_Argument, "raknet.accept", "nil listener")
        return
    }
    ok: bool
    conn, ok = channel.recv(listener.incoming)
    if !ok {
        err = mcpe_runtime.make_error(.Closed, "raknet.accept")
    }
    return
}

listener_address :: proc(listener: ^Listener) -> net.Endpoint {
    return listener.endpoint
}

listener_id :: proc(listener: ^Listener) -> i64 {
    return listener.id
}

set_pong_data :: proc(listener: ^Listener, data: []u8) -> mcpe_runtime.Error {
    if len(data) > int(max(i16)) {
        return mcpe_runtime.make_error(.Limit_Exceeded, "raknet.set_pong_data", "pong data exceeds int16")
    }
    owned := make([]u8, len(data), listener.allocator)
    copy(owned, data)
    if sync.mutex_guard(&listener.mutex) {
        delete(listener.pong_data, listener.allocator)
        listener.pong_data = owned
    }
    return nil
}

set_pong_data_proc :: proc(
    listener: ^Listener,
    pong_proc: Pong_Data_Proc,
    user_data: rawptr = nil,
) {
    if sync.mutex_guard(&listener.mutex) {
        listener.config.pong_data_proc = pong_proc
        listener.config.pong_user_data = user_data
    }
}

close_listener :: proc(listener: ^Listener) -> mcpe_runtime.Error {
    if listener == nil {
        return nil
    }
    first := false
    if sync.mutex_guard(&listener.mutex) {
        if !listener.closed {
            listener.closed = true
            first = true
        }
    }
    if first {
        net.close(listener.socket)
        channel.close(listener.incoming)
    }
    return nil
}

destroy_listener :: proc(listener: ^Listener) {
    if listener == nil {
        return
    }
    close_listener(listener)
    thread.join(listener.worker)
    thread.destroy(listener.worker)

    // Connected entries in the accept backlog own an application reference.
    // Release it while Listener callbacks are still valid.
    for {
        conn, ok := channel.try_recv(listener.incoming)
        if !ok {
            break
        }
        conn_destroy(conn)
    }

    owned := make([dynamic]^Conn, 0, len(listener.owned))
    releasing := make([dynamic]^Conn, 0, 4)
    if sync.mutex_guard(&listener.mutex) {
        for conn in listener.owned {
            // Keep live Conn storage while callbacks are detached. A zero
            // reference Conn is already committed to its release callback and
            // remains owned by Listener until that callback finishes.
            if conn_try_retain(conn) {
                append(&owned, conn)
            } else {
                append(&releasing, conn)
            }
        }
    }
    for conn in releasing {
        for !sync.atomic_load(&conn.release_finished) {
            time.sleep(time.Millisecond)
        }
    }
    delete(releasing)
    for conn in owned {
        conn_close_internal(conn)
        for !sync.atomic_load(&conn.close_finished) {
            time.sleep(time.Millisecond)
        }
        // Connections still referenced by accepted callers must no longer
        // call into a destroyed Listener when their final reference is released.
        if sync.mutex_guard(&conn.mutex) {
            conn.callback_data = nil
            conn.on_connected = nil
            conn.on_closed = nil
            conn.on_released = nil
        }
        for sync.atomic_load(&conn.callback_count) != 0 {
            time.sleep(time.Millisecond)
        }
        conn_release(conn)
    }
    delete(owned)
    listener_reap_retired(listener)

    delete(listener.connections)
    delete(listener.owned)
    delete(listener.retired)
    delete(listener.blocks)
    delete(listener.pong_data, listener.allocator)
    channel.destroy(listener.incoming)
    free(listener, listener.allocator)
}

listener_send :: proc(listener: ^Listener, data: []u8, remote: net.Endpoint) -> mcpe_runtime.Error {
    if _, send_err := net.send_udp(listener.socket, data, remote); send_err != nil {
        return network_error("raknet.listener.send")
    }
    return nil
}

listener_handle_unconnected :: proc(
    listener: ^Listener,
    data: []u8,
    remote: net.Endpoint,
) -> mcpe_runtime.Error {
    if len(data) == 0 {
        return mcpe_runtime.make_error(.Malformed, "raknet.listener", "zero packet")
    }
    switch data[0] {
    case message.ID_UNCONNECTED_PING, message.ID_UNCONNECTED_PING_OPEN_CONNECTIONS:
        // Pinned go-raknet treats both ping IDs identically, including while
        // its accept backlog is full. Preserve discovery behavior exactly.
        ping := message.unmarshal_unconnected_ping(data[1:]) or_return
        pong_data_proc: Pong_Data_Proc
        pong_user_data: rawptr
        if sync.mutex_guard(&listener.mutex) {
            pong_data_proc = listener.config.pong_data_proc
            pong_user_data = listener.config.pong_user_data
        }
        pong_data: []u8
        owned_pong_data: []u8
        if pong_data_proc != nil {
            pong_data = pong_data_proc(pong_user_data, remote)
        } else if sync.mutex_guard(&listener.mutex) {
            owned_pong_data = make([]u8, len(listener.pong_data), listener.allocator)
            copy(owned_pong_data, listener.pong_data)
            pong_data = owned_pong_data
        }
        if len(pong_data) > int(max(i16)) {
            if owned_pong_data != nil {
                delete(owned_pong_data, listener.allocator)
            }
            return mcpe_runtime.make_error(.Limit_Exceeded, "raknet.listener.pong", "pong data exceeds int16")
        }
        pong := message.marshal_unconnected_pong({
            ping_time = ping.ping_time,
            server_guid = listener.id,
            data = pong_data,
        })
        send_err := listener_send(listener, pong.data[:], remote)
        writer_destroy(&pong)
        if owned_pong_data != nil {
            delete(owned_pong_data, listener.allocator)
        }
        return send_err

    case message.ID_OPEN_CONNECTION_REQUEST_1:
        request := message.unmarshal_open_connection_request_1(data[1:]) or_return
        // Pinned go-raknet echoes a sub-minimum request MTU, then clamps only
        // its internal Conn. Preserve this malformed-peer handshake quirk.
        mtu := min(request.mtu, listener.config.max_mtu)
        if request.client_protocol != PROTOCOL_VERSION {
            response := message.marshal_incompatible_protocol_version({
                server_protocol = PROTOCOL_VERSION,
                server_guid = listener.id,
            })
            listener_send(listener, response[:], remote) or_return
            return mcpe_runtime.make_error(.Protocol, "raknet.listener.request_1", "incompatible protocol")
        }
        response := message.marshal_open_connection_reply_1({
            server_guid = listener.id,
            server_has_security = !listener.config.disable_cookies,
            cookie = listener_cookie(listener, remote, listener.cookie_salt),
            mtu = mtu,
        })
        defer writer_destroy(&response)
        return listener_send(listener, response.data[:], remote)

    case message.ID_OPEN_CONNECTION_REQUEST_2:
        request := message.unmarshal_open_connection_request_2(
            data[1:],
            !listener.config.disable_cookies,
        ) or_return
        if !listener.config.disable_cookies {
            current := listener_cookie(listener, remote, listener.cookie_salt)
            previous := listener_cookie(listener, remote, listener.previous_salt)
            if request.cookie != current && request.cookie != previous {
                return mcpe_runtime.make_error(.Protocol, "raknet.listener.request_2", "invalid cookie")
            }
        }
        // Pinned go-raknet rejects non-negative client GUIDs. Preserve this
        // compatibility quirk even though RakNet transmits a raw u64.
        if request.client_guid >= 0 {
            return mcpe_runtime.make_error(.Protocol, "raknet.listener.request_2", "client GUID must be negative")
        }
        mtu := min(request.mtu, listener.config.max_mtu)
        conn: ^Conn
        if sync.mutex_guard(&listener.mutex) {
            if _, exists := listener.connections[remote]; exists {
                return nil
            }
            if len(listener.owned) >= MAX_LISTENER_CONNECTIONS ||
               listener.half_open_count >= MAX_HALF_OPEN_CONNECTIONS {
                return mcpe_runtime.make_error(
                    .Limit_Exceeded,
                    "raknet.listener.request_2",
                    "listener connection budget exceeded",
                )
            }
            conn = conn_create(
                listener.socket,
                remote,
                mtu,
                .Server,
                false,
                listener.allocator,
            ) or_return
            conn.callback_data = listener
            conn.on_connected = listener_on_connected
            conn.on_closed = listener_on_conn_closed
            conn.on_released = listener_on_conn_released
            conn.error_log = listener.config.error_log
            listener.connections[remote] = conn
            listener.owned[conn] = true
            listener.half_open_count += 1
        }
        response := message.marshal_open_connection_reply_2({
            server_guid = listener.id,
            client_address = message_address_from_endpoint(remote),
            mtu = mtu,
        })
        send_err := listener_send(listener, response.data[:], remote)
        writer_destroy(&response)
        if send_err != nil {
            conn_close_internal(conn)
            return send_err
        }
        conn_start_threads(conn, false)
        return nil
    }
    if data[0] & BIT_FLAG_DATAGRAM != 0 {
        return nil
    }
    return mcpe_runtime.make_error(.Protocol, "raknet.listener", "unknown unconnected packet")
}

listener_thread :: proc(worker: ^thread.Thread) {
    listener := (^Listener)(worker.data)
    buffer: [1500]u8
    for !sync.atomic_load(&listener.closed) {
        listener_maintenance(listener)
        count, remote, receive_err := net.recv_udp(listener.socket, buffer[:])
        if receive_err != nil {
            if sync.atomic_load(&listener.closed) {
                break
            }
            if receive_err == .Timeout || receive_err == .Would_Block {
                continue
            }
            err := network_error("raknet.listener.receive")
            mcpe_runtime.report_error(listener.config.error_log, err)
            mcpe_runtime.destroy_error(err)
            continue
        }
        if count == 0 {
            continue
        }
        blocked := false
        conn: ^Conn
        if sync.mutex_guard(&listener.mutex) {
            blocked = listener_blocked(listener, remote)
            conn = listener.connections[remote]
        }
        if blocked {
            continue
        }
        if conn != nil {
            receive_error := conn_receive(conn, buffer[:count])
            if receive_error != nil {
                mcpe_runtime.report_error(listener.config.error_log, receive_error)
                mcpe_runtime.destroy_error(receive_error)
                conn_close_internal(conn)
            }
            continue
        }
        if handle_err := listener_handle_unconnected(listener, buffer[:count], remote); handle_err != nil {
            mcpe_runtime.report_error(listener.config.error_log, handle_err)
            mcpe_runtime.destroy_error(handle_err)
            // Pinned go-raknet blocks malformed unconnected senders before
            // authentication. Preserve observable BlockDuration behaviour.
            block(listener, remote)
        }
    }
    listener_maintenance(listener)
}

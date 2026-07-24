package raknet

import "core:net"
import "core:mem"
import "core:slice"
import "core:sync"
import channel "core:sync/chan"
import "core:thread"
import "core:time"
import message "mcpe:raknet/message"
import mcpe_runtime "mcpe:runtime"

Connection_Mode :: enum {
    Client,
    Server,
}

Connection_Callback :: proc "odin" (user_data: rawptr, conn: ^Conn)

Connection_Callback_Kind :: enum {
    Connected,
    Closed,
    Released,
}

MAX_INCOMING_BYTES :: i64(16 * 1024 * 1024)
MAX_PENDING_ACKS   :: 8192

Conn :: struct {
    allocator:   mem.Allocator,
    socket:      net.UDP_Socket,
    remote:      net.Endpoint,
    local:       net.Endpoint,
    owns_socket: bool,
    mode:        Connection_Mode,
    mtu:         u16,
    lifecycle_context: Conn_Context,

    mutex:          sync.Mutex,
    ack_mutex:      sync.Mutex,
    closed:         bool,
    connected:      bool,
    app_reference:  bool,
    app_released:   bool,
    closing_reference: bool,
    limits_enabled: bool,
    reference_count: i64,
    created_at:      i64,
    closing_at_ns:  i64,
    closing_acks_left: int,
    last_activity:  i64,
    rtt_ns:         i64,
    incoming_bytes: i64,
    close_finished: bool,
    callback_count: i64,
    release_finished: bool,

    sequence:      UInt24,
    sequence_index: UInt24,
    order_index:   UInt24,
    message_index: UInt24,
    split_id:      u32,

    window:          Datagram_Window,
    ordered:         Packet_Queue,
    splits:          Split_Assembler,
    resend:          Resend_Map,
    incoming:        channel.Chan([]u8),
    connected_event: channel.Chan(bool),
    pending_acks:    [dynamic]UInt24,

    receive_thread: ^thread.Thread,
    tick_thread:    ^thread.Thread,

    callback_data:         rawptr,
    on_connected:          Connection_Callback,
    on_closed:             Connection_Callback,
    on_released:           Connection_Callback,
    error_log:             mcpe_runtime.Error_Logger,
}

clamp_mtu :: proc(mtu, minimum: u16) -> u16 {
    if mtu == 0 || mtu > MAX_MTU_SIZE {
        return MAX_MTU_SIZE
    }
    return max(mtu, minimum)
}

effective_mtu :: proc(conn: ^Conn) -> u16 {
    return conn.mtu - 28
}

conn_destroy_empty_collections :: proc(conn: ^Conn) {
    datagram_window_destroy(&conn.window)
    packet_queue_destroy(&conn.ordered)
    split_assembler_destroy(&conn.splits)
    resend_map_destroy(&conn.resend)
    delete(conn.pending_acks)
    destroy_context(&conn.lifecycle_context)
}

conn_create :: proc(
    socket: net.UDP_Socket,
    remote: net.Endpoint,
    mtu: u16,
    mode: Connection_Mode,
    owns_socket: bool,
    allocator: mem.Allocator = context.allocator,
) -> (conn: ^Conn, err: mcpe_runtime.Error) {
    conn = new(Conn, allocator)
    conn.allocator = allocator
    conn.socket = socket
    conn.remote = remote
    conn.owns_socket = owns_socket
    conn.mode = mode
    conn.mtu = clamp_mtu(mtu, MIN_MTU_SIZE)
    conn.lifecycle_context = conn_context_create(allocator)
    conn.reference_count = 1
    conn.app_reference = mode == .Client
    // Resource ceilings protect both listeners and clients from hostile peers.
    conn.limits_enabled = true
    conn.window = datagram_window_init()
    conn.ordered = packet_queue_init()
    conn.splits = split_assembler_init(allocator)
    conn.resend = resend_map_init()
    conn.pending_acks = make([dynamic]UInt24, 0, 128, allocator)
    conn.created_at = mcpe_runtime.system_now_ns(nil)
    conn.last_activity = conn.created_at

    incoming, incoming_err := channel.create(channel.Chan([]u8), 4096, context.allocator)
    if incoming_err != .None {
        err = mcpe_runtime.make_error(.Internal, "raknet.conn_create", "create incoming channel")
        conn_destroy_empty_collections(conn)
        free(conn, allocator)
        conn = nil
        return
    }
    conn.incoming = incoming
    connected_event, connected_err := channel.create(channel.Chan(bool), 1, context.allocator)
    if connected_err != .None {
        channel.destroy(conn.incoming)
        conn_destroy_empty_collections(conn)
        err = mcpe_runtime.make_error(.Internal, "raknet.conn_create", "create connected channel")
        free(conn, allocator)
        conn = nil
        return
    }
    conn.connected_event = connected_event
    conn.local, _ = net.bound_endpoint(socket)
    return
}

conn_start_threads :: proc(conn: ^Conn, start_receiver: bool) {
    if start_receiver && conn.receive_thread == nil {
        conn.receive_thread = thread.create(conn_receive_thread)
        conn.receive_thread.data = conn
        thread.start(conn.receive_thread)
    }
    if conn.tick_thread == nil {
        conn.tick_thread = thread.create(conn_tick_thread)
        conn.tick_thread.data = conn
        thread.start(conn.tick_thread)
    }
}

conn_free_packet :: proc(conn: ^Conn, packet: ^Packet) {
    if packet == nil {
        return
    }
    delete(packet.content, conn.allocator)
    free(packet, conn.allocator)
}

conn_report_send_error :: proc(
    conn: ^Conn,
    operation: string,
) -> mcpe_runtime.Error {
    err := network_error(operation)
    mcpe_runtime.report_error(conn.error_log, err)
    return err
}

conn_log_receive_error :: proc(conn: ^Conn, err: mcpe_runtime.Error) {
    mcpe_runtime.report_error(conn.error_log, err)
    mcpe_runtime.destroy_error(err)
}

conn_finalize :: proc(conn: ^Conn) {
    if conn == nil {
        return
    }
    if conn.receive_thread != nil {
        thread.join(conn.receive_thread)
        thread.destroy(conn.receive_thread)
    }
    if conn.tick_thread != nil {
        thread.join(conn.tick_thread)
        thread.destroy(conn.tick_thread)
    }

    for _, packet in conn.resend.unacknowledged {
        conn_free_packet(conn, packet.packet)
    }
    for _, content in conn.ordered.entries {
        delete(content, conn.allocator)
    }
    for {
        content, ok := channel.try_recv(conn.incoming)
        if !ok {
            break
        }
        delete(content, conn.allocator)
    }
    datagram_window_destroy(&conn.window)
    packet_queue_destroy(&conn.ordered)
    split_assembler_destroy(&conn.splits)
    resend_map_destroy(&conn.resend)
    delete(conn.pending_acks)
    channel.destroy(conn.incoming)
    channel.destroy(conn.connected_event)
    destroy_context(&conn.lifecycle_context)
    free(conn, conn.allocator)
}

conn_try_retain :: proc(conn: ^Conn) -> bool {
    current := sync.atomic_load(&conn.reference_count)
    for current > 0 {
        observed, retained := sync.atomic_compare_exchange_weak(
            &conn.reference_count,
            current,
            current + 1,
        )
        if retained {
            return true
        }
        current = observed
    }
    return false
}

conn_invoke_callback :: proc(
    conn: ^Conn,
    kind: Connection_Callback_Kind,
) -> bool {
    callback: Connection_Callback
    user_data: rawptr
    if sync.mutex_guard(&conn.mutex) {
        switch kind {
        case .Connected:
            callback = conn.on_connected
        case .Closed:
            callback = conn.on_closed
        case .Released:
            callback = conn.on_released
        }
        user_data = conn.callback_data
        if callback != nil {
            _ = sync.atomic_add(&conn.callback_count, 1)
        }
    }
    if callback == nil {
        return false
    }
    callback(user_data, conn)
    _ = sync.atomic_add(&conn.callback_count, -1)
    return true
}

conn_release :: proc(conn: ^Conn) {
    previous := sync.atomic_add(&conn.reference_count, -1)
    assert(previous > 0)
    if previous != 1 {
        return
    }
    if !conn_invoke_callback(conn, .Released) {
        conn_finalize(conn)
        return
    }
    sync.atomic_store(&conn.release_finished, true)
}

conn_finalize_detached :: proc(data: rawptr) {
    // release_finished gates Listener-owned Released callbacks only. A
    // detached client has no such waiter, and conn_finalize frees this flag.
    conn_finalize((^Conn)(data))
}

conn_release_async :: proc(conn: ^Conn) {
    previous := sync.atomic_add(&conn.reference_count, -1)
    assert(previous > 0)
    if previous != 1 {
        return
    }
    if conn_invoke_callback(conn, .Released) {
        sync.atomic_store(&conn.release_finished, true)
        return
    }
    thread.run_with_data(conn, conn_finalize_detached)
}

conn_release_app_reference :: proc(conn: ^Conn) {
    release_app := false
    if sync.mutex_guard(&conn.mutex) {
        if conn.app_reference && !conn.app_released {
            conn.app_released = true
            release_app = true
        }
    }
    if release_app {
        conn_release(conn)
    }
}

conn_destroy :: proc(conn: ^Conn) {
    if conn == nil {
        return
    }
    conn_send_disconnect_notification(conn)
    _ = conn_close_internal(conn)
    conn_release_app_reference(conn)
}

conn_mark_connected :: proc(conn: ^Conn) {
    if sync.mutex_guard(&conn.mutex) {
        if conn.closed || conn.connected {
            return
        }
        if !conn.app_reference {
            conn.app_reference = true
            _ = sync.atomic_add(&conn.reference_count, 1)
        }
        conn.connected = true
    }
    _ = channel.try_send(conn.connected_event, true)
    _ = conn_invoke_callback(conn, .Connected)
}

conn_send_datagram_locked :: proc(conn: ^Conn, packet: ^Packet) -> mcpe_runtime.Error {
    w := writer(int(conn.mtu))
    defer writer_destroy(&w)
    write_u8(&w, BIT_FLAG_DATAGRAM | BIT_FLAG_NEEDS_B_AND_AS)
    sequence := uint24_inc(&conn.sequence)
    write_u24_le(&w, sequence)
    write_packet(&w, packet)

    if reliability_is_reliable(packet.reliability) {
        if !resend_map_add(&conn.resend, sequence, packet, mcpe_runtime.system_now_ns(nil)) {
            conn_free_packet(conn, packet)
            return mcpe_runtime.make_error(
                .Limit_Exceeded,
                "raknet.write",
                "unacknowledged resend budget exceeded",
            )
        }
    }
    if _, send_err := net.send_udp(conn.socket, w.data[:], conn.remote); send_err != nil {
        send_error := conn_report_send_error(conn, "raknet.write")
        if send_err != .Invalid_Argument {
            // Pinned go-raknet reports recoverable connected-send errors but
            // relies on ACK/NACK recovery instead of failing Write.
            mcpe_runtime.destroy_error(send_error)
            if !reliability_is_reliable(packet.reliability) {
                conn_free_packet(conn, packet)
            }
            return nil
        }
        if !reliability_is_reliable(packet.reliability) {
            conn_free_packet(conn, packet)
        }
        return send_error
    }
    if !reliability_is_reliable(packet.reliability) {
        conn_free_packet(conn, packet)
    }
    return nil
}

conn_write_reliability :: proc(
    conn: ^Conn,
    data: []u8,
    reliability: Reliability,
) -> (written: int, err: mcpe_runtime.Error) {
    if conn == nil {
        err = mcpe_runtime.make_error(.Invalid_Argument, "raknet.write", "nil connection")
        return
    }
    if sync.mutex_guard(&conn.mutex) {
        if conn.closed {
            err = mcpe_runtime.make_error(.Closed, "raknet.write")
            return
        }

        fragments := split_content(data, effective_mtu(conn)) or_return
        defer delete(fragments)
        if len(fragments) > MAX_SPLIT_COUNT {
            err = mcpe_runtime.make_error(
                .Limit_Exceeded,
                "raknet.write",
                "split count exceeds maximum",
            )
            return
        }
        order_index: UInt24
        if reliability_is_sequenced_or_ordered(reliability) {
            order_index = uint24_inc(&conn.order_index)
        }
        sequence_index: UInt24
        if reliability_is_sequenced(reliability) {
            sequence_index = uint24_inc(&conn.sequence_index)
        }
        split_id := u16(conn.split_id)
        if len(fragments) > 1 {
            conn.split_id += 1
        }

        for fragment, split_index in fragments {
            packet := new(Packet, conn.allocator)
            packet.reliability = reliability
            packet.order_index = order_index
            packet.sequence_index = sequence_index
            packet.content = make([]u8, len(fragment), conn.allocator)
            copy(packet.content, fragment)
            if reliability_is_reliable(reliability) {
                packet.message_index = uint24_inc(&conn.message_index)
            }
            packet.split = len(fragments) > 1
            if packet.split {
                packet.split_count = u32(len(fragments))
                packet.split_index = u32(split_index)
                packet.split_id = split_id
            }
            if send_error := conn_send_datagram_locked(conn, packet); send_error != nil {
                written = 0
                err = send_error
                return
            }
        }
        written = len(data)
    }
    return
}

write :: proc(conn: ^Conn, data: []u8) -> (written: int, err: mcpe_runtime.Error) {
    return conn_write_reliability(conn, data, .Reliable_Ordered)
}

conn_send_control :: proc(conn: ^Conn, data: []u8) -> mcpe_runtime.Error {
    _, err := write(conn, data)
    return err
}

conn_send_unreliable_control :: proc(
    conn: ^Conn,
    data: []u8,
) -> mcpe_runtime.Error {
    _, err := conn_write_reliability(conn, data, .Unreliable)
    return err
}

read_packet_owned :: proc(conn: ^Conn) -> (data: []u8, err: mcpe_runtime.Error) {
    if conn == nil {
        err = mcpe_runtime.make_error(.Invalid_Argument, "raknet.read", "nil connection")
        return
    }
    ok: bool
    data, ok = channel.recv(conn.incoming)
    if !ok {
        err = mcpe_runtime.make_error(.Closed, "raknet.read")
    } else {
        _ = sync.atomic_add(&conn.incoming_bytes, -i64(len(data)))
    }
    return
}

// read_packet returns an owned packet. The caller must delete it with the
// connection's construction allocator after use.
read_packet :: proc(conn: ^Conn) -> (data: []u8, err: mcpe_runtime.Error) {
    return read_packet_owned(conn)
}

read :: proc(conn: ^Conn, output: []u8) -> (read_count: int, err: mcpe_runtime.Error) {
    data := read_packet_owned(conn) or_return
    defer delete(data, conn.allocator)
    if len(output) < len(data) {
        err = mcpe_runtime.make_error(.Limit_Exceeded, "raknet.read", "buffer too small")
        return
    }
    read_count = copy(output, data)
    return
}

remote_address :: proc(conn: ^Conn) -> net.Endpoint {
    return conn.remote
}

local_address :: proc(conn: ^Conn) -> net.Endpoint {
    return conn.local
}

latency :: proc(conn: ^Conn) -> time.Duration {
    return time.Duration(sync.atomic_load(&conn.rtt_ns) / 2)
}

set_read_deadline :: proc(
    conn: ^Conn,
    deadline: time.Time,
) -> mcpe_runtime.Error {
    _ = conn
    _ = deadline
    return mcpe_runtime.make_error(
        .Not_Supported,
        "raknet.set_read_deadline",
        "feature not supported",
    )
}

set_write_deadline :: proc(
    conn: ^Conn,
    deadline: time.Time,
) -> mcpe_runtime.Error {
    _ = conn
    _ = deadline
    return mcpe_runtime.make_error(
        .Not_Supported,
        "raknet.set_write_deadline",
        "feature not supported",
    )
}

set_deadline :: proc(
    conn: ^Conn,
    deadline: time.Time,
) -> mcpe_runtime.Error {
    _ = conn
    _ = deadline
    return mcpe_runtime.make_error(
        .Not_Supported,
        "raknet.set_deadline",
        "feature not supported",
    )
}

conn_finish_close :: proc(conn: ^Conn) {
    mcpe_runtime.cancel(context_token(conn.lifecycle_context))
    channel.close(conn.incoming)
    channel.close(conn.connected_event)
    if conn.owns_socket {
        net.close(conn.socket)
    }
    _ = conn_invoke_callback(conn, .Closed)
    sync.atomic_store(&conn.close_finished, true)
}

conn_close_internal :: proc(conn: ^Conn) -> mcpe_runtime.Error {
    if conn == nil {
        return nil
    }
    first_close := false
    if sync.mutex_guard(&conn.mutex) {
        if !conn.closed {
            conn.closed = true
            first_close = true
        }
    }
    if !first_close {
        return nil
    }

    conn_finish_close(conn)
    release_closing := false
    if sync.mutex_guard(&conn.mutex) {
        if conn.closing_reference {
            conn.closing_reference = false
            release_closing = true
        }
    }
    if release_closing {
        // This may be called by a Conn worker. Finalize on a detached helper
        // if the closing reference is the final one.
        conn_release_async(conn)
    }
    return nil
}

conn_send_disconnect_notification :: proc(conn: ^Conn) {
    if conn == nil {
        return
    }
    if sync.atomic_load(&conn.closed) {
        return
    }
    notification := []u8{message.ID_DISCONNECT_NOTIFICATION}
    if _, notify_err := conn_write_reliability(
        conn,
        notification,
        .Reliable_Ordered,
    ); notify_err != nil {
        mcpe_runtime.destroy_error(notify_err)
    }
}

close :: proc(conn: ^Conn) -> mcpe_runtime.Error {
    if conn == nil {
        return nil
    }
    begin_close := false
    if sync.mutex_guard(&conn.mutex) {
        if !conn.closed && conn.closing_at_ns == 0 {
            sync.atomic_store(
                &conn.closing_at_ns,
                mcpe_runtime.system_now_ns(nil),
            )
            if conn_try_retain(conn) {
                conn.closing_reference = true
            }
            begin_close = true
        }
    }
    if begin_close || sync.atomic_load(&conn.closed) {
        conn_release_app_reference(conn)
    }
    return nil
}

conn_send_acknowledgement :: proc(conn: ^Conn, packets: []UInt24, flag: u8) -> mcpe_runtime.Error {
    ordered := make([]UInt24, len(packets))
    defer delete(ordered)
    copy(ordered, packets)
    slice.sort(ordered)

    offset := 0
    for offset < len(ordered) {
        ack := acknowledgement_init(len(ordered) - offset)
        for packet in ordered[offset:] {
            acknowledgement_add(&ack, packet)
        }
        w := writer(128)
        write_u8(&w, flag | BIT_FLAG_DATAGRAM)
        consumed := acknowledgement_write(&ack, &w, effective_mtu(conn))
        acknowledgement_destroy(&ack)
        if consumed == 0 {
            writer_destroy(&w)
            return mcpe_runtime.make_error(.Internal, "raknet.send_acknowledgement", "zero acknowledgement progress")
        }
        if _, send_err := net.send_udp(conn.socket, w.data[:], conn.remote); send_err != nil {
            writer_destroy(&w)
            return network_error("raknet.send_acknowledgement")
        }
        writer_destroy(&w)
        offset += consumed
    }
    return nil
}

conn_queue_ack :: proc(conn: ^Conn, sequence: UInt24) -> mcpe_runtime.Error {
    if sync.mutex_guard(&conn.ack_mutex) {
        if len(conn.pending_acks) >= MAX_PENDING_ACKS {
            return mcpe_runtime.make_error(
                .Limit_Exceeded,
                "raknet.receive_datagram",
                "pending acknowledgement budget exceeded",
            )
        }
        append(&conn.pending_acks, sequence)
    }
    return nil
}

conn_flush_acks :: proc(conn: ^Conn) -> mcpe_runtime.Error {
    if sync.mutex_guard(&conn.ack_mutex) {
        if len(conn.pending_acks) == 0 {
            return nil
        }
        send_err := conn_send_acknowledgement(
            conn,
            conn.pending_acks[:],
            BIT_FLAG_ACK,
        )
        if send_err != nil {
            return send_err
        }
        resize(&conn.pending_acks, 0)
    }
    return nil
}

conn_handle_ack :: proc(conn: ^Conn, data: []u8, negative: bool) -> mcpe_runtime.Error {
    ack := acknowledgement_init()
    defer acknowledgement_destroy(&ack)
    acknowledgement_read(&ack, data) or_return

    if sync.mutex_guard(&conn.mutex) {
        now := mcpe_runtime.system_now_ns(nil)
        for sequence in ack.packets {
            if negative {
                packet, found := resend_map_retransmit(&conn.resend, sequence, now)
                if found {
                    conn_send_datagram_locked(conn, packet) or_return
                }
            } else {
                packet, found := resend_map_acknowledge(&conn.resend, sequence, now)
                if found {
                    conn_free_packet(conn, packet)
                }
            }
        }
    }
    return nil
}

conn_handle_control :: proc(conn: ^Conn, data: []u8) -> (
    handled: bool,
    err: mcpe_runtime.Error,
) {
    if len(data) == 0 {
        return true, mcpe_runtime.make_error(.Malformed, "raknet.handle_packet", "zero packet length")
    }
    switch data[0] {
    case message.ID_CONNECTION_REQUEST:
        if conn.mode != .Server {
            return true, mcpe_runtime.make_error(.Protocol, "raknet.handle_packet", "unexpected connection request")
        }
        request := message.unmarshal_connection_request(data[1:]) or_return
        response := message.marshal_connection_request_accepted({
            client_address = message_address_from_endpoint(conn.remote),
            ping_time = request.request_time,
            pong_time = timestamp(),
        })
        defer writer_destroy(&response)
        return true, conn_send_control(conn, response.data[:])

    case message.ID_CONNECTION_REQUEST_ACCEPTED:
        if conn.mode != .Client {
            return true, mcpe_runtime.make_error(.Protocol, "raknet.handle_packet", "unexpected connection request accepted")
        }
        accepted := message.unmarshal_connection_request_accepted(data[1:]) or_return
        if sync.atomic_load(&conn.connected) {
            return true, mcpe_runtime.make_error(
                .Protocol,
                "raknet.handle_packet",
                "additional connection request accepted",
            )
        }
        response := message.marshal_new_incoming_connection({
            server_address = message_address_from_endpoint(conn.remote),
            ping_time = accepted.pong_time,
            pong_time = timestamp(),
        })
        send_err := conn_send_control(conn, response.data[:])
        writer_destroy(&response)
        if send_err != nil {
            return true, send_err
        }
        conn_mark_connected(conn)
        return true, nil

    case message.ID_NEW_INCOMING_CONNECTION:
        if conn.mode != .Server {
            return true, mcpe_runtime.make_error(.Protocol, "raknet.handle_packet", "unexpected new incoming connection")
        }
        // Pinned go-raknet deliberately neither decodes this packet nor tracks
        // a preceding ConnectionRequest, but rejects additional packets after
        // connection. Preserve both observable handshake quirks.
        if sync.atomic_load(&conn.connected) {
            return true, mcpe_runtime.make_error(
                .Protocol,
                "raknet.handle_packet",
                "additional new incoming connection",
            )
        }
        conn_mark_connected(conn)
        return true, nil

    case message.ID_CONNECTED_PING:
        ping := message.unmarshal_connected_ping(data[1:]) or_return
        pong := message.marshal_connected_pong({
            ping_time = ping.ping_time,
            pong_time = timestamp(),
        })
        return true, conn_send_unreliable_control(conn, pong[:])

    case message.ID_CONNECTED_PONG:
        pong := message.unmarshal_connected_pong(data[1:]) or_return
        if pong.ping_time > timestamp() {
            return true, mcpe_runtime.make_error(
                .Protocol,
                "raknet.handle_packet",
                "connected pong timestamp is in the future",
            )
        }
        return true, nil

    case message.ID_DISCONNECT_NOTIFICATION:
        conn_send_disconnect_notification(conn)
        conn_close_internal(conn)
        return true, nil

    case message.ID_DETECT_LOST_CONNECTIONS:
        ping := message.marshal_connected_ping({ping_time = timestamp()})
        return true, conn_send_control(conn, ping[:])
    }
    return false, nil
}

conn_deliver_content :: proc(conn: ^Conn, content: []u8) -> mcpe_runtime.Error {
    if len(content) == 0 {
        return mcpe_runtime.make_error(
            .Malformed,
            "raknet.handle_packet",
            "zero packet length",
        )
    }
    // ACK/NACK handling happens before this boundary. Pinned go-raknet drops
    // all decoded packet content once graceful closing has started.
    if sync.atomic_load(&conn.closing_at_ns) != 0 {
        return nil
    }
    handled, control_err := conn_handle_control(conn, content)
    if control_err != nil {
        return control_err
    }
    if handled {
        return nil
    }
    content_size := i64(len(content))
    previous_bytes := sync.atomic_add(&conn.incoming_bytes, content_size)
    if previous_bytes + content_size > MAX_INCOMING_BYTES {
        _ = sync.atomic_add(&conn.incoming_bytes, -content_size)
        conn_close_internal(conn)
        return mcpe_runtime.make_error(
            .Limit_Exceeded,
            "raknet.deliver",
            "incoming packet byte budget exceeded",
        )
    }
    owned := make([]u8, len(content), conn.allocator)
    copy(owned, content)
    if !channel.try_send(conn.incoming, owned) {
        _ = sync.atomic_add(&conn.incoming_bytes, -content_size)
        delete(owned, conn.allocator)
        conn_close_internal(conn)
        return mcpe_runtime.make_error(
            .Limit_Exceeded,
            "raknet.deliver",
            "incoming packet queue full",
        )
    }
    return nil
}

conn_receive_packet :: proc(conn: ^Conn, packet: ^Packet) -> mcpe_runtime.Error {
    content := packet.content
    content_owned := false
    if packet.split {
        complete: bool
        split_err: mcpe_runtime.Error
        content, complete, split_err = split_assembler_add(
            &conn.splits,
            packet,
            conn.limits_enabled,
        )
        if split_err != nil {
            return split_err
        }
        if !complete {
            return nil
        }
        content_owned = true
    }

    // Pinned go-raknet parses reliable and sequenced indices but only applies
    // receive ordering to Reliable_Ordered packets.
    if packet.reliability != .Reliable_Ordered {
        deliver_err := conn_deliver_content(conn, content)
        if content_owned {
            delete(content, conn.splits.allocator)
        }
        return deliver_err
    }
    if uint24_before(packet.order_index, conn.ordered.lowest) {
        if content_owned {
            delete(content, conn.splits.allocator)
        }
        return nil
    }
    if uint24_forward_distance(
        conn.ordered.lowest,
        packet.order_index,
    ) > u32(MAX_WINDOW_SIZE) {
        if content_owned {
            delete(content, conn.splits.allocator)
        }
        return mcpe_runtime.make_error(
            .Limit_Exceeded,
            "raknet.receive_packet",
            "ordered packet is outside receive window",
        )
    }
    queued := make([]u8, len(content), conn.allocator)
    copy(queued, content)
    if content_owned {
        delete(content, conn.splits.allocator)
    }
    if !packet_queue_put(&conn.ordered, packet.order_index, queued) {
        delete(queued, conn.allocator)
        return nil
    }
    if conn.limits_enabled && packet_queue_window_size(&conn.ordered) > MAX_WINDOW_SIZE {
        return mcpe_runtime.make_error(.Limit_Exceeded, "raknet.receive_packet", "ordered window too large")
    }
    packets := packet_queue_fetch(&conn.ordered)
    defer delete(packets)
    for queued_content in packets {
        deliver_err := conn_deliver_content(conn, queued_content)
        delete(queued_content, conn.allocator)
        if deliver_err != nil {
            return deliver_err
        }
    }
    return nil
}

conn_receive_datagram :: proc(conn: ^Conn, data: []u8) -> mcpe_runtime.Error {
    if len(data) < 3 {
        return mcpe_runtime.make_error(.Unexpected_EOF, "raknet.receive_datagram")
    }
    sequence := load_u24_le(data[:3])
    now := mcpe_runtime.system_now_ns(nil)
    if datagram_window_seen(&conn.window, sequence) {
        return nil
    }
    if uint24_forward_distance(
        conn.window.lowest,
        sequence,
    ) > u32(MAX_WINDOW_SIZE) {
        return mcpe_runtime.make_error(
            .Limit_Exceeded,
            "raknet.receive_datagram",
            "datagram is outside receive window",
        )
    }
    if !datagram_window_add(&conn.window, sequence, now) {
        return nil
    }
    conn_queue_ack(conn, sequence) or_return

    if conn.limits_enabled && datagram_window_size(&conn.window) > MAX_WINDOW_SIZE {
        return mcpe_runtime.make_error(.Limit_Exceeded, "raknet.receive_datagram", "datagram window too large")
    }

    if datagram_window_shift(&conn.window) == 0 {
        delay := max(conn.rtt_ns + conn.rtt_ns / 2, i64(1))
        missing := datagram_window_missing(&conn.window, now, delay)
        if len(missing) > 0 {
            nack_err := conn_send_acknowledgement(conn, missing[:], BIT_FLAG_NACK)
            delete(missing)
            if nack_err != nil {
                return nack_err
            }
        } else {
            delete(missing)
        }
    }
    offset := 3
    for offset < len(data) {
        packet, consumed, read_err := decode_packet(data[offset:])
        if read_err != nil {
            return read_err
        }
        conn_receive_packet(conn, &packet) or_return
        offset += consumed
    }
    return nil
}

conn_receive :: proc(conn: ^Conn, data: []u8) -> mcpe_runtime.Error {
    if len(data) == 0 {
        return nil
    }
    sync.atomic_store(&conn.last_activity, mcpe_runtime.system_now_ns(nil))
    if data[0] & BIT_FLAG_ACK != 0 {
        return conn_handle_ack(conn, data[1:], false)
    }
    if data[0] & BIT_FLAG_NACK != 0 {
        return conn_handle_ack(conn, data[1:], true)
    }
    if data[0] & BIT_FLAG_DATAGRAM != 0 {
        return conn_receive_datagram(conn, data[1:])
    }
    return nil
}

conn_receive_thread :: proc(worker: ^thread.Thread) {
    conn := (^Conn)(worker.data)
    buffer: [1500]u8
    for !sync.atomic_load(&conn.closed) {
        count, remote, receive_err := net.recv_udp(conn.socket, buffer[:])
        if receive_err != nil {
            if sync.atomic_load(&conn.closed) {
                return
            }
            if receive_err == .Timeout || receive_err == .Would_Block {
                continue
            }
            err := network_error("raknet.receive")
            conn_log_receive_error(conn, err)
            continue
        }
        if count == 0 || remote != conn.remote {
            continue
        }
        if receive_error := conn_receive(conn, buffer[:count]); receive_error != nil {
            conn_log_receive_error(conn, receive_error)
            // Pinned go-raknet's dialer logs malformed connected packets and
            // keeps its client receive loop alive.
            continue
        }
    }
}

conn_tick_thread :: proc(worker: ^thread.Thread) {
    conn := (^Conn)(worker.data)
    ticks := 0
    for !sync.atomic_load(&conn.closed) {
        time.sleep(100 * time.Millisecond)
        ticks += 1
        now := mcpe_runtime.system_now_ns(nil)
        if flush_err := conn_flush_acks(conn); flush_err != nil {
            mcpe_runtime.destroy_error(flush_err)
        }
        handshake_expired := false
        if conn.mode == .Server {
            if sync.mutex_guard(&conn.mutex) {
                if !conn.closed &&
                   !conn.connected &&
                   now - conn.created_at > i64(10 * time.Second) {
                    conn.closed = true
                    handshake_expired = true
                }
            }
        }
        if handshake_expired {
            conn_finish_close(conn)
            return
        }
        if ticks % 3 == 0 {
            if sync.mutex_guard(&conn.mutex) {
                rtt := resend_map_rtt(&conn.resend, now)
                sync.atomic_store(&conn.rtt_ns, rtt)
                delay := rtt + rtt / 2
                resend_sequences := make([dynamic]UInt24)
                for sequence, record in conn.resend.unacknowledged {
                    if now - record.timestamp > delay {
                        append(&resend_sequences, sequence)
                    }
                }
                for sequence in resend_sequences {
                    packet, found := resend_map_retransmit(&conn.resend, sequence, now)
                    if found {
                        if resend_err := conn_send_datagram_locked(conn, packet); resend_err != nil {
                            mcpe_runtime.destroy_error(resend_err)
                        }
                    }
                }
                delete(resend_sequences)
            }
        }
        closing_at_ns := sync.atomic_load(&conn.closing_at_ns)
        if closing_at_ns != 0 {
            unacknowledged := 0
            if sync.mutex_guard(&conn.mutex) {
                unacknowledged = len(conn.resend.unacknowledged)
            }
            drained := conn.closing_acks_left != 0 && unacknowledged == 0
            conn.closing_acks_left = unacknowledged
            elapsed := now - closing_at_ns
            if drained ||
               (unacknowledged == 0 && elapsed > i64(time.Second)) ||
               elapsed > i64(5 * time.Second) {
                conn_send_disconnect_notification(conn)
                conn_close_internal(conn)
                return
            }
            continue
        }
        if ticks % 5 == 0 && sync.atomic_load(&conn.connected) {
            ping := message.marshal_connected_ping({ping_time = timestamp()})
            if ping_err := conn_send_control(conn, ping[:]); ping_err != nil {
                mcpe_runtime.destroy_error(ping_err)
            }
            rtt := sync.atomic_load(&conn.rtt_ns)
            if now - sync.atomic_load(&conn.last_activity) > 5_000_000_000 + rtt * 2 {
                conn_close_internal(conn)
                return
            }
        }
    }
}

package raknet

import "core:slice"
import "core:testing"
import mcpe_runtime "mcpe:runtime"

@(test)
packet_round_trip :: proc(t: ^testing.T) {
    content := []u8{0x12, 0x34, 0x56}
    expected := Packet{
        reliability = .Reliable_Ordered,
        message_index = 4,
        order_index = 9,
        content = content,
        split = true,
        split_count = 3,
        split_index = 1,
        split_id = 17,
    }
    w := writer()
    defer writer_destroy(&w)
    write_packet(&w, &expected)
    actual, consumed, err := decode_packet(w.data[:])
    testing.expect(t, err == nil)
    testing.expect_value(t, consumed, len(w.data))
    testing.expect_value(t, actual.reliability, expected.reliability)
    testing.expect_value(t, actual.message_index, expected.message_index)
    testing.expect_value(t, actual.order_index, expected.order_index)
    testing.expect_value(t, actual.split_count, expected.split_count)
    testing.expect_value(t, actual.split_index, expected.split_index)
    testing.expect_value(t, actual.split_id, expected.split_id)
    testing.expect(t, slice.equal(actual.content, expected.content))
}

@(test)
packet_accepts_reserved_reliability_like_upstream :: proc(t: ^testing.T) {
    for reliability: u8 = 5; reliability <= 7; reliability += 1 {
        data := []u8{
            reliability << 5,
            0,
            8,
            0x42,
        }
        packet, consumed, err := decode_packet(data)
        testing.expect(t, err == nil)
        testing.expect_value(t, consumed, len(data))
        testing.expect_value(t, u8(packet.reliability), reliability)
        testing.expect(t, slice.equal(packet.content, data[3:]))
    }
}

@(test)
packet_split_respects_mtu :: proc(t: ^testing.T) {
    data: [4096]u8
    fragments, err := split_content(data[:], 1400)
    defer delete(fragments)
    testing.expect(t, err == nil)
    testing.expect_value(t, len(fragments), 3)
    for fragment in fragments {
        testing.expect(t, len(fragment) + PACKET_ADDITIONAL_SIZE + SPLIT_ADDITIONAL_SIZE <= 1400)
    }
}

@(test)
acknowledgement_never_exceeds_mtu :: proc(t: ^testing.T) {
    ack := acknowledgement_init()
    defer acknowledgement_destroy(&ack)
    for index in 0..<100 {
        acknowledgement_add(&ack, UInt24(index * 2))
    }
    w := writer()
    defer writer_destroy(&w)
    write_u8(&w, BIT_FLAG_ACK | BIT_FLAG_DATAGRAM)
    consumed := acknowledgement_write(&ack, &w, 20)
    testing.expect(t, consumed > 0)
    testing.expect(t, len(w.data) <= 20)
}

@(test)
acknowledgement_range_round_trip :: proc(t: ^testing.T) {
    expected := acknowledgement_init()
    defer acknowledgement_destroy(&expected)
    values := [?]UInt24{1, 2, 3, 8, 10, 11}
    for value in values {
        acknowledgement_add(&expected, value)
    }

    w := writer()
    defer writer_destroy(&w)
    consumed := acknowledgement_write(&expected, &w, 1400)
    testing.expect_value(t, consumed, len(expected.packets))

    actual := acknowledgement_init()
    defer acknowledgement_destroy(&actual)
    err := acknowledgement_read(&actual, w.data[:])
    testing.expect(t, err == nil)
    testing.expect(t, slice.equal(actual.packets[:], expected.packets[:]))
}

@(test)
acknowledgement_write_preserves_duplicate_records :: proc(t: ^testing.T) {
    ack := acknowledgement_init()
    defer acknowledgement_destroy(&ack)
    acknowledgement_add(&ack, 1)
    acknowledgement_add(&ack, 1)

    writer := writer()
    defer writer_destroy(&writer)
    consumed := acknowledgement_write(&ack, &writer, 1400)
    expected := []u8{
        0, 2,
        ACK_SINGLE, 1, 0, 0,
        ACK_SINGLE, 1, 0, 0,
    }
    testing.expect_value(t, consumed, 2)
    testing.expect(t, slice.equal(writer.data[:], expected))
}

@(test)
ordered_packet_queue :: proc(t: ^testing.T) {
    queue := packet_queue_init()
    defer packet_queue_destroy(&queue)
    a := []u8{1}
    b := []u8{2}
    testing.expect(t, packet_queue_put(&queue, 1, b))
    first := packet_queue_fetch(&queue)
    testing.expect_value(t, len(first), 0)
    delete(first)
    testing.expect(t, packet_queue_put(&queue, 0, a))
    packets := packet_queue_fetch(&queue)
    defer delete(packets)
    testing.expect_value(t, len(packets), 2)
    testing.expect(t, slice.equal(packets[0], a))
    testing.expect(t, slice.equal(packets[1], b))
}

@(test)
ordered_packet_queue_wraps :: proc(t: ^testing.T) {
    queue := packet_queue_init()
    defer packet_queue_destroy(&queue)
    queue.lowest = UInt24(UINT24_MASK - 1)
    queue.highest = queue.lowest

    testing.expect(t, packet_queue_put(&queue, UInt24(UINT24_MASK - 1), []u8{1}))
    testing.expect(t, packet_queue_put(&queue, UInt24(UINT24_MASK), []u8{2}))
    testing.expect(t, packet_queue_put(&queue, UInt24(0), []u8{3}))
    packets := packet_queue_fetch(&queue)
    defer delete(packets)
    testing.expect_value(t, len(packets), 3)
    testing.expect_value(t, packets[0][0], u8(1))
    testing.expect_value(t, packets[1][0], u8(2))
    testing.expect_value(t, packets[2][0], u8(3))
}

@(test)
datagram_window_reports_gap_after_delay :: proc(t: ^testing.T) {
    window := datagram_window_init()
    defer datagram_window_destroy(&window)
    testing.expect(t, datagram_window_add(&window, 0, 100))
    testing.expect(t, datagram_window_add(&window, 2, 100))
    testing.expect_value(t, datagram_window_shift(&window), 1)
    missing := datagram_window_missing(&window, 300, 100)
    defer delete(missing)
    testing.expect_value(t, len(missing), 1)
    testing.expect_value(t, missing[0], UInt24(1))
}

@(test)
datagram_window_wraps :: proc(t: ^testing.T) {
    window := datagram_window_init()
    defer datagram_window_destroy(&window)
    window.lowest = UInt24(UINT24_MASK)
    window.highest = window.lowest
    testing.expect(t, datagram_window_add(&window, UInt24(UINT24_MASK), 1))
    testing.expect(t, datagram_window_add(&window, UInt24(0), 1))
    testing.expect_value(t, datagram_window_shift(&window), 2)
    testing.expect_value(t, window.lowest, UInt24(1))
    testing.expect_value(t, datagram_window_size(&window), UInt24(0))
}

@(test)
datagram_window_rejects_far_indices :: proc(t: ^testing.T) {
    window := datagram_window_init()
    defer datagram_window_destroy(&window)
    far := uint24_add(window.lowest, u32(MAX_WINDOW_SIZE) + 1)
    testing.expect(t, !datagram_window_add(&window, far, 1))
    testing.expect_value(t, len(window.entries), 0)
}

@(test)
ordered_packet_queue_rejects_far_indices :: proc(t: ^testing.T) {
    queue := packet_queue_init()
    defer packet_queue_destroy(&queue)
    far := uint24_add(queue.lowest, u32(MAX_WINDOW_SIZE) + 1)
    testing.expect(t, !packet_queue_put(&queue, far, []u8{1}))
    testing.expect_value(t, len(queue.entries), 0)
}

@(test)
reliable_window_deduplicates_and_wraps :: proc(t: ^testing.T) {
    window := reliable_window_init()
    defer reliable_window_destroy(&window)

    testing.expect_value(
        t,
        reliable_window_add(&window, UInt24(UINT24_MASK)),
        Reliable_Window_Result.Added,
    )
    testing.expect_value(
        t,
        reliable_window_add(&window, UInt24(0)),
        Reliable_Window_Result.Added,
    )
    testing.expect_value(
        t,
        reliable_window_add(&window, UInt24(UINT24_MASK)),
        Reliable_Window_Result.Duplicate,
    )
    far := uint24_add(UInt24(0), u32(MAX_WINDOW_SIZE) + 1)
    testing.expect_value(
        t,
        reliable_window_add(&window, far),
        Reliable_Window_Result.Out_Of_Window,
    )
}

@(test)
sequenced_packets_discard_stale_indices :: proc(t: ^testing.T) {
    conn: Conn
    first := Packet{
        reliability = .Reliable_Sequenced,
        sequence_index = 10,
        order_index = 20,
    }
    accepted, err := conn_accept_sequenced(&conn, &first)
    testing.expect(t, err == nil)
    testing.expect(t, accepted)

    stale := first
    stale.sequence_index = 9
    accepted, err = conn_accept_sequenced(&conn, &stale)
    testing.expect(t, err == nil)
    testing.expect(t, !accepted)

    next := first
    next.sequence_index = 11
    accepted, err = conn_accept_sequenced(&conn, &next)
    testing.expect(t, err == nil)
    testing.expect(t, accepted)

    conn.ordered.lowest = 21
    delayed := next
    delayed.sequence_index = 12
    accepted, err = conn_accept_sequenced(&conn, &delayed)
    testing.expect(t, err == nil)
    testing.expect(t, !accepted)

    current := next
    current.order_index = 21
    current.sequence_index = 0
    accepted, err = conn_accept_sequenced(&conn, &current)
    testing.expect(t, err == nil)
    testing.expect(t, accepted)
}

@(test)
acknowledgements_are_bounded_and_batched :: proc(t: ^testing.T) {
    conn: Conn
    conn.pending_acks = make([dynamic]UInt24, 0, 4)
    defer delete(conn.pending_acks)

    testing.expect(t, conn_queue_ack(&conn, 10) == nil)
    testing.expect(t, conn_queue_ack(&conn, 11) == nil)
    testing.expect_value(t, len(conn.pending_acks), 2)

    resize(&conn.pending_acks, MAX_PENDING_ACKS)
    err := conn_queue_ack(&conn, 12)
    testing.expect(t, err != nil)
    if err != nil {
        testing.expect_value(
            t,
            err.kind,
            mcpe_runtime.Error_Kind.Limit_Exceeded,
        )
        mcpe_runtime.destroy_error(err)
    }
}

@(test)
malformed_acknowledgement_ranges_are_bounded :: proc(t: ^testing.T) {
    descending := []u8{
        0, 1,
        ACK_RANGE,
        10, 0, 0,
        9, 0, 0,
    }
    ack := acknowledgement_init()
    err := acknowledgement_read(&ack, descending)
    testing.expect(t, err != nil)
    if err != nil {
        testing.expect_value(
            t,
            err.kind,
            mcpe_runtime.Error_Kind.Limit_Exceeded,
        )
        mcpe_runtime.destroy_error(err)
    }
    acknowledgement_destroy(&ack)

    oversized := []u8{
        0, 1,
        ACK_RANGE,
        0, 0, 0,
        0xff, 0xff, 0xff,
    }
    ack = acknowledgement_init()
    err = acknowledgement_read(&ack, oversized)
    testing.expect(t, err != nil)
    testing.expect_value(t, len(ack.packets), 0)
    if err != nil {
        testing.expect_value(
            t,
            err.kind,
            mcpe_runtime.Error_Kind.Limit_Exceeded,
        )
        mcpe_runtime.destroy_error(err)
    }
    acknowledgement_destroy(&ack)
}

@(test)
acknowledgement_range_preserves_upstream_inclusive_limit :: proc(t: ^testing.T) {
    upstream_boundary := []u8{
        0, 1,
        ACK_RANGE,
        0, 0, 0,
        0, 32, 0,
    }
    ack := acknowledgement_init()
    err := acknowledgement_read(&ack, upstream_boundary)
    testing.expect(t, err == nil)
    testing.expect_value(t, len(ack.packets), 8193)
    acknowledgement_destroy(&ack)

    above_boundary := []u8{
        0, 1,
        ACK_RANGE,
        0, 0, 0,
        1, 32, 0,
    }
    ack = acknowledgement_init()
    err = acknowledgement_read(&ack, above_boundary)
    testing.expect(t, err != nil)
    testing.expect_value(t, len(ack.packets), 0)
    if err != nil {
        testing.expect_value(
            t,
            err.kind,
            mcpe_runtime.Error_Kind.Limit_Exceeded,
        )
        mcpe_runtime.destroy_error(err)
    }
    acknowledgement_destroy(&ack)
}

@(test)
resend_map_tracks_rtt :: proc(t: ^testing.T) {
    resend := resend_map_init()
    defer resend_map_destroy(&resend)
    packet: Packet
    testing.expect(t, resend_map_add(&resend, 7, &packet, 1_000))
    actual, found := resend_map_acknowledge(&resend, 7, 2_000)
    testing.expect(t, found)
    testing.expect(t, actual == &packet)
    testing.expect_value(t, resend_map_rtt(&resend, 2_000), i64(1_000))
}

@(test)
split_assembler_reassembles_out_of_order :: proc(t: ^testing.T) {
    assembler := split_assembler_init()
    defer split_assembler_destroy(&assembler)

    second := Packet{
        split = true,
        split_count = 2,
        split_index = 1,
        split_id = 5,
        content = []u8{3, 4},
    }
    first := second
    first.split_index = 0
    first.content = []u8{1, 2}

    _, complete, err := split_assembler_add(&assembler, &second, true)
    testing.expect(t, err == nil)
    testing.expect(t, !complete)

    content: []u8
    content, complete, err = split_assembler_add(&assembler, &first, true)
    defer delete(content)
    testing.expect(t, err == nil)
    testing.expect(t, complete)
    testing.expect(t, slice.equal(content, []u8{1, 2, 3, 4}))
}

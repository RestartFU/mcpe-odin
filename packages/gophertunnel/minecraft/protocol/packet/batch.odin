package gt_packet

import "core:mem"
import "core:slice"
import protocol "mcpe:gophertunnel/minecraft/protocol"
import mcpe_runtime "mcpe:runtime"

BATCH_HEADER         :: u8(0xfe)
MAXIMUM_BATCH_PACKETS :: 812
MAXIMUM_UNLIMITED_BATCH_PACKETS :: 65_536

encode_batch :: proc(
    packets: [][]u8,
    batch_header: []u8 = []u8{BATCH_HEADER},
    allocator: mem.Allocator = context.allocator,
) -> (data: []u8, err: mcpe_runtime.Error) {
    output := protocol.writer(0, 256, allocator)
    defer protocol.writer_destroy(&output)
    protocol.write_bytes(&output, batch_header)
    for packet in packets {
        if u64(len(packet)) > u64(max(u32)) {
            err = packet_error(
                .Limit_Exceeded,
                "gophertunnel.packet.encode_batch",
                "packet length exceeds uint32",
            )
            return
        }
        protocol.write_varuint32(&output, u32(len(packet)))
        protocol.write_bytes(&output, packet)
    }
    encoded := protocol.writer_bytes(&output)
    data = make([]u8, len(encoded), allocator)
    copy(data, encoded)
    return
}

// decode_batch returns an owned outer slice containing payloads borrowed from
// data. Delete the outer slice when finished; do not delete individual payloads.
decode_batch :: proc(
    data: []u8,
    batch_header: []u8 = []u8{BATCH_HEADER},
    check_packet_limit: bool = true,
    allocator: mem.Allocator = context.allocator,
) -> (result: [][]u8, err: mcpe_runtime.Error) {
    // Matches Decoder.Decode: a zero-byte transport read is not a batch error.
    if len(data) == 0 {
        return
    }
    if len(data) < len(batch_header) ||
       !slice.equal(data[:len(batch_header)], batch_header) {
        err = packet_error(
            .Malformed,
            "gophertunnel.packet.decode_batch",
            "invalid batch header",
        )
        return
    }

    input := protocol.reader(data[len(batch_header):], 0, true, allocator)
    packets := make([dynamic][]u8, 0, 8, allocator)
    defer delete(packets)
    for protocol.remaining(&input) != 0 {
        length := protocol.read_varuint32(&input) or_return
        if length == 0 {
            err = packet_error(
                .Malformed,
                "gophertunnel.packet.decode_batch",
                "empty packet",
            )
            return
        }
        if u64(length) > u64(protocol.remaining(&input)) {
            err = packet_error(
                .Unexpected_EOF,
                "gophertunnel.packet.decode_batch",
                "packet length exceeds remaining batch",
            )
            return
        }
        if check_packet_limit && len(packets) >= MAXIMUM_BATCH_PACKETS {
            err = packet_error(
                .Limit_Exceeded,
                "gophertunnel.packet.decode_batch",
                "packet count exceeds batch limit",
            )
            return
        }
        if !check_packet_limit &&
           len(packets) >= MAXIMUM_UNLIMITED_BATCH_PACKETS {
            err = packet_error(
                .Limit_Exceeded,
                "gophertunnel.packet.decode_batch",
                "packet count exceeds allocation ceiling",
            )
            return
        }
        payload := protocol.reader_take(
            &input,
            int(length),
            "gophertunnel.packet.decode_batch",
        ) or_return
        append(&packets, payload)
    }
    result = make([][]u8, len(packets), allocator)
    copy(result, packets[:])
    return
}

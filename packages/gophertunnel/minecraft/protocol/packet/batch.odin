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

Decoded_Batch :: struct {
    packets: [][]u8,
    storage: []u8,
}

destroy_decoded_batch :: proc(
    value: ^Decoded_Batch,
    allocator: mem.Allocator = context.allocator,
) {
    if value == nil {
        return
    }
    delete(value.packets, allocator)
    delete(value.storage, allocator)
    value^ = {}
}

encode_compressed_batch :: proc(
    packets: [][]u8,
    compression: Compression = .Flate,
    threshold: int = 0,
    batch_header: []u8 = []u8{BATCH_HEADER},
    allocator: mem.Allocator = context.allocator,
) -> (data: []u8, err: mcpe_runtime.Error) {
    if threshold < 0 {
        err = packet_error(
            .Invalid_Argument,
            "gophertunnel.packet.encode_compressed_batch",
            "negative compression threshold",
        )
        return
    }
    raw, raw_err := encode_batch(packets, nil, allocator)
    if raw_err != nil {
        err = raw_err
        return
    }
    defer delete(raw, allocator)

    algorithm := u8(0xff)
    payload := raw
    owned_payload: []u8
    defer if owned_payload != nil {
        delete(owned_payload, allocator)
    }
    if len(raw) >= threshold && compression != .None {
        switch compression {
        case .Flate:
            owned_payload, err = compress_flate(raw, allocator)
            if err != nil {
                return
            }
            payload = owned_payload
            algorithm = u8(compression_id(.Flate))
        case .Snappy:
            err = packet_error(
                .Not_Supported,
                "gophertunnel.packet.encode_compressed_batch",
                "Snappy compression is not ported",
            )
            return
        case .None:
        }
    }

    if len(batch_header) > max(int) - 1 - len(payload) {
        err = packet_error(
            .Limit_Exceeded,
            "gophertunnel.packet.encode_compressed_batch",
            "compressed batch length overflow",
        )
        return
    }
    data = make(
        []u8,
        len(batch_header) + 1 + len(payload),
        allocator,
    )
    offset := copy(data, batch_header)
    data[offset] = algorithm
    copy(data[offset + 1:], payload)
    return
}

decode_compressed_batch :: proc(
    data: []u8,
    compression: Compression = .Flate,
    maximum_decompressed_bytes: int = MAX_DECOMPRESSED_BATCH_BYTES,
    batch_header: []u8 = []u8{BATCH_HEADER},
    check_packet_limit: bool = true,
    allocator: mem.Allocator = context.allocator,
) -> (result: Decoded_Batch, err: mcpe_runtime.Error) {
    // Decoder.Decode returns no packets for a zero-byte transport read before
    // inspecting batch framing or compression state.
    if len(data) == 0 {
        return
    }
    if len(data) < len(batch_header) ||
       !slice.equal(data[:len(batch_header)], batch_header) {
        err = packet_error(
            .Malformed,
            "gophertunnel.packet.decode_compressed_batch",
            "invalid batch header",
        )
        return
    }
    framed_data := data[len(batch_header):]
    if len(framed_data) == 0 {
        err = packet_error(
            .Unexpected_EOF,
            "gophertunnel.packet.decode_compressed_batch",
            "missing compression algorithm",
        )
        return
    }
    algorithm := framed_data[0]
    payload := framed_data[1:]
    if algorithm != 0xff {
        selected, found := compression_by_id(u16(algorithm))
        if !found {
            err = packet_error(
                .Protocol,
                "gophertunnel.packet.decode_compressed_batch",
                "unknown compression algorithm",
            )
            return
        }
        if selected != compression {
            err = packet_error(
                .Protocol,
                "gophertunnel.packet.decode_compressed_batch",
                "unexpected compression algorithm",
            )
            return
        }
        switch selected {
        case .Flate:
            result.storage, err = decompress_flate(
                payload,
                maximum_decompressed_bytes,
                allocator,
            )
            if err != nil {
                return
            }
            payload = result.storage
        case .Snappy:
            err = packet_error(
                .Not_Supported,
                "gophertunnel.packet.decode_compressed_batch",
                "Snappy compression is not ported",
            )
            return
        case .None:
        }
    }
    result.packets, err = decode_batch(
        payload,
        nil,
        check_packet_limit,
        allocator,
    )
    if err != nil {
        delete(result.storage, allocator)
        result.storage = nil
    }
    return
}

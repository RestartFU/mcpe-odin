package gt_packet

import "core:slice"
import "core:testing"
import mcpe_runtime "mcpe:runtime"

@(test)
batch_round_trip_borrows_packet_payloads :: proc(t: ^testing.T) {
    packets := [][]u8{
        []u8{1, 2, 3},
        []u8{4, 5},
    }
    data, encode_err := encode_batch(packets)
    testing.expect(t, encode_err == nil)
    if encode_err != nil {
        mcpe_runtime.destroy_error(encode_err)
        return
    }
    defer delete(data)
    decoded, decode_err := decode_batch(data)
    testing.expect(t, decode_err == nil)
    if decode_err != nil {
        mcpe_runtime.destroy_error(decode_err)
        return
    }
    defer delete(decoded)
    testing.expect_value(t, len(decoded), 2)
    testing.expect(t, slice.equal(decoded[0], packets[0]))
    testing.expect(t, slice.equal(decoded[1], packets[1]))
    data[2] = 9
    testing.expect_value(t, decoded[0][0], u8(9))
}

@(test)
batch_rejects_empty_and_truncated_packets :: proc(t: ^testing.T) {
    _, empty_err := decode_batch([]u8{BATCH_HEADER, 0})
    testing.expect(t, empty_err != nil)
    if empty_err != nil {
        testing.expect_value(
            t,
            empty_err.kind,
            mcpe_runtime.Error_Kind.Malformed,
        )
        mcpe_runtime.destroy_error(empty_err)
    }

    _, truncated_err := decode_batch(
        []u8{BATCH_HEADER, 4, 1, 2},
    )
    testing.expect(t, truncated_err != nil)
    if truncated_err != nil {
        testing.expect_value(
            t,
            truncated_err.kind,
            mcpe_runtime.Error_Kind.Unexpected_EOF,
        )
        mcpe_runtime.destroy_error(truncated_err)
    }
}

@(test)
zero_byte_transport_reads_match_upstream :: proc(t: ^testing.T) {
    decoded, err := decode_batch(nil)
    testing.expect(t, err == nil)
    testing.expect(t, decoded == nil)
}

@(test)
batch_packet_limit_matches_upstream :: proc(t: ^testing.T) {
    packets := make([][]u8, MAXIMUM_BATCH_PACKETS + 1)
    defer delete(packets)
    for &packet in packets {
        packet = []u8{1}
    }
    data, encode_err := encode_batch(packets)
    testing.expect(t, encode_err == nil)
    if encode_err != nil {
        mcpe_runtime.destroy_error(encode_err)
        return
    }
    defer delete(data)
    _, decode_err := decode_batch(data)
    testing.expect(t, decode_err != nil)
    if decode_err != nil {
        testing.expect_value(
            t,
            decode_err.kind,
            mcpe_runtime.Error_Kind.Limit_Exceeded,
        )
        mcpe_runtime.destroy_error(decode_err)
    }
    decoded, unlimited_err := decode_batch(data, check_packet_limit = false)
    testing.expect(t, unlimited_err == nil)
    if unlimited_err == nil {
        testing.expect_value(t, len(decoded), MAXIMUM_BATCH_PACKETS + 1)
        delete(decoded)
    } else {
        mcpe_runtime.destroy_error(unlimited_err)
    }
}

package gt_packet

import "core:slice"
import "core:testing"
import mcpe_runtime "mcpe:runtime"

@(test)
stored_flate_round_trip :: proc(t: ^testing.T) {
    input := make([]u8, DEFLATE_STORED_BLOCK_BYTES + 17)
    defer delete(input)
    for &value, index in input {
        value = u8(index)
    }
    compressed, compress_err := compress_flate(input)
    testing.expect(t, compress_err == nil)
    if compress_err != nil {
        mcpe_runtime.destroy_error(compress_err)
        return
    }
    defer delete(compressed)
    decoded, decode_err := decompress_flate(compressed, len(input))
    testing.expect(t, decode_err == nil)
    if decode_err != nil {
        mcpe_runtime.destroy_error(decode_err)
        return
    }
    defer delete(decoded)
    testing.expect(t, slice.equal(decoded, input))
}

@(test)
flate_decodes_go_level_six_stream :: proc(t: ^testing.T) {
    compressed := []u8{
        0xed, 0xca, 0xc1, 0x0d, 0x00, 0x10, 0x0c, 0x40,
        0xd1, 0x55, 0x3a, 0x8b, 0xbb, 0x21, 0xa4, 0x2a,
        0x11, 0xa1, 0x52, 0xf6, 0x8f, 0x93, 0x2d, 0xfe,
        0x3b, 0xbf, 0xdc, 0x97, 0x69, 0x94, 0x76, 0x25,
        0x59, 0x0d, 0xd7, 0x21, 0xbb, 0xe8, 0xb0, 0x2b,
        0xea, 0x73, 0x87, 0x9d, 0xd3, 0x7d, 0x49, 0x26,
        0x91, 0x48, 0x24, 0x12, 0x89, 0x44, 0x22, 0xfd,
        0xf4, 0x00,
    }
    decoded, err := decompress_flate(compressed, 2368)
    testing.expect(t, err == nil)
    if err != nil {
        mcpe_runtime.destroy_error(err)
        return
    }
    defer delete(decoded)
    testing.expect_value(t, len(decoded), 2368)
    phrase_text := "Minecraft Bedrock packet compression "
    phrase := transmute([]u8)phrase_text
    testing.expect(t, slice.equal(decoded[:len(phrase)], phrase))
    testing.expect(t, slice.equal(decoded[len(decoded) - len(phrase):], phrase))
}

@(test)
flate_decompression_limit_is_enforced :: proc(t: ^testing.T) {
    input := make([]u8, 1024)
    defer delete(input)
    compressed, compress_err := compress_flate(input)
    testing.expect(t, compress_err == nil)
    if compress_err != nil {
        mcpe_runtime.destroy_error(compress_err)
        return
    }
    defer delete(compressed)
    decoded, err := decompress_flate(compressed, 1023)
    testing.expect(t, decoded == nil)
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
none_compression_id_keeps_upstream_lookup_quirk :: proc(t: ^testing.T) {
    compression, found := compression_by_id(
        compression_id(.None),
    )
    testing.expect(t, !found)
    testing.expect_value(t, compression, Compression.Flate)
}

@(test)
flate_rejects_truncated_dynamic_huffman_stream :: proc(t: ^testing.T) {
    decoded, err := decompress_flate([]u8{0x05}, 1024)
    testing.expect(t, decoded == nil)
    testing.expect(t, err != nil)
    if err != nil {
        testing.expect_value(
            t,
            err.kind,
            mcpe_runtime.Error_Kind.Malformed,
        )
        mcpe_runtime.destroy_error(err)
    }
}

@(test)
flate_rejects_truncated_stored_block :: proc(t: ^testing.T) {
    decoded, err := decompress_flate(
        []u8{0x01, 0x01, 0x00, 0xfe, 0xff},
        1024,
    )
    testing.expect(t, decoded == nil)
    testing.expect(t, err != nil)
    if err != nil {
        testing.expect_value(
            t,
            err.kind,
            mcpe_runtime.Error_Kind.Malformed,
        )
        mcpe_runtime.destroy_error(err)
    }
}

@(test)
flate_rejects_over_limit_stored_stream_without_truncating :: proc(
    t: ^testing.T,
) {
    input := make([]u8, 1024 * 1024 + 1)
    defer delete(input)
    compressed, compress_err := compress_flate(input)
    testing.expect(t, compress_err == nil)
    if compress_err != nil {
        mcpe_runtime.destroy_error(compress_err)
        return
    }
    defer delete(compressed)
    decoded, err := decompress_flate(compressed, 1024 * 1024)
    testing.expect(t, decoded == nil)
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

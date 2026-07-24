package gt_packet

import "core:c"
import "core:mem"
import mcpe_runtime "mcpe:runtime"

MAX_DECOMPRESSED_BATCH_BYTES :: 64 * 1024 * 1024
DEFLATE_STORED_BLOCK_BYTES   :: 65_535

Z_Stream :: struct {
    next_in:   rawptr,
    avail_in:  c.uint,
    total_in:  c.ulong,
    next_out:  rawptr,
    avail_out: c.uint,
    total_out: c.ulong,
    message:   cstring,
    state:     rawptr,
    allocate:  rawptr,
    free:      rawptr,
    opaque:    rawptr,
    data_type: c.int,
    adler:     c.ulong,
    reserved:  c.ulong,
}

#assert(size_of(Z_Stream) == 112)

foreign import zlib_library "system:z"

@(default_calling_convention="c")
foreign zlib_library {
    @(link_name="zlibVersion")
    zlib_version :: proc() -> cstring ---

    @(link_name="inflateInit2_")
    zlib_inflate_init2 :: proc(
        stream: ^Z_Stream,
        window_bits: c.int,
        version: cstring,
        stream_size: c.int,
    ) -> c.int ---

    @(link_name="inflate")
    zlib_inflate :: proc(stream: ^Z_Stream, flush: c.int) -> c.int ---

    @(link_name="inflateEnd")
    zlib_inflate_end :: proc(stream: ^Z_Stream) -> c.int ---
}

Z_OK         :: c.int(0)
Z_STREAM_END :: c.int(1)
Z_BUF_ERROR  :: c.int(-5)
Z_NO_FLUSH   :: c.int(0)
Z_FINISH     :: c.int(4)

Compression :: enum u16 {
    Flate  = 0,
    Snappy = 1,
    None   = 0xffff,
}

compression_by_id :: proc(id: u16) -> (
    compression: Compression,
    found: bool,
) {
    switch id {
    case u16(Compression.Flate):
        return .Flate, true
    case u16(Compression.Snappy):
        return .Snappy, true
    }
    // Upstream returns DefaultCompression together with false.
    return .Flate, false
}

compression_id :: proc(value: Compression) -> u16 {
    return u16(value)
}

// compress_flate emits valid raw DEFLATE stored blocks. This baseline favours
// exact interoperability; a compressed level-6 encoder replaces it later.
compress_flate :: proc(
    input: []u8,
    allocator: mem.Allocator = context.allocator,
) -> (result: []u8, err: mcpe_runtime.Error) {
    block_count := max(1, (len(input) + DEFLATE_STORED_BLOCK_BYTES - 1) /
        DEFLATE_STORED_BLOCK_BYTES)
    if len(input) > max(int) - block_count * 5 {
        err = packet_error(
            .Limit_Exceeded,
            "gophertunnel.packet.compress_flate",
            "compressed output length overflow",
        )
        return
    }
    result = make([]u8, len(input) + block_count * 5, allocator)
    input_offset := 0
    output_offset := 0
    for block_index in 0..<block_count {
        remaining := len(input) - input_offset
        block_length := min(DEFLATE_STORED_BLOCK_BYTES, remaining)
        final := block_index == block_count - 1
        result[output_offset] = 1 if final else 0
        output_offset += 1
        length := u16(block_length)
        inverse := ~length
        result[output_offset + 0] = u8(length)
        result[output_offset + 1] = u8(length >> 8)
        result[output_offset + 2] = u8(inverse)
        result[output_offset + 3] = u8(inverse >> 8)
        output_offset += 4
        copy(
            result[output_offset:output_offset + block_length],
            input[input_offset:input_offset + block_length],
        )
        input_offset += block_length
        output_offset += block_length
    }
    return
}

decompress_flate :: proc(
    input: []u8,
    limit: int,
    allocator: mem.Allocator = context.allocator,
) -> (result: []u8, err: mcpe_runtime.Error) {
    if limit < 0 || limit > MAX_DECOMPRESSED_BATCH_BYTES {
        err = packet_error(
            .Invalid_Argument,
            "gophertunnel.packet.decompress_flate",
            "invalid decompressed-size limit",
        )
        return
    }
    if len(input) > int(max(c.uint)) {
        err = packet_error(
            .Limit_Exceeded,
            "gophertunnel.packet.decompress_flate",
            "compressed input exceeds zlib size field",
        )
        return
    }

    maximum_output := limit + 1
    initial_size := min(
        maximum_output,
        max(512, min(len(input) * 2, maximum_output)),
    )
    output := make(
        [dynamic]u8,
        initial_size,
        initial_size,
        allocator,
    )
    defer if output != nil {
        delete(output)
    }
    stream := Z_Stream{
        next_in = raw_data(input),
        avail_in = c.uint(len(input)),
        next_out = raw_data(output[:]),
        avail_out = c.uint(len(output)),
    }
    init_code := zlib_inflate_init2(
        &stream,
        -15,
        zlib_version(),
        c.int(size_of(Z_Stream)),
    )
    if init_code != Z_OK {
        err = packet_error(
            .Native,
            "gophertunnel.packet.decompress_flate",
            "initialize libz inflater",
        )
        return
    }
    defer zlib_inflate_end(&stream)

    for {
        previous_input := stream.total_in
        previous_output := stream.total_out
        inflate_code := zlib_inflate(&stream, Z_NO_FLUSH)
        if inflate_code == Z_STREAM_END {
            break
        }
        if inflate_code != Z_OK && inflate_code != Z_BUF_ERROR {
            err = packet_error(
                .Malformed,
                "gophertunnel.packet.decompress_flate",
                "invalid raw DEFLATE stream",
            )
            return
        }
        if stream.avail_out == 0 {
            if len(output) >= maximum_output {
                err = packet_error(
                    .Limit_Exceeded,
                    "gophertunnel.packet.decompress_flate",
                    "decompressed size exceeds limit",
                )
                return
            }
            next_size := min(
                maximum_output,
                max(len(output) + 512, len(output) * 2),
            )
            resize(&output, next_size)
            produced := int(stream.total_out)
            stream.next_out = raw_data(output[produced:])
            stream.avail_out = c.uint(len(output) - produced)
            continue
        }
        if stream.avail_in == 0 ||
           (stream.total_in == previous_input &&
            stream.total_out == previous_output) {
            err = packet_error(
                .Malformed,
                "gophertunnel.packet.decompress_flate",
                "truncated raw DEFLATE stream",
            )
            return
        }
    }
    decoded_length := int(stream.total_out)
    if decoded_length > limit {
        err = packet_error(
            .Limit_Exceeded,
            "gophertunnel.packet.decompress_flate",
            "decompressed size exceeds limit",
        )
        return
    }
    resize(&output, decoded_length)
    result = output[:]
    output = nil
    return
}

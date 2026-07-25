package gt_protocol

import "core:slice"
import "core:testing"
import mcpe_runtime "mcpe:runtime"

@(test)
varuint32_matches_minecraft_vectors :: proc(t: ^testing.T) {
    values := [?]u32{
        0,
        1,
        127,
        128,
        255,
        300,
        max(u32),
    }
    expected := [?][]u8{
        {0x00},
        {0x01},
        {0x7f},
        {0x80, 0x01},
        {0xff, 0x01},
        {0xac, 0x02},
        {0xff, 0xff, 0xff, 0xff, 0x0f},
    }
    for input, index in values {
        output := writer()
        write_varuint32(&output, input)
        testing.expect(
            t,
            slice.equal(writer_bytes(&output), expected[index]),
        )
        source := reader(writer_bytes(&output))
        decoded, decode_err := read_varuint32(&source)
        testing.expect(t, decode_err == nil)
        testing.expect_value(t, decoded, input)
        testing.expect_value(t, remaining(&source), 0)
        writer_destroy(&output)
    }
    }

@(test)
signed_varints_round_trip_boundaries :: proc(t: ^testing.T) {
    values32 := [?]i32{
        min(i32),
        -1_000_000,
        -1,
        0,
        1,
        1_000_000,
        max(i32),
    }
    output := writer()
    for input in values32 {
        write_varint32(&output, input)
    }
    source := reader(writer_bytes(&output))
    for expected in values32 {
        actual, decode_err := read_varint32(&source)
        testing.expect(t, decode_err == nil)
        testing.expect_value(t, actual, expected)
    }
    testing.expect_value(t, remaining(&source), 0)
    writer_destroy(&output)

    values64 := [?]i64{
        min(i64),
        -1_000_000_000_000,
        -1,
        0,
        1,
        1_000_000_000_000,
        max(i64),
    }
    output = writer()
    for input in values64 {
        write_varint64(&output, input)
    }
    source = reader(writer_bytes(&output))
    for expected in values64 {
        actual, decode_err := read_varint64(&source)
        testing.expect(t, decode_err == nil)
        testing.expect_value(t, actual, expected)
    }
    testing.expect_value(t, remaining(&source), 0)
    writer_destroy(&output)
}

@(test)
unterminated_varints_consume_go_width :: proc(t: ^testing.T) {
    encoded32 := []u8{0x80, 0x80, 0x80, 0x80, 0x80, 0x01}
    source32 := reader(encoded32)
    _, err32 := read_varuint32(&source32)
    testing.expect(t, err32 != nil)
    if err32 != nil {
        testing.expect_value(t, err32.kind, mcpe_runtime.Error_Kind.Malformed)
        mcpe_runtime.destroy_error(err32)
    }
    testing.expect_value(t, source32.offset, 5)

    encoded64 := []u8{
        0x80,
        0x80,
        0x80,
        0x80,
        0x80,
        0x80,
        0x80,
        0x80,
        0x80,
        0x80,
        0x01,
    }
    source64 := reader(encoded64)
    _, err64 := read_varuint64(&source64)
    testing.expect(t, err64 != nil)
    if err64 != nil {
        testing.expect_value(t, err64.kind, mcpe_runtime.Error_Kind.Malformed)
        mcpe_runtime.destroy_error(err64)
    }
    testing.expect_value(t, source64.offset, 10)
}

@(test)
primitive_codec_round_trip :: proc(t: ^testing.T) {
    output := writer()
    defer writer_destroy(&output)
    write_u16(&output, 0x1234)
    write_i16(&output, -1234)
    write_u32(&output, 0x1234_5678)
    write_i32(&output, -123_456)
    write_be_i32(&output, 0x1234_5678)
    write_u64(&output, 0x0123_4567_89ab_cdef)
    write_i64(&output, -123_456_789)
    write_f32(&output, 123.5)
    write_f64(&output, -987.25)
    write_bool(&output, true)
    write_bool(&output, false)

    source := reader(writer_bytes(&output))
    testing.expect_value(t, read_u16(&source) or_else 0, u16(0x1234))
    testing.expect_value(t, read_i16(&source) or_else 0, i16(-1234))
    testing.expect_value(t, read_u32(&source) or_else 0, u32(0x1234_5678))
    testing.expect_value(t, read_i32(&source) or_else 0, i32(-123_456))
    testing.expect_value(t, read_be_i32(&source) or_else 0, i32(0x1234_5678))
    testing.expect_value(
        t,
        read_u64(&source) or_else 0,
        u64(0x0123_4567_89ab_cdef),
    )
    testing.expect_value(
        t,
        read_i64(&source) or_else 0,
        i64(-123_456_789),
    )
    testing.expect_value(t, read_f32(&source) or_else 0, f32(123.5))
    testing.expect_value(t, read_f64(&source) or_else 0, f64(-987.25))
    testing.expect(t, read_bool(&source) or_else false)
    testing.expect(t, !(read_bool(&source) or_else true))
    testing.expect_value(t, remaining(&source), 0)
}

@(test)
strings_and_bytes_are_owned :: proc(t: ^testing.T) {
    output := writer()
    defer writer_destroy(&output)
    write_string(&output, "Minecraft")
    write_string_utf(&output, "Bedrock")
    write_byte_slice(&output, []u8{1, 2, 3, 4})

    source := reader(writer_bytes(&output))
    first, first_err := read_string(&source)
    testing.expect(t, first_err == nil)
    defer delete(first)
    testing.expect_value(t, first, "Minecraft")
    second, second_err := read_string_utf(&source)
    testing.expect(t, second_err == nil)
    defer delete(second)
    testing.expect_value(t, second, "Bedrock")
    bytes, bytes_err := read_byte_slice(&source)
    testing.expect(t, bytes_err == nil)
    defer delete(bytes)
    testing.expect(t, slice.equal(bytes, []u8{1, 2, 3, 4}))
}

@(test)
truncated_fields_fail_without_allocating :: proc(t: ^testing.T) {
    source := reader([]u8{10, 1, 2})
    bytes, err := read_byte_slice(&source)
    testing.expect(t, bytes == nil)
    testing.expect(t, err != nil)
    if err != nil {
        testing.expect_value(
            t,
            err.kind,
            mcpe_runtime.Error_Kind.Unexpected_EOF,
        )
        mcpe_runtime.destroy_error(err)
    }
}

@(test)
structured_protocol_values_round_trip :: proc(t: ^testing.T) {
    expected_uuid := UUID{
        0x00,
        0x11,
        0x22,
        0x33,
        0x44,
        0x55,
        0x66,
        0x77,
        0x88,
        0x99,
        0xaa,
        0xbb,
        0xcc,
        0xdd,
        0xee,
        0xff,
    }
    expected_block := Block_Pos{-12, 64, 3456}
    expected_chunk := Chunk_Pos{-100, 200}
    expected_sub_chunk := Sub_Chunk_Pos{-2, 10, 44}
    expected_vec := Vec3{1.25, -2.5, 9.75}
    expected_colour := RGBA{r = 1, g = 2, b = 3, a = 4}

    output := writer()
    defer writer_destroy(&output)
    write_uuid(&output, expected_uuid)
    write_block_pos(&output, expected_block)
    write_chunk_pos(&output, expected_chunk)
    write_sub_chunk_pos(&output, expected_sub_chunk)
    write_vec3(&output, expected_vec)
    write_rgba(&output, expected_colour)
    write_var_rgba(&output, expected_colour)

    source := reader(writer_bytes(&output))
    testing.expect_value(
        t,
        read_uuid(&source) or_else {},
        expected_uuid,
    )
    testing.expect_value(
        t,
        read_block_pos(&source) or_else {},
        expected_block,
    )
    testing.expect_value(
        t,
        read_chunk_pos(&source) or_else {},
        expected_chunk,
    )
    testing.expect_value(
        t,
        read_sub_chunk_pos(&source) or_else {},
        expected_sub_chunk,
    )
    testing.expect_value(
        t,
        read_vec3(&source) or_else {},
        expected_vec,
    )
    testing.expect_value(
        t,
        read_rgba(&source) or_else {},
        expected_colour,
    )
    testing.expect_value(
        t,
        read_var_rgba(&source) or_else {},
        expected_colour,
    )
}

@(test)
optional_values_preserve_presence :: proc(t: ^testing.T) {
    present := option(u32(42))
    value, set := optional_value(present)
    testing.expect(t, set)
    testing.expect_value(t, value, u32(42))

    absent: Optional(u32)
    value, set = optional_value(absent)
    testing.expect(t, !set)
    testing.expect_value(t, value, u32(0))
}
@(test)
bitset_round_trip_and_bounds :: proc(t: ^testing.T) {
    flags, create_err := new_bitset(130)
    testing.expect(t, create_err == nil)
    if create_err != nil {
        mcpe_runtime.destroy_error(create_err)
        return
    }
    defer destroy_bitset(&flags)
    flag_indices := [?]int{0, 64, 129}
    for index in flag_indices {
        set_err := bitset_set(&flags, index)
        testing.expect(t, set_err == nil)
        if set_err != nil {
            mcpe_runtime.destroy_error(set_err)
        }
    }
    output := writer()
    defer writer_destroy(&output)
    write_err := write_bitset(&output, flags, 130)
    testing.expect(t, write_err == nil)
    if write_err != nil {
        mcpe_runtime.destroy_error(write_err)
        return
    }
    source := reader(writer_bytes(&output))
    decoded, read_err := read_bitset(&source, 130)
    testing.expect(t, read_err == nil)
    if read_err != nil {
        mcpe_runtime.destroy_error(read_err)
        return
    }
    defer destroy_bitset(&decoded)
    for index in flag_indices {
        loaded, load_err := bitset_load(decoded, index)
        testing.expect(t, load_err == nil)
        testing.expect(t, loaded)
        if load_err != nil {
            mcpe_runtime.destroy_error(load_err)
        }
}

    overflow := reader([]u8{0x80})
    invalid, overflow_err := read_bitset(&overflow, 7)
    destroy_bitset(&invalid)
    testing.expect(t, overflow_err != nil)
    if overflow_err != nil {
        testing.expect_value(
            t,
            overflow_err.kind,
            mcpe_runtime.Error_Kind.Malformed,
        )
        mcpe_runtime.destroy_error(overflow_err)
    }
}

@(test)
command_origins_round_trip :: proc(t: ^testing.T) {
    for origin := u32(0); origin <= Command_Origin_Executor; origin += 1 {
        output := writer()
        value := Command_Origin{
            origin = origin,
            request_id = "request",
            player_unique_id = -99,
        }
        write_err := write_command_origin(&output, value)
        testing.expect(t, write_err == nil)
        if write_err != nil {
            mcpe_runtime.destroy_error(write_err)
            writer_destroy(&output)
            continue
        }
        input := reader(writer_bytes(&output))
        decoded, read_err := read_command_origin(&input)
        testing.expect(t, read_err == nil)
        if read_err == nil {
            testing.expect_value(t, decoded.origin, origin)
            testing.expect_value(t, decoded.request_id, "request")
            testing.expect_value(t, decoded.player_unique_id, i64(-99))
            destroy_command_origin(decoded)
        } else {
            mcpe_runtime.destroy_error(read_err)
        }
        writer_destroy(&output)
    }
}

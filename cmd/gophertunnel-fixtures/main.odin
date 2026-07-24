package gophertunnel_fixtures

import "core:fmt"
import protocol "mcpe:gophertunnel/minecraft/protocol"

emit :: proc(name: string, data: []u8) {
    fmt.printf("%s ", name)
    for value in data {
        fmt.printf("%02x", value)
    }
    fmt.println()
}

main :: proc() {
    output := protocol.writer()
    defer protocol.writer_destroy(&output)

    protocol.write_u16(&output, 0x1234)
    protocol.write_i16(&output, -1234)
    protocol.write_u32(&output, 0x1234_5678)
    protocol.write_i32(&output, -123_456)
    protocol.write_be_i32(&output, 0x1234_5678)
    protocol.write_u64(&output, 0x0123_4567_89ab_cdef)
    protocol.write_i64(&output, -123_456_789)
    protocol.write_f32(&output, 123.5)
    protocol.write_f64(&output, -987.25)
    protocol.write_bool(&output, true)
    protocol.write_bool(&output, false)

    varuint32_values := [?]u32{0, 1, 127, 128, 255, 300, max(u32)}
    for value in varuint32_values {
        protocol.write_varuint32(&output, value)
    }
    varint32_values := [?]i32{
        min(i32),
        -1_000_000,
        -1,
        0,
        1,
        1_000_000,
        max(i32),
    }
    for value in varint32_values {
        protocol.write_varint32(&output, value)
    }
    varuint64_values := [?]u64{0, 1, 127, 128, 300, max(u64)}
    for value in varuint64_values {
        protocol.write_varuint64(&output, value)
    }
    varint64_values := [?]i64{
        min(i64),
        -1_000_000_000_000,
        -1,
        0,
        1,
        max(i64),
    }
    for value in varint64_values {
        protocol.write_varint64(&output, value)
    }

    protocol.write_string(&output, "Minecraft")
    protocol.write_string_utf(&output, "Bedrock")
    protocol.write_byte_slice(&output, []u8{1, 2, 3, 4})
    protocol.write_vec2(&output, {1.25, -2.5})
    protocol.write_vec3(&output, {1.25, -2.5, 9.75})
    protocol.write_block_pos(&output, {-12, 64, 3456})
    protocol.write_chunk_pos(&output, {-100, 200})
    protocol.write_sub_chunk_pos(&output, {-2, 10, 44})
    protocol.write_sound_pos(&output, {1.25, -2.5, 9.75})
    protocol.write_byte_float(&output, 180)
    protocol.write_uuid(
        &output,
        {
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
        },
    )
    colour := protocol.RGBA{r = 1, g = 2, b = 3, a = 4}
    protocol.write_rgba(&output, colour)
    protocol.write_var_rgba(&output, colour)
    emit("protocol_codec", protocol.writer_bytes(&output))
}

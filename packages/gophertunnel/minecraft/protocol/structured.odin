package gt_protocol

import mcpe_runtime "mcpe:runtime"

read_vec2 :: proc(value: ^Reader) -> (result: Vec2, err: mcpe_runtime.Error) {
    for &component in result {
        component = read_f32(value) or_return
    }
    return
}

write_vec2 :: proc(value: ^Writer, input: Vec2) {
    for component in input {
        write_f32(value, component)
    }
}

read_vec3 :: proc(value: ^Reader) -> (result: Vec3, err: mcpe_runtime.Error) {
    for &component in result {
        component = read_f32(value) or_return
    }
    return
}

write_vec3 :: proc(value: ^Writer, input: Vec3) {
    for component in input {
        write_f32(value, component)
    }
}

read_block_pos :: proc(value: ^Reader) -> (
    result: Block_Pos,
    err: mcpe_runtime.Error,
) {
    for &component in result {
        component = read_varint32(value) or_return
    }
    return
}

write_block_pos :: proc(value: ^Writer, input: Block_Pos) {
    for component in input {
        write_varint32(value, component)
    }
}

read_chunk_pos :: proc(value: ^Reader) -> (
    result: Chunk_Pos,
    err: mcpe_runtime.Error,
) {
    for &component in result {
        component = read_varint32(value) or_return
    }
    return
}

write_chunk_pos :: proc(value: ^Writer, input: Chunk_Pos) {
    for component in input {
        write_varint32(value, component)
    }
}

read_sub_chunk_pos :: proc(value: ^Reader) -> (
    result: Sub_Chunk_Pos,
    err: mcpe_runtime.Error,
) {
    for &component in result {
        component = read_varint32(value) or_return
    }
    return
}

write_sub_chunk_pos :: proc(value: ^Writer, input: Sub_Chunk_Pos) {
    for component in input {
        write_varint32(value, component)
    }
}

read_sound_pos :: proc(value: ^Reader) -> (
    result: Vec3,
    err: mcpe_runtime.Error,
) {
    block := read_block_pos(value) or_return
    for &component, index in result {
        component = f32(block[index]) / 8
    }
    return
}

write_sound_pos :: proc(value: ^Writer, input: Vec3) {
    block := Block_Pos{
        i32(input[0] * 8),
        i32(input[1] * 8),
        i32(input[2] * 8),
    }
    write_block_pos(value, block)
}

read_byte_float :: proc(value: ^Reader) -> (
    result: f32,
    err: mcpe_runtime.Error,
) {
    result = f32(read_u8(value) or_return) * (360.0 / 256.0)
    return
}

write_byte_float :: proc(value: ^Writer, input: f32) {
    write_u8(value, u8(input / (360.0 / 256.0)))
}

read_uuid :: proc(value: ^Reader) -> (
    result: UUID,
    err: mcpe_runtime.Error,
) {
    bytes := reader_take(
        value,
        16,
        "gophertunnel.protocol.read_uuid",
    ) or_return
    for index in 0..<8 {
        result[index] = bytes[7 - index]
        result[8 + index] = bytes[15 - index]
    }
    return
}

write_uuid :: proc(value: ^Writer, input: UUID) {
    for index in 0..<8 {
        write_u8(value, input[7 - index])
    }
    for index in 0..<8 {
        write_u8(value, input[15 - index])
    }
}

read_rgba :: proc(value: ^Reader) -> (
    result: RGBA,
    err: mcpe_runtime.Error,
) {
    raw := read_u32(value) or_return
    result = {
        r = u8(raw),
        g = u8(raw >> 8),
        b = u8(raw >> 16),
        a = u8(raw >> 24),
    }
    return
}

write_rgba :: proc(value: ^Writer, input: RGBA) {
    write_u32(
        value,
        u32(input.r) |
        u32(input.g) << 8 |
        u32(input.b) << 16 |
        u32(input.a) << 24,
    )
}

read_var_rgba :: proc(value: ^Reader) -> (
    result: RGBA,
    err: mcpe_runtime.Error,
) {
    raw := read_varuint32(value) or_return
    result = {
        r = u8(raw),
        g = u8(raw >> 8),
        b = u8(raw >> 16),
        a = u8(raw >> 24),
    }
    return
}

write_var_rgba :: proc(value: ^Writer, input: RGBA) {
    write_varuint32(
        value,
        u32(input.r) |
        u32(input.g) << 8 |
        u32(input.b) << 16 |
        u32(input.a) << 24,
    )
}

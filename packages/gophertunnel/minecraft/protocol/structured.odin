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

read_entity_link :: proc(value: ^Reader) -> (
    result: Entity_Link,
    err: mcpe_runtime.Error,
) {
    result.ridden_entity_unique_id = read_varint64(value) or_return
    result.rider_entity_unique_id = read_varint64(value) or_return
    result.type = read_u8(value) or_return
    result.immediate = read_bool(value) or_return
    result.rider_initiated = read_bool(value) or_return
    result.vehicle_angular_velocity = read_f32(value) or_return
    return
}

write_entity_link :: proc(value: ^Writer, input: Entity_Link) {
    write_varint64(value, input.ridden_entity_unique_id)
    write_varint64(value, input.rider_entity_unique_id)
    write_u8(value, input.type)
    write_bool(value, input.immediate)
    write_bool(value, input.rider_initiated)
    write_f32(value, input.vehicle_angular_velocity)
}

read_pixel_request :: proc(value: ^Reader) -> (
    result: Pixel_Request,
    err: mcpe_runtime.Error,
) {
    result.colour = read_rgba(value) or_return
    result.index = read_u16(value) or_return
    return
}

write_pixel_request :: proc(value: ^Writer, input: Pixel_Request) {
    write_rgba(value, input.colour)
    write_u16(value, input.index)
}

read_player_armour_damage_entry :: proc(value: ^Reader) -> (
    result: Player_Armour_Damage_Entry,
    err: mcpe_runtime.Error,
) {
    result.armour_slot = read_varint32(value) or_return
    result.damage = read_i16(value) or_return
    return
}

write_player_armour_damage_entry :: proc(
    value: ^Writer,
    input: Player_Armour_Damage_Entry,
) {
    write_varint32(value, input.armour_slot)
    write_i16(value, input.damage)
}

read_score_remove_entry :: proc(value: ^Reader) -> (
    result: Scoreboard_Entry,
    err: mcpe_runtime.Error,
) {
    result.entry_id = read_varint64(value) or_return
    result.objective_name = read_string(value) or_return
    result.score, err = read_i32(value)
    if err != nil {
        delete(result.objective_name, value.allocator)
        result.objective_name = ""
    }
    return
}

write_score_remove_entry :: proc(
    value: ^Writer,
    input: Scoreboard_Entry,
) {
    write_varint64(value, input.entry_id)
    write_string(value, input.objective_name)
    write_i32(value, input.score)
}

read_scoreboard_entry :: proc(value: ^Reader) -> (
    result: Scoreboard_Entry,
    err: mcpe_runtime.Error,
) {
    result = read_score_remove_entry(value) or_return
    result.identity_type, err = read_u8(value)
    if err != nil {
        delete(result.objective_name, value.allocator)
        result = {}
        return
    }
    switch result.identity_type {
    case Scoreboard_Identity_Entity, Scoreboard_Identity_Player:
        result.entity_unique_id, err = read_varint64(value)
    case Scoreboard_Identity_Fake_Player:
        result.display_name, err = read_string(value)
    case:
        err = codec_error(
            .Malformed,
            "gophertunnel.protocol.read_scoreboard_entry",
            "unknown scoreboard identity type",
        )
    }
    if err != nil {
        delete(result.objective_name, value.allocator)
        delete(result.display_name, value.allocator)
        result = {}
    }
    return
}

write_scoreboard_entry :: proc(
    value: ^Writer,
    input: Scoreboard_Entry,
) -> mcpe_runtime.Error {
    write_score_remove_entry(value, input)
    write_u8(value, input.identity_type)
    switch input.identity_type {
    case Scoreboard_Identity_Entity, Scoreboard_Identity_Player:
        write_varint64(value, input.entity_unique_id)
    case Scoreboard_Identity_Fake_Player:
        write_string(value, input.display_name)
    case:
        return codec_error(
            .Invalid_Argument,
            "gophertunnel.protocol.write_scoreboard_entry",
            "unknown scoreboard identity type",
        )
    }
    return nil
}

read_scoreboard_identity_entry :: proc(value: ^Reader) -> (
    result: Scoreboard_Identity_Entry,
    err: mcpe_runtime.Error,
) {
    result.entry_id = read_varint64(value) or_return
    result.entity_unique_id = read_varint64(value) or_return
    return
}

write_scoreboard_identity_entry :: proc(
    value: ^Writer,
    input: Scoreboard_Identity_Entry,
) {
    write_varint64(value, input.entry_id)
    write_varint64(value, input.entity_unique_id)
}

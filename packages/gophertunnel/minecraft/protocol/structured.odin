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

read_trim_pattern :: proc(value: ^Reader) -> (
    result: Trim_Pattern,
    err: mcpe_runtime.Error,
) {
    result.item_name = read_string(value) or_return
    result.pattern_id, err = read_string(value)
    if err != nil {
        delete(result.item_name, value.allocator)
        result.item_name = ""
    }
    return
}

write_trim_pattern :: proc(value: ^Writer, input: Trim_Pattern) {
    write_string(value, input.item_name)
    write_string(value, input.pattern_id)
}

read_trim_material :: proc(value: ^Reader) -> (
    result: Trim_Material,
    err: mcpe_runtime.Error,
) {
    result.material_id = read_string(value) or_return
    result.colour, err = read_string(value)
    if err != nil {
        delete(result.material_id, value.allocator)
        result = {}
        return
    }
    result.item_name, err = read_string(value)
    if err != nil {
        delete(result.material_id, value.allocator)
        delete(result.colour, value.allocator)
        result = {}
    }
    return
}

write_trim_material :: proc(value: ^Writer, input: Trim_Material) {
    write_string(value, input.material_id)
    write_string(value, input.colour)
    write_string(value, input.item_name)
}

read_dimension_definition :: proc(value: ^Reader) -> (
    result: Dimension_Definition,
    err: mcpe_runtime.Error,
) {
    result.name = read_string(value) or_return
    result.range[0], err = read_varint32(value)
    if err == nil {
        result.range[1], err = read_varint32(value)
    }
    if err == nil {
        result.generator, err = read_varint32(value)
    }
    if err == nil {
        result.dimension_type, err = read_varint32(value)
    }
    if err != nil {
        delete(result.name, value.allocator)
        result = {}
    }
    return
}

write_dimension_definition :: proc(
    value: ^Writer,
    input: Dimension_Definition,
) {
    write_string(value, input.name)
    write_varint32(value, input.range[0])
    write_varint32(value, input.range[1])
    write_varint32(value, input.generator)
    write_varint32(value, input.dimension_type)
}

read_generation_feature :: proc(value: ^Reader) -> (
    result: Generation_Feature,
    err: mcpe_runtime.Error,
) {
    result.name = read_string(value) or_return
    result.json, err = read_byte_slice(value)
    if err != nil {
        delete(result.name, value.allocator)
        result = {}
    }
    return
}

write_generation_feature :: proc(
    value: ^Writer,
    input: Generation_Feature,
) {
    write_string(value, input.name)
    write_byte_slice(value, input.json)
}

read_store_entry_point_info :: proc(value: ^Reader) -> (
    result: Store_Entry_Point_Info,
    err: mcpe_runtime.Error,
) {
    result.store_id = read_string(value) or_return
    result.store_name, err = read_string(value)
    if err != nil {
        delete(result.store_id, value.allocator)
        result = {}
    }
    return
}

write_store_entry_point_info :: proc(
    value: ^Writer,
    input: Store_Entry_Point_Info,
) {
    write_string(value, input.store_id)
    write_string(value, input.store_name)
}

read_presence_info :: proc(value: ^Reader) -> (
    result: Presence_Info,
    err: mcpe_runtime.Error,
) {
    result.experience_name.set = read_bool(value) or_return
    if result.experience_name.set {
        result.experience_name.value = read_string(value) or_return
    }
    result.world_name.set, err = read_bool(value)
    if err == nil && result.world_name.set {
        result.world_name.value, err = read_string(value)
    }
    if err == nil {
        result.rich_presence_id, err = read_string(value)
    }
    if err != nil {
        if result.experience_name.set {
            delete(result.experience_name.value, value.allocator)
        }
        if result.world_name.set {
            delete(result.world_name.value, value.allocator)
        }
        result = {}
    }
    return
}

write_presence_info :: proc(value: ^Writer, input: Presence_Info) {
    write_bool(value, input.experience_name.set)
    if input.experience_name.set {
        write_string(value, input.experience_name.value)
    }
    write_bool(value, input.world_name.set)
    if input.world_name.set {
        write_string(value, input.world_name.value)
    }
    write_string(value, input.rich_presence_id)
}

read_camera_aim_assist_actor_priority_data :: proc(
    value: ^Reader,
) -> (
    result: Camera_Aim_Assist_Actor_Priority_Data,
    err: mcpe_runtime.Error,
) {
    result.preset_index = read_i32(value) or_return
    result.category_index = read_i32(value) or_return
    result.actor_index = read_i32(value) or_return
    result.priority = read_i32(value) or_return
    return
}

write_camera_aim_assist_actor_priority_data :: proc(
    value: ^Writer,
    input: Camera_Aim_Assist_Actor_Priority_Data,
) {
    write_i32(value, input.preset_index)
    write_i32(value, input.category_index)
    write_i32(value, input.actor_index)
    write_i32(value, input.priority)
}

read_ability_layer :: proc(value: ^Reader) -> (
    result: Ability_Layer,
    err: mcpe_runtime.Error,
) {
    result.type = read_u16(value) or_return
    result.abilities = read_u32(value) or_return
    result.values = read_u32(value) or_return
    result.fly_speed = read_f32(value) or_return
    result.vertical_fly_speed = read_f32(value) or_return
    result.walk_speed = read_f32(value) or_return
    return
}

write_ability_layer :: proc(value: ^Writer, input: Ability_Layer) {
    write_u16(value, input.type)
    write_u32(value, input.abilities)
    write_u32(value, input.values)
    write_f32(value, input.fly_speed)
    write_f32(value, input.vertical_fly_speed)
    write_f32(value, input.walk_speed)
}

read_full_container_name :: proc(value: ^Reader) -> (
    result: Full_Container_Name,
    err: mcpe_runtime.Error,
) {
    result.container_id = read_u8(value) or_return
    result.dynamic_container_id.set = read_bool(value) or_return
    if result.dynamic_container_id.set {
        result.dynamic_container_id.value = read_u32(value) or_return
    }
    return
}

write_full_container_name :: proc(
    value: ^Writer,
    input: Full_Container_Name,
) {
    write_u8(value, input.container_id)
    write_bool(value, input.dynamic_container_id.set)
    if input.dynamic_container_id.set {
        write_u32(value, input.dynamic_container_id.value)
    }
}

read_ability_data :: proc(value: ^Reader) -> (
    result: Ability_Data,
    err: mcpe_runtime.Error,
) {
    result.entity_unique_id = read_i64(value) or_return
    result.player_permissions = read_u8(value) or_return
    result.command_permissions = read_u8(value) or_return
    count := read_u8(value) or_return
    result.layers = make(
        []Ability_Layer,
        int(count),
        value.allocator,
    )
    for &layer in result.layers {
        layer, err = read_ability_layer(value)
        if err != nil {
            delete(result.layers, value.allocator)
            result = {}
            return
        }
    }
    return
}

write_ability_data :: proc(
    value: ^Writer,
    input: Ability_Data,
) -> mcpe_runtime.Error {
    if len(input.layers) > 255 {
        return codec_error(
            .Limit_Exceeded,
            "gophertunnel.protocol.write_ability_data",
            "ability layer list exceeds uint8 length",
        )
    }
    write_i64(value, input.entity_unique_id)
    write_u8(value, input.player_permissions)
    write_u8(value, input.command_permissions)
    write_u8(value, u8(len(input.layers)))
    for layer in input.layers {
        write_ability_layer(value, layer)
    }
    return nil
}

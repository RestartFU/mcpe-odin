package gt_protocol

import mcpe_runtime "mcpe:runtime"

new_bitset :: proc(
    size: int,
    allocator := context.allocator,
) -> (result: Bitset, err: mcpe_runtime.Error) {
    if size < 0 {
        return {}, codec_error(
            .Invalid_Argument,
            "gophertunnel.protocol.new_bitset",
            "bitset size cannot be negative",
        )
    }
    result.size = size
    result.words = make([]u64, (size + 63) / 64, allocator)
    return
}

destroy_bitset :: proc(
    value: ^Bitset,
    allocator := context.allocator,
) {
    if value == nil {
        return
    }
    delete(value.words, allocator)
    value^ = {}
}

bitset_storage_valid :: proc(value: Bitset) -> bool {
    if value.size < 0 || len(value.words) != (value.size + 63) / 64 {
        return false
    }
    final_bits := value.size % 64
    if final_bits != 0 && len(value.words) != 0 {
        valid_mask := (u64(1) << u64(final_bits)) - 1
        if value.words[len(value.words) - 1] &~ valid_mask != 0 {
            return false
        }
    }
    return true
}

bitset_set :: proc(value: ^Bitset, index: int) -> mcpe_runtime.Error {
    if value == nil ||
       !bitset_storage_valid(value^) ||
       index < 0 ||
       index >= value.size {
        return codec_error(
            .Invalid_Argument,
            "gophertunnel.protocol.bitset_set",
            "bitset index out of bounds",
        )
    }
    value.words[index / 64] |= u64(1) << u64(index % 64)
    return nil
}

bitset_unset :: proc(value: ^Bitset, index: int) -> mcpe_runtime.Error {
    if value == nil ||
       !bitset_storage_valid(value^) ||
       index < 0 ||
       index >= value.size {
        return codec_error(
            .Invalid_Argument,
            "gophertunnel.protocol.bitset_unset",
            "bitset index out of bounds",
        )
    }
    value.words[index / 64] &~= u64(1) << u64(index % 64)
    return nil
}

bitset_load :: proc(value: Bitset, index: int) -> (
    result: bool,
    err: mcpe_runtime.Error,
) {
    if !bitset_storage_valid(value) ||
       index < 0 ||
       index >= value.size {
        return false, codec_error(
            .Invalid_Argument,
            "gophertunnel.protocol.bitset_load",
            "bitset index out of bounds",
        )
    }
    result = value.words[index / 64] &
        (u64(1) << u64(index % 64)) != 0
    return
}

read_bitset :: proc(value: ^Reader, size: int) -> (
    result: Bitset,
    err: mcpe_runtime.Error,
) {
    result, err = new_bitset(size, value.allocator)
    if err != nil {
        return
    }
    for offset := 0; offset < size; offset += 7 {
        octet, read_err := read_u8(value)
        if read_err != nil {
            destroy_bitset(&result, value.allocator)
            return {}, read_err
        }
        remaining := size - offset
        if remaining < 8 {
            invalid_mask := u8(0xff << u8(remaining))
            if octet & invalid_mask != 0 {
                destroy_bitset(&result, value.allocator)
                return {}, codec_error(
                    .Malformed,
                    "gophertunnel.protocol.read_bitset",
                    "bitset overflows declared size",
                )
            }
        }
        payload := octet & 0x7f
        for bit := 0; bit < 7 && offset + bit < size; bit += 1 {
            if payload & (u8(1) << u8(bit)) != 0 {
                result.words[(offset + bit) / 64] |=
                    u64(1) << u64((offset + bit) % 64)
            }
        }
        if octet & 0x80 == 0 {
            return
        }
    }
    destroy_bitset(&result, value.allocator)
    return {}, codec_error(
        .Malformed,
        "gophertunnel.protocol.read_bitset",
        "bitset overflows declared size",
    )
}

write_bitset :: proc(
    value: ^Writer,
    input: Bitset,
    size: int,
) -> mcpe_runtime.Error {
    if input.size != size || !bitset_storage_valid(input) {
        return codec_error(
            .Invalid_Argument,
            "gophertunnel.protocol.write_bitset",
            "bitset size mismatch",
        )
    }
    last_set_bit := -1
    for index := 0; index < size; index += 1 {
        if input.words[index / 64] &
           (u64(1) << u64(index % 64)) != 0 {
            last_set_bit = index
        }
    }
    if last_set_bit < 0 {
        write_u8(value, 0)
        return nil
    }
    last_group := last_set_bit / 7
    for group := 0; group <= last_group; group += 1 {
        octet: u8
        offset := group * 7
        for bit := 0; bit < 7 && offset + bit < size; bit += 1 {
            if input.words[(offset + bit) / 64] &
               (u64(1) << u64((offset + bit) % 64)) != 0 {
                octet |= u8(1) << u8(bit)
            }
        }
        if group < last_group {
            octet |= 0x80
        }
        write_u8(value, octet)
    }
    return nil
}

read_parameter_keyframe_value :: proc(value: ^Reader) -> (
    result: Parameter_Keyframe_Value,
    err: mcpe_runtime.Error,
) {
    result.time = read_f32(value) or_return
    result.value = read_vec3(value) or_return
    return
}

write_parameter_keyframe_value :: proc(
    value: ^Writer,
    input: Parameter_Keyframe_Value,
) {
    write_f32(value, input.time)
    write_vec3(value, input.value)
}

destroy_waypoint :: proc(
    waypoint: Waypoint,
    allocator := context.allocator,
) {
    if waypoint.texture_path.set {
        delete(waypoint.texture_path.value, allocator)
    }
}

read_waypoint_world_position :: proc(value: ^Reader) -> (
    result: Waypoint_World_Position,
    err: mcpe_runtime.Error,
) {
    result.position = read_vec3(value) or_return
    result.dimension_id = read_varint32(value) or_return
    return
}

write_waypoint_world_position :: proc(
    value: ^Writer,
    input: Waypoint_World_Position,
) {
    write_vec3(value, input.position)
    write_varint32(value, input.dimension_id)
}

read_waypoint :: proc(value: ^Reader) -> (
    result: Waypoint,
    err: mcpe_runtime.Error,
) {
    result.update_flag = read_u32(value) or_return
    result.visible.set, err = read_bool(value)
    if err == nil && result.visible.set {
        result.visible.value, err = read_bool(value)
    }
    if err == nil {
        result.world_position.set, err = read_bool(value)
    }
    if err == nil && result.world_position.set {
        result.world_position.value, err =
            read_waypoint_world_position(value)
    }
    if err == nil {
        result.texture_path.set, err = read_bool(value)
    }
    if err == nil && result.texture_path.set {
        result.texture_path.value, err = read_string(value)
    }
    if err == nil {
        result.icon_size.set, err = read_bool(value)
    }
    if err == nil && result.icon_size.set {
        result.icon_size.value, err = read_vec2(value)
    }
    if err == nil {
        result.color.set, err = read_bool(value)
    }
    if err == nil && result.color.set {
        result.color.value, err = read_i32(value)
    }
    if err == nil {
        result.client_position_authority.set, err = read_bool(value)
    }
    if err == nil && result.client_position_authority.set {
        result.client_position_authority.value, err = read_bool(value)
    }
    if err == nil {
        result.actor_unique_id.set, err = read_bool(value)
    }
    if err == nil && result.actor_unique_id.set {
        result.actor_unique_id.value, err = read_varint64(value)
    }
    if err != nil {
        destroy_waypoint(result, value.allocator)
        result = {}
    }
    return
}

write_waypoint :: proc(
    value: ^Writer,
    input: Waypoint,
) {
    write_u32(value, input.update_flag)
    write_bool(value, input.visible.set)
    if input.visible.set {
        write_bool(value, input.visible.value)
    }
    write_bool(value, input.world_position.set)
    if input.world_position.set {
        write_waypoint_world_position(
            value,
            input.world_position.value,
        )
    }
    write_bool(value, input.texture_path.set)
    if input.texture_path.set {
        write_string(value, input.texture_path.value)
    }
    write_bool(value, input.icon_size.set)
    if input.icon_size.set {
        write_vec2(value, input.icon_size.value)
    }
    write_bool(value, input.color.set)
    if input.color.set {
        write_i32(value, input.color.value)
    }
    write_bool(value, input.client_position_authority.set)
    if input.client_position_authority.set {
        write_bool(value, input.client_position_authority.value)
    }
    write_bool(value, input.actor_unique_id.set)
    if input.actor_unique_id.set {
        write_varint64(value, input.actor_unique_id.value)
    }
}

read_locator_bar_waypoint :: proc(value: ^Reader) -> (
    result: Locator_Bar_Waypoint,
    err: mcpe_runtime.Error,
) {
    result.group_handle = read_uuid(value) or_return
    result.waypoint = read_waypoint(value) or_return
    result.action, err = read_u8(value)
    if err != nil {
        destroy_waypoint(result.waypoint, value.allocator)
        result = {}
    }
    return
}

write_locator_bar_waypoint :: proc(
    value: ^Writer,
    input: Locator_Bar_Waypoint,
) {
    write_uuid(value, input.group_handle)
    write_waypoint(value, input.waypoint)
    write_u8(value, input.action)
}

read_sync_world_clock_state_data :: proc(value: ^Reader) -> (
    result: Sync_World_Clock_State_Data,
    err: mcpe_runtime.Error,
) {
    result.clock_id = read_varuint64(value) or_return
    result.time = read_varint32(value) or_return
    result.paused = read_bool(value) or_return
    return
}

write_sync_world_clock_state_data :: proc(
    value: ^Writer,
    input: Sync_World_Clock_State_Data,
) {
    write_varuint64(value, input.clock_id)
    write_varint32(value, input.time)
    write_bool(value, input.paused)
}

destroy_time_marker_data :: proc(
    marker: Time_Marker_Data,
    allocator := context.allocator,
) {
    delete(marker.name, allocator)
}

read_time_marker_data :: proc(value: ^Reader) -> (
    result: Time_Marker_Data,
    err: mcpe_runtime.Error,
) {
    result.id = read_varuint64(value) or_return
    result.name = read_string(value) or_return
    result.time, err = read_varint32(value)
    if err == nil {
        result.period.set, err = read_bool(value)
    }
    if err == nil && result.period.set {
        result.period.value, err = read_i32(value)
    }
    if err != nil {
        destroy_time_marker_data(result, value.allocator)
        result = {}
    }
    return
}

write_time_marker_data :: proc(
    value: ^Writer,
    input: Time_Marker_Data,
) {
    write_varuint64(value, input.id)
    write_string(value, input.name)
    write_varint32(value, input.time)
    write_bool(value, input.period.set)
    if input.period.set {
        write_i32(value, input.period.value)
    }
}

destroy_time_marker_slice :: proc(
    markers: []Time_Marker_Data,
    allocator := context.allocator,
) {
    for marker in markers {
        destroy_time_marker_data(marker, allocator)
    }
    delete(markers, allocator)
}

read_time_marker_slice :: proc(value: ^Reader) -> (
    result: []Time_Marker_Data,
    err: mcpe_runtime.Error,
) {
    count := read_varuint32(value) or_return
    if count > MAX_COLLECTION_ELEMENTS {
        return nil, codec_error(
            .Limit_Exceeded,
            "gophertunnel.protocol.read_time_marker_slice",
            "time markers exceed entry limit",
        )
    }
    result = make([]Time_Marker_Data, int(count), value.allocator)
    for &marker, index in result {
        marker, err = read_time_marker_data(value)
        if err != nil {
            for previous in result[:index] {
                destroy_time_marker_data(previous, value.allocator)
            }
            delete(result, value.allocator)
            result = nil
            return
        }
    }
    return
}

write_time_marker_slice :: proc(
    value: ^Writer,
    input: []Time_Marker_Data,
) -> mcpe_runtime.Error {
    if len(input) > MAX_COLLECTION_ELEMENTS {
        return codec_error(
            .Limit_Exceeded,
            "gophertunnel.protocol.write_time_marker_slice",
            "time markers exceed entry limit",
        )
    }
    write_varuint32(value, u32(len(input)))
    for marker in input {
        write_time_marker_data(value, marker)
    }
    return nil
}

destroy_world_clock_data :: proc(
    clock: World_Clock_Data,
    allocator := context.allocator,
) {
    delete(clock.name, allocator)
    destroy_time_marker_slice(clock.time_markers, allocator)
}

read_world_clock_data :: proc(value: ^Reader) -> (
    result: World_Clock_Data,
    err: mcpe_runtime.Error,
) {
    result.id = read_varuint64(value) or_return
    result.name = read_string(value) or_return
    result.time, err = read_varint32(value)
    if err == nil {
        result.paused, err = read_bool(value)
    }
    if err == nil {
        result.time_markers, err = read_time_marker_slice(value)
    }
    if err != nil {
        destroy_world_clock_data(result, value.allocator)
        result = {}
    }
    return
}

write_world_clock_data :: proc(
    value: ^Writer,
    input: World_Clock_Data,
) -> mcpe_runtime.Error {
    write_varuint64(value, input.id)
    write_string(value, input.name)
    write_varint32(value, input.time)
    write_bool(value, input.paused)
    write_time_marker_slice(value, input.time_markers) or_return
    return nil
}

destroy_cache_blob :: proc(
    blob: Cache_Blob,
    allocator := context.allocator,
) {
    delete(blob.payload, allocator)
}

read_cache_blob :: proc(value: ^Reader) -> (
    result: Cache_Blob,
    err: mcpe_runtime.Error,
) {
    result.hash = read_u64(value) or_return
    result.payload = read_byte_slice(value) or_return
    return
}

write_cache_blob :: proc(value: ^Writer, input: Cache_Blob) {
    write_u64(value, input.hash)
    write_byte_slice(value, input.payload)
}

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

read_game_rule :: proc(value: ^Reader) -> (
    result: Game_Rule,
    err: mcpe_runtime.Error,
) {
    result.name = read_string(value) or_return
    result.can_be_modified_by_player, err = read_bool(value)
    if err != nil {
        delete(result.name, value.allocator)
        result = {}
        return
    }
    rule_type, read_err := read_varuint32(value)
    if read_err != nil {
        delete(result.name, value.allocator)
        result = {}
        err = read_err
        return
    }
    switch rule_type {
    case 1:
        rule_value, value_err := read_bool(value)
        if value_err != nil {
            delete(result.name, value.allocator)
            result = {}
            err = value_err
            return
        }
        result.value = rule_value
    case 2:
        rule_value, value_err := read_u32(value)
        if value_err != nil {
            delete(result.name, value.allocator)
            result = {}
            err = value_err
            return
        }
        result.value = rule_value
    case 3:
        rule_value, value_err := read_f32(value)
        if value_err != nil {
            delete(result.name, value.allocator)
            result = {}
            err = value_err
            return
        }
        result.value = rule_value
    case:
        delete(result.name, value.allocator)
        result = {}
        err = codec_error(
            .Malformed,
            "gophertunnel.protocol.read_game_rule",
            "unknown game rule type",
        )
    }
    return
}

write_game_rule :: proc(
    value: ^Writer,
    input: Game_Rule,
) -> mcpe_runtime.Error {
    write_string(value, input.name)
    write_bool(value, input.can_be_modified_by_player)
    switch rule_value in input.value {
    case bool:
        write_varuint32(value, 1)
        write_bool(value, rule_value)
    case u32:
        write_varuint32(value, 2)
        write_u32(value, rule_value)
    case f32:
        write_varuint32(value, 3)
        write_f32(value, rule_value)
    case:
        return codec_error(
            .Invalid_Argument,
            "gophertunnel.protocol.write_game_rule",
            "nil game rule value",
        )
    }
    return nil
}

read_pack_setting :: proc(value: ^Reader) -> (
    result: Pack_Setting,
    err: mcpe_runtime.Error,
) {
    result.name = read_string(value) or_return
    setting_type, type_err := read_varuint32(value)
    if type_err != nil {
        delete(result.name, value.allocator)
        result = {}
        err = type_err
        return
    }
    switch setting_type {
    case 0:
        setting_value, value_err := read_f32(value)
        if value_err != nil {
            delete(result.name, value.allocator)
            result = {}
            err = value_err
            return
        }
        result.value = setting_value
    case 1:
        setting_value, value_err := read_bool(value)
        if value_err != nil {
            delete(result.name, value.allocator)
            result = {}
            err = value_err
            return
        }
        result.value = setting_value
    case 2:
        setting_value, value_err := read_string(value)
        if value_err != nil {
            delete(result.name, value.allocator)
            result = {}
            err = value_err
            return
        }
        result.value = setting_value
    case:
        delete(result.name, value.allocator)
        result = {}
        err = codec_error(
            .Malformed,
            "gophertunnel.protocol.read_pack_setting",
            "unknown pack setting type",
        )
    }
    return
}

write_pack_setting :: proc(
    value: ^Writer,
    input: Pack_Setting,
) -> mcpe_runtime.Error {
    write_string(value, input.name)
    switch setting_value in input.value {
    case f32:
        write_varuint32(value, 0)
        write_f32(value, setting_value)
    case bool:
        write_varuint32(value, 1)
        write_bool(value, setting_value)
    case string:
        write_varuint32(value, 2)
        write_string(value, setting_value)
    case:
        return codec_error(
            .Invalid_Argument,
            "gophertunnel.protocol.write_pack_setting",
            "nil pack setting value",
        )
    }
    return nil
}

read_ability_value :: proc(value: ^Reader) -> (
    result: Ability_Value,
    err: mcpe_runtime.Error,
) {
    value_type := read_u8(value) or_return
    bool_value := read_bool(value) or_return
    float_value := read_f32(value) or_return
    switch value_type {
    case 1: result = bool_value
    case 2: result = float_value
    case:
        err = codec_error(
            .Malformed,
            "gophertunnel.protocol.read_ability_value",
            "unknown ability value type",
        )
    }
    return
}

write_ability_value :: proc(
    value: ^Writer,
    input: Ability_Value,
) -> mcpe_runtime.Error {
    switch ability_value in input {
    case bool:
        write_u8(value, 1)
        write_bool(value, ability_value)
        write_f32(value, 0)
    case f32:
        write_u8(value, 2)
        write_bool(value, false)
        write_f32(value, ability_value)
    case:
        return codec_error(
            .Invalid_Argument,
            "gophertunnel.protocol.write_ability_value",
            "nil ability value",
        )
    }
    return nil
}

destroy_data_store_update :: proc(
    update: Data_Store_Update,
    allocator := context.allocator,
) {
    delete(update.data_store_name, allocator)
    delete(update.property, allocator)
    delete(update.path, allocator)
    delete(update.string_value, allocator)
}

read_data_store_update :: proc(value: ^Reader) -> (
    result: Data_Store_Update,
    err: mcpe_runtime.Error,
) {
    result.data_store_name = read_string(value) or_return
    result.property, err = read_string(value)
    if err == nil {
        result.path, err = read_string(value)
    }
    if err == nil {
        result.control_type, err = read_varuint32(value)
    }
    if err == nil {
        switch result.control_type {
        case Data_Store_Control_Double:
            result.double_value, err = read_f64(value)
        case Data_Store_Control_Boolean:
            result.bool_value, err = read_bool(value)
        case Data_Store_Control_String:
            result.string_value, err = read_string(value)
        case:
            err = codec_error(
                .Malformed,
                "gophertunnel.protocol.read_data_store_update",
                "unknown data store control type",
            )
        }
    }
    if err == nil {
        result.property_update_count, err = read_u32(value)
    }
    if err == nil {
        result.path_update_count, err = read_u32(value)
    }
    if err != nil {
        destroy_data_store_update(result, value.allocator)
        result = {}
    }
    return
}

write_data_store_update :: proc(
    value: ^Writer,
    input: Data_Store_Update,
) -> mcpe_runtime.Error {
    write_string(value, input.data_store_name)
    write_string(value, input.property)
    write_string(value, input.path)
    write_varuint32(value, input.control_type)
    switch input.control_type {
    case Data_Store_Control_Double:
        write_f64(value, input.double_value)
    case Data_Store_Control_Boolean:
        write_bool(value, input.bool_value)
    case Data_Store_Control_String:
        write_string(value, input.string_value)
    case:
        return codec_error(
            .Invalid_Argument,
            "gophertunnel.protocol.write_data_store_update",
            "unknown data store control type",
        )
    }
    write_u32(value, input.property_update_count)
    write_u32(value, input.path_update_count)
    return nil
}

MAX_DATA_STORE_DEPTH :: 64
MAX_DATA_STORE_NODES :: 64 * 1024

destroy_data_store_property_value :: proc(
    property: Data_Store_Property_Value,
    allocator := context.allocator,
) {
    delete(property.string_value, allocator)
    for child in property.list_value {
        destroy_data_store_property_value(child, allocator)
    }
    delete(property.list_value, allocator)
    for entry in property.map_value {
        delete(entry.key, allocator)
        destroy_data_store_property_value(entry.value, allocator)
    }
    delete(property.map_value, allocator)
}

read_data_store_property_value :: proc(
    value: ^Reader,
    remaining_nodes: ^int,
    depth: int = 0,
) -> (
    result: Data_Store_Property_Value,
    err: mcpe_runtime.Error,
) {
    if depth > MAX_DATA_STORE_DEPTH {
        return {}, codec_error(
            .Limit_Exceeded,
            "gophertunnel.protocol.read_data_store_property_value",
            "data store nesting exceeds depth limit",
        )
    }
    result.type = read_i32(value) or_return
    switch result.type {
    case Data_Store_Property_Type_None:
    case Data_Store_Property_Type_Bool:
        result.bool_value = read_bool(value) or_return
    case Data_Store_Property_Type_Int64:
        result.int64_value = read_i64(value) or_return
    case Data_Store_Property_Type_Double:
        result.double_value = read_f64(value) or_return
    case Data_Store_Property_Type_String:
        result.string_value = read_string(value) or_return
    case Data_Store_Property_Type_List:
        count := read_varuint32(value) or_return
        if count > MAX_COLLECTION_ELEMENTS {
            return {}, codec_error(
                .Limit_Exceeded,
                "gophertunnel.protocol.read_data_store_property_value",
                "data store list exceeds entry limit",
            )
        }
        if int(count) > remaining_nodes^ {
            return {}, codec_error(
                .Limit_Exceeded,
                "gophertunnel.protocol.read_data_store_property_value",
                "data store value exceeds node budget",
            )
        }
        remaining_nodes^ -= int(count)
        result.list_value = make(
            []Data_Store_Property_Value,
            int(count),
            value.allocator,
        )
        for &child, index in result.list_value {
            child, err =
                read_data_store_property_value(
                    value,
                    remaining_nodes,
                    depth + 1,
                )
            if err != nil {
                for previous in result.list_value[:index] {
                    destroy_data_store_property_value(
                        previous,
                        value.allocator,
                    )
                }
                delete(result.list_value, value.allocator)
                result = {}
                return
            }
        }
    case Data_Store_Property_Type_Map:
        count := read_varuint32(value) or_return
        if count > MAX_COLLECTION_ELEMENTS {
            return {}, codec_error(
                .Limit_Exceeded,
                "gophertunnel.protocol.read_data_store_property_value",
                "data store map exceeds entry limit",
            )
        }
        if int(count) > remaining_nodes^ {
            return {}, codec_error(
                .Limit_Exceeded,
                "gophertunnel.protocol.read_data_store_property_value",
                "data store value exceeds node budget",
            )
        }
        remaining_nodes^ -= int(count)
        result.map_value = make(
            []Data_Store_Map_Entry,
            int(count),
            value.allocator,
        )
        for &entry, index in result.map_value {
            entry.key, err = read_string(value)
            if err != nil {
                for previous in result.map_value[:index] {
                    delete(previous.key, value.allocator)
                    destroy_data_store_property_value(
                        previous.value,
                        value.allocator,
                    )
                }
                delete(result.map_value, value.allocator)
                result = {}
                return
            }
            entry.value, err =
                read_data_store_property_value(
                    value,
                    remaining_nodes,
                    depth + 1,
                )
            if err != nil {
                delete(entry.key, value.allocator)
                for previous in result.map_value[:index] {
                    delete(previous.key, value.allocator)
                    destroy_data_store_property_value(
                        previous.value,
                        value.allocator,
                    )
                }
                delete(result.map_value, value.allocator)
                result = {}
                return
            }
        }
    case:
        err = codec_error(
            .Malformed,
            "gophertunnel.protocol.read_data_store_property_value",
            "unknown data store property type",
        )
    }
    return
}

write_data_store_property_value :: proc(
    value: ^Writer,
    property: Data_Store_Property_Value,
    remaining_nodes: ^int,
    depth: int = 0,
) -> mcpe_runtime.Error {
    if depth > MAX_DATA_STORE_DEPTH {
        return codec_error(
            .Limit_Exceeded,
            "gophertunnel.protocol.write_data_store_property_value",
            "data store nesting exceeds depth limit",
        )
    }
    write_i32(value, property.type)
    switch property.type {
    case Data_Store_Property_Type_None:
    case Data_Store_Property_Type_Bool:
        write_bool(value, property.bool_value)
    case Data_Store_Property_Type_Int64:
        write_i64(value, property.int64_value)
    case Data_Store_Property_Type_Double:
        write_f64(value, property.double_value)
    case Data_Store_Property_Type_String:
        write_string(value, property.string_value)
    case Data_Store_Property_Type_List:
        if len(property.list_value) > MAX_COLLECTION_ELEMENTS {
            return codec_error(
                .Limit_Exceeded,
                "gophertunnel.protocol.write_data_store_property_value",
                "data store list exceeds entry limit",
            )
        }
        if len(property.list_value) > remaining_nodes^ {
            return codec_error(
                .Limit_Exceeded,
                "gophertunnel.protocol.write_data_store_property_value",
                "data store value exceeds node budget",
            )
        }
        remaining_nodes^ -= len(property.list_value)
        write_varuint32(value, u32(len(property.list_value)))
        for child in property.list_value {
            write_data_store_property_value(
                value,
                child,
                remaining_nodes,
                depth + 1,
            ) or_return
        }
    case Data_Store_Property_Type_Map:
        if len(property.map_value) > MAX_COLLECTION_ELEMENTS {
            return codec_error(
                .Limit_Exceeded,
                "gophertunnel.protocol.write_data_store_property_value",
                "data store map exceeds entry limit",
            )
        }
        if len(property.map_value) > remaining_nodes^ {
            return codec_error(
                .Limit_Exceeded,
                "gophertunnel.protocol.write_data_store_property_value",
                "data store value exceeds node budget",
            )
        }
        remaining_nodes^ -= len(property.map_value)
        write_varuint32(value, u32(len(property.map_value)))
        for entry in property.map_value {
            write_string(value, entry.key)
            write_data_store_property_value(
                value,
                entry.value,
                remaining_nodes,
                depth + 1,
            ) or_return
        }
    case:
        return codec_error(
            .Invalid_Argument,
            "gophertunnel.protocol.write_data_store_property_value",
            "unknown data store property type",
        )
    }
    return nil
}

destroy_data_store_change_entry :: proc(
    entry: Data_Store_Change_Entry,
    allocator := context.allocator,
) {
    switch entry.change_type {
    case Data_Store_Change_Type_Update:
        destroy_data_store_update(entry.update, allocator)
    case Data_Store_Change_Type_Change:
        delete(entry.change.data_store_name, allocator)
        delete(entry.change.property, allocator)
        destroy_data_store_property_value(
            entry.change.new_value,
            allocator,
        )
    case Data_Store_Change_Type_Removal:
        delete(entry.removal.data_store_name, allocator)
    case:
    }
}

read_data_store_change_entry :: proc(
    value: ^Reader,
    remaining_nodes: ^int,
) -> (
    result: Data_Store_Change_Entry,
    err: mcpe_runtime.Error,
) {
    result.change_type = read_varuint32(value) or_return
    switch result.change_type {
    case Data_Store_Change_Type_Update:
        result.update = read_data_store_update(value) or_return
    case Data_Store_Change_Type_Change:
        result.change.data_store_name = read_string(value) or_return
        result.change.property, err = read_string(value)
        if err == nil {
            result.change.update_count, err = read_u32(value)
        }
        if err == nil {
            result.change.new_value, err =
                read_data_store_property_value(
                    value,
                    remaining_nodes,
                )
        }
        if err != nil {
            destroy_data_store_change_entry(result, value.allocator)
            result = {}
        }
    case Data_Store_Change_Type_Removal:
        result.removal.data_store_name =
            read_string(value) or_return
    case:
        err = codec_error(
            .Malformed,
            "gophertunnel.protocol.read_data_store_change_entry",
            "unknown data store change type",
        )
    }
    return
}

write_data_store_change_entry :: proc(
    value: ^Writer,
    entry: Data_Store_Change_Entry,
    remaining_nodes: ^int,
) -> mcpe_runtime.Error {
    write_varuint32(value, entry.change_type)
    switch entry.change_type {
    case Data_Store_Change_Type_Update:
        write_data_store_update(value, entry.update) or_return
    case Data_Store_Change_Type_Change:
        write_string(value, entry.change.data_store_name)
        write_string(value, entry.change.property)
        write_u32(value, entry.change.update_count)
        write_data_store_property_value(
            value,
            entry.change.new_value,
            remaining_nodes,
        ) or_return
    case Data_Store_Change_Type_Removal:
        write_string(value, entry.removal.data_store_name)
    case:
        return codec_error(
            .Invalid_Argument,
            "gophertunnel.protocol.write_data_store_change_entry",
            "unknown data store change type",
        )
    }
    return nil
}

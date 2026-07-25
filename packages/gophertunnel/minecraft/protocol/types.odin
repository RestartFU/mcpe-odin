package gt_protocol

Vec2 :: [2]f32
Vec3 :: [3]f32
UUID :: [16]u8
RGBA :: struct {
    r, g, b, a: u8,
}

Entity_Link_Remove    :: u8(0)
Entity_Link_Rider     :: u8(1)
Entity_Link_Passenger :: u8(2)

Entity_Link :: struct {
    ridden_entity_unique_id:   i64,
    rider_entity_unique_id:    i64,
    type:                      u8,
    immediate:                 bool,
    rider_initiated:           bool,
    vehicle_angular_velocity:  f32,
}

Pixel_Request :: struct {
    colour: RGBA,
    index:  u16,
}

Player_Armour_Damage_Entry :: struct {
    armour_slot: i32,
    damage:      i16,
}

Optional :: struct($T: typeid) {
    set:   bool,
    value: T,
}

option :: proc(value: $T) -> Optional(T) {
    return {set = true, value = value}
}

optional_value :: proc(optional: Optional($T)) -> (
    value: T,
    set: bool,
) {
    return optional.value, optional.set
}

Block_Pos :: [3]i32
Chunk_Pos :: [2]i32
Sub_Chunk_Pos :: [3]i32

block_pos_x :: proc(pos: Block_Pos) -> i32 {
    return pos[0]
}

block_pos_y :: proc(pos: Block_Pos) -> i32 {
    return pos[1]
}

block_pos_z :: proc(pos: Block_Pos) -> i32 {
    return pos[2]
}

chunk_pos_x :: proc(pos: Chunk_Pos) -> i32 {
    return pos[0]
}

chunk_pos_z :: proc(pos: Chunk_Pos) -> i32 {
    return pos[1]
}

sub_chunk_pos_x :: proc(pos: Sub_Chunk_Pos) -> i32 {
    return pos[0]
}

sub_chunk_pos_y :: proc(pos: Sub_Chunk_Pos) -> i32 {
    return pos[1]
}

sub_chunk_pos_z :: proc(pos: Sub_Chunk_Pos) -> i32 {
    return pos[2]
}

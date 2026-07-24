package gt_protocol

Vec2 :: [2]f32
Vec3 :: [3]f32
UUID :: [16]u8
RGBA :: struct {
    r, g, b, a: u8,
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

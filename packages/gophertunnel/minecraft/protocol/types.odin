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

Scoreboard_Identity_Player      :: u8(1)
Scoreboard_Identity_Entity      :: u8(2)
Scoreboard_Identity_Fake_Player :: u8(3)

Scoreboard_Entry :: struct {
    entry_id:         i64,
    objective_name:   string,
    score:            i32,
    identity_type:    u8,
    entity_unique_id: i64,
    display_name:     string,
}

Scoreboard_Identity_Entry :: struct {
    entry_id:         i64,
    entity_unique_id: i64,
}

Trim_Pattern :: struct {
    item_name:  string,
    pattern_id: string,
}

Trim_Material :: struct {
    material_id: string,
    colour:      string,
    item_name:   string,
}

Generator_Legacy    :: i32(0)
Generator_Overworld :: i32(1)
Generator_Flat      :: i32(2)
Generator_Nether    :: i32(3)
Generator_End       :: i32(4)
Generator_Void      :: i32(5)

Dimension_Definition :: struct {
    name:           string,
    range:          [2]i32,
    generator:      i32,
    dimension_type: i32,
}

Generation_Feature :: struct {
    name: string,
    json: []u8,
}

Store_Entry_Point_Info :: struct {
    store_id:   string,
    store_name: string,
}

Presence_Info :: struct {
    experience_name: Optional(string),
    world_name:      Optional(string),
    rich_presence_id: string,
}

Camera_Aim_Assist_Actor_Priority_Data :: struct {
    preset_index:   i32,
    category_index: i32,
    actor_index:    i32,
    priority:       i32,
}

Ability_Layer_Type_Custom_Cache   :: u16(0)
Ability_Layer_Type_Base           :: u16(1)
Ability_Layer_Type_Spectator      :: u16(2)
Ability_Layer_Type_Commands       :: u16(3)
Ability_Layer_Type_Editor         :: u16(4)
Ability_Layer_Type_Loading_Screen :: u16(5)

Ability_Layer :: struct {
    type:               u16,
    abilities:          u32,
    values:             u32,
    fly_speed:          f32,
    vertical_fly_speed: f32,
    walk_speed:         f32,
}

Ability_Data :: struct {
    entity_unique_id:    i64,
    player_permissions:  u8,
    command_permissions: u8,
    layers:              []Ability_Layer,
}

Full_Container_Name :: struct {
    container_id:         u8,
    dynamic_container_id: Optional(u32),
}

Game_Rule_Value :: union {
    bool,
    u32,
    f32,
}

Game_Rule :: struct {
    name:                      string,
    can_be_modified_by_player: bool,
    value:                     Game_Rule_Value,
}

Pack_Setting_Value :: union {
    f32,
    bool,
    string,
}

Pack_Setting :: struct {
    name:  string,
    value: Pack_Setting_Value,
}

Ability_Value :: union {
    bool,
    f32,
}

Data_Store_Control_Double  :: u32(0)
Data_Store_Control_Boolean :: u32(1)
Data_Store_Control_String  :: u32(2)

Data_Store_Update :: struct {
    data_store_name:       string,
    property:              string,
    path:                  string,
    control_type:          u32,
    double_value:          f64,
    bool_value:            bool,
    string_value:          string,
    property_update_count: u32,
    path_update_count:     u32,
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

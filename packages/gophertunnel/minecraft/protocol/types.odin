package gt_protocol

Vec2 :: [2]f32
Vec3 :: [3]f32
UUID :: [16]u8
RGBA :: struct {
    r, g, b, a: u8,
}

Bitset :: struct {
    size:  int,
    words: []u64,
}

Entity_Data_Flag_Count :: 130

Graphics_Override_Parameter_Type_Sky_Zenith_Color        :: u8(0)
Graphics_Override_Parameter_Type_Sky_Horizon_Color       :: u8(1)
Graphics_Override_Parameter_Type_Horizon_Blend_Min       :: u8(2)
Graphics_Override_Parameter_Type_Horizon_Blend_Max       :: u8(3)
Graphics_Override_Parameter_Type_Horizon_Blend_Start     :: u8(4)
Graphics_Override_Parameter_Type_Horizon_Blend_Mie_Start :: u8(5)
Graphics_Override_Parameter_Type_Rayleigh_Strength       :: u8(6)
Graphics_Override_Parameter_Type_Sun_Mie_Strength        :: u8(7)
Graphics_Override_Parameter_Type_Moon_Mie_Strength       :: u8(8)
Graphics_Override_Parameter_Type_Sun_Glare_Shape         :: u8(9)
Graphics_Override_Parameter_Type_Chlorophyll             :: u8(10)
Graphics_Override_Parameter_Type_CDOM                    :: u8(11)
Graphics_Override_Parameter_Type_Suspended_Sediment      :: u8(12)
Graphics_Override_Parameter_Type_Waves_Depth             :: u8(13)
Graphics_Override_Parameter_Type_Waves_Frequency         :: u8(14)
Graphics_Override_Parameter_Type_Waves_Frequency_Scaling :: u8(15)
Graphics_Override_Parameter_Type_Waves_Speed             :: u8(16)
Graphics_Override_Parameter_Type_Waves_Speed_Scaling     :: u8(17)
Graphics_Override_Parameter_Type_Waves_Shape             :: u8(18)
Graphics_Override_Parameter_Type_Waves_Octaves           :: u8(19)
Graphics_Override_Parameter_Type_Waves_Mix               :: u8(20)
Graphics_Override_Parameter_Type_Waves_Pull              :: u8(21)
Graphics_Override_Parameter_Type_Waves_Direction_Increment :: u8(22)
Graphics_Override_Parameter_Type_Midtones_Contrast       :: u8(23)
Graphics_Override_Parameter_Type_Highlights_Contrast     :: u8(24)
Graphics_Override_Parameter_Type_Shadows_Contrast        :: u8(25)
Graphics_Override_Parameter_Type_Highlights_Gain         :: u8(26)
Graphics_Override_Parameter_Type_Highlights_Gamma        :: u8(27)
Graphics_Override_Parameter_Type_Highlights_Offset       :: u8(28)
Graphics_Override_Parameter_Type_Highlights_Saturation   :: u8(29)
Graphics_Override_Parameter_Type_Midtones_Gain           :: u8(30)
Graphics_Override_Parameter_Type_Midtones_Gamma          :: u8(31)
Graphics_Override_Parameter_Type_Midtones_Offset         :: u8(32)
Graphics_Override_Parameter_Type_Midtones_Saturation     :: u8(33)
Graphics_Override_Parameter_Type_Shadows_Gain            :: u8(34)
Graphics_Override_Parameter_Type_Shadows_Gamma           :: u8(35)
Graphics_Override_Parameter_Type_Shadows_Offset          :: u8(36)
Graphics_Override_Parameter_Type_Shadows_Saturation      :: u8(37)
Graphics_Override_Parameter_Type_Highlights_Min          :: u8(38)
Graphics_Override_Parameter_Type_Shadows_Max             :: u8(39)
Graphics_Override_Parameter_Type_Temperature             :: u8(40)
Graphics_Override_Parameter_Type_Sun_Color               :: u8(41)
Graphics_Override_Parameter_Type_Sun_Illuminance         :: u8(42)
Graphics_Override_Parameter_Type_Moon_Color              :: u8(43)
Graphics_Override_Parameter_Type_Moon_Illuminance        :: u8(44)
Graphics_Override_Parameter_Type_Flash_Color             :: u8(45)
Graphics_Override_Parameter_Type_Flash_Illuminance       :: u8(46)
Graphics_Override_Parameter_Type_Ambient_Color           :: u8(47)
Graphics_Override_Parameter_Type_Ambient_Illuminance     :: u8(48)
Graphics_Override_Parameter_Type_Emissive_Desaturation   :: u8(49)
Graphics_Override_Parameter_Type_Sky_Intensity           :: u8(50)
Graphics_Override_Parameter_Type_Orbital_Offset_Degrees  :: u8(51)

Parameter_Keyframe_Value :: struct {
    time:  f32,
    value: Vec3,
}

Waypoint_Action_None   :: u8(0)
Waypoint_Action_Add    :: u8(1)
Waypoint_Action_Remove :: u8(2)
Waypoint_Action_Update :: u8(3)

Waypoint_Update_Flag_Visible                   :: u32(1 << 0)
Waypoint_Update_Flag_Position                  :: u32(1 << 1)
Waypoint_Update_Flag_Texture_ID                :: u32(1 << 2)
Waypoint_Update_Flag_Color                     :: u32(1 << 3)
Waypoint_Update_Flag_Client_Position_Authority :: u32(1 << 4)
Waypoint_Update_Flag_Actor_Unique_ID           :: u32(1 << 5)

Waypoint_Texture_Square       :: i32(2)
Waypoint_Texture_Circle       :: i32(3)
Waypoint_Texture_Small_Square :: i32(4)
Waypoint_Texture_Small_Star   :: i32(5)

Waypoint_World_Position :: struct {
    position:     Vec3,
    dimension_id: i32,
}

Waypoint :: struct {
    update_flag:               u32,
    visible:                   Optional(bool),
    world_position:            Optional(Waypoint_World_Position),
    texture_path:              Optional(string),
    icon_size:                 Optional(Vec2),
    color:                     Optional(i32),
    client_position_authority: Optional(bool),
    actor_unique_id:           Optional(i64),
}

Locator_Bar_Waypoint :: struct {
    group_handle: UUID,
    waypoint:     Waypoint,
    action:       u8,
}

Clock_Payload_Type_Sync_State          :: u32(0)
Clock_Payload_Type_Initialize_Registry :: u32(1)
Clock_Payload_Type_Add_Time_Marker     :: u32(2)
Clock_Payload_Type_Remove_Time_Marker  :: u32(3)

Sync_World_Clock_State_Data :: struct {
    clock_id: u64,
    time:     i32,
    paused:   bool,
}

Time_Marker_Data :: struct {
    id:     u64,
    name:   string,
    time:   i32,
    period: Optional(i32),
}

World_Clock_Data :: struct {
    id:           u64,
    name:         string,
    time:         i32,
    paused:       bool,
    time_markers: []Time_Marker_Data,
}

Cache_Blob :: struct {
    hash:    u64,
    payload: []u8,
}

Structure_Mirror_None      :: u8(0)
Structure_Mirror_X_Axis    :: u8(1)
Structure_Mirror_Z_Axis    :: u8(2)
Structure_Mirror_Both_Axes :: u8(3)

Structure_Rotation_None       :: u8(0)
Structure_Rotation_Rotate_90  :: u8(1)
Structure_Rotation_Rotate_180 :: u8(2)
Structure_Rotation_Rotate_270 :: u8(3)

Animation_Mode_None   :: u8(0)
Animation_Mode_Layers :: u8(1)
Animation_Mode_Blocks :: u8(2)

Structure_Settings :: struct {
    palette_name:                  string,
    ignore_entities:               bool,
    ignore_blocks:                 bool,
    allow_non_ticking_chunks:      bool,
    size:                          Block_Pos,
    offset:                        Block_Pos,
    last_editing_player_unique_id: i64,
    rotation:                      u8,
    mirror:                        u8,
    animation_mode:                u8,
    animation_duration:            f32,
    integrity:                     f32,
    seed:                          u32,
    pivot:                         Vec3,
}

Command_Origin_Player                      :: u32(0)
Command_Origin_Block                       :: u32(1)
Command_Origin_Minecart_Block              :: u32(2)
Command_Origin_Dev_Console                 :: u32(3)
Command_Origin_Test                        :: u32(4)
Command_Origin_Automation_Player           :: u32(5)
Command_Origin_Client_Automation           :: u32(6)
Command_Origin_Dedicated_Server            :: u32(7)
Command_Origin_Entity                      :: u32(8)
Command_Origin_Virtual                     :: u32(9)
Command_Origin_Game_Argument               :: u32(10)
Command_Origin_Entity_Server               :: u32(11)
Command_Origin_Precompiled                 :: u32(12)
Command_Origin_Game_Director_Entity_Server :: u32(13)
Command_Origin_Script                      :: u32(14)
Command_Origin_Executor                    :: u32(15)

Command_Origin :: struct {
    origin:           u32,
    uuid:             UUID,
    request_id:       string,
    player_unique_id: i64,
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

Data_Store_Property_Type_None   :: i32(0)
Data_Store_Property_Type_Bool   :: i32(1)
Data_Store_Property_Type_Int64  :: i32(2)
Data_Store_Property_Type_Double :: i32(3)
Data_Store_Property_Type_String :: i32(4)
Data_Store_Property_Type_List   :: i32(5)
Data_Store_Property_Type_Map    :: i32(6)

Data_Store_Property_Value :: struct {
    type:         i32,
    bool_value:   bool,
    int64_value:  i64,
    double_value: f64,
    string_value: string,
    list_value:   []Data_Store_Property_Value,
    map_value:    []Data_Store_Map_Entry,
}

Data_Store_Map_Entry :: struct {
    key:   string,
    value: Data_Store_Property_Value,
}

Data_Store_Change :: struct {
    data_store_name: string,
    property:        string,
    update_count:    u32,
    new_value:       Data_Store_Property_Value,
}

Data_Store_Removal :: struct {
    data_store_name: string,
}

Data_Store_Change_Type_Update  :: u32(0)
Data_Store_Change_Type_Change  :: u32(1)
Data_Store_Change_Type_Removal :: u32(2)

Data_Store_Change_Entry :: struct {
    change_type: u32,
    update:      Data_Store_Update,
    change:      Data_Store_Change,
    removal:     Data_Store_Removal,
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

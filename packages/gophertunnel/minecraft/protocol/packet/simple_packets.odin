package gt_packet

import protocol "mcpe:gophertunnel/minecraft/protocol"
import mcpe_runtime "mcpe:runtime"

Client_Bound_Data_Driven_UI_Reload :: struct {}
Refresh_Entitlements :: struct {}
Resource_Packs_Ready_For_Validation :: struct {}

Ticking_Areas_Load_Status :: struct {
    preload: bool,
}

Add_Behaviour_Tree :: struct {
    behaviour_tree: string,
}

Client_Start_Item_Cooldown :: struct {
    category: string,
    duration: i32,
}

Remove_Volume_Entity :: struct {
    entity_runtime_id: u32,
    dimension:         i32,
}

On_Screen_Texture_Animation :: struct {
    animation_type: u32,
}

Automation_Client_Connect :: struct {
    server_uri: string,
}

Photo_Info_Request :: struct {
    photo_id: i64,
}

Map_Create_Locked_Copy :: struct {
    original_map_id: i64,
    new_map_id:      i64,
}

Script_Message :: struct {
    identifier: string,
    data:       []u8,
}

Open_Sign :: struct {
    position:   protocol.Block_Pos,
    front_side: bool,
}

Client_Bound_Data_Driven_UI_Close_Screen :: struct {
    form_id: protocol.Optional(u32),
}

Available_Actor_Identifiers :: struct {
    serialised_entity_identifiers: []u8,
}

Current_Structure_Feature :: struct {
    current_feature: string,
}

Server_Stats :: struct {
    server_time:  f32,
    network_time: f32,
}

Anvil_Damage :: struct {
    damage:         u8,
    anvil_position: protocol.Block_Pos,
}

Debug_Info :: struct {
    player_unique_id: i64,
    data:             []u8,
}

Create_Photo :: struct {
    entity_unique_id: i64,
    photo_name:       string,
    item_name:        string,
}

Code_Builder :: struct {
    url:                      string,
    should_open_code_builder: bool,
}

Education_Resource_URI :: struct {
    resource: protocol.Education_Shared_Resource_URI,
}

Player_Fog :: struct {
    stack: []string,
}

Death_Info :: struct {
    cause:    string,
    messages: []string,
}

Client_Cache_Status :: struct {
    enabled: bool,
}

Level_Event_Generic :: struct {
    event_id:              i32,
    serialised_event_data: []u8,
}

Container_Close :: struct {
    window_id:      u8,
    container_type: u8,
    server_side:    bool,
}

Container_Set_Data :: struct {
    window_id: u8,
    key:       i32,
    value:     i32,
}

GUI_Data_Pick_Item :: struct {
    item_name:    string,
    item_effects: string,
    hot_bar_slot: i32,
}

Completed_Using_Item :: struct {
    used_item_id: i16,
    use_method:   i32,
}

write_string_slice :: proc(
    output: ^protocol.Writer,
    values: []string,
) -> mcpe_runtime.Error {
    if len(values) > protocol.MAX_COLLECTION_ELEMENTS {
        return packet_error(
            .Limit_Exceeded,
            "gophertunnel.packet.write_string_slice",
            "string list exceeds entry limit",
        )
    }
    protocol.write_varuint32(output, u32(len(values)))
    for value in values {
        protocol.write_string(output, value)
    }
    return nil
}

read_string_slice :: proc(
    input: ^protocol.Reader,
) -> (
    values: []string,
    err: mcpe_runtime.Error,
) {
    count := protocol.read_varuint32(input) or_return
    if count > protocol.MAX_COLLECTION_ELEMENTS {
        return nil, packet_error(
            .Limit_Exceeded,
            "gophertunnel.packet.read_string_slice",
            "string list exceeds entry limit",
        )
    }
    values = make([]string, int(count), input.allocator)
    for &value, index in values {
        value, err = protocol.read_string(input)
        if err != nil {
            for previous in values[:index] {
                delete(previous, input.allocator)
            }
            delete(values, input.allocator)
            values = nil
            return
        }
    }
    return
}

destroy_string_slice :: proc(
    values: []string,
    allocator := context.allocator,
) {
    for value in values {
        delete(value, allocator)
    }
    delete(values, allocator)
}

Sound_Data_Event_Stop :: "Stop"

Lesson_Action_Start    :: i32(0)
Lesson_Action_Complete :: i32(1)
Lesson_Action_Restart  :: i32(2)

Enable_Multi_Player  :: i32(0)
Disable_Multi_Player :: i32(1)
Refresh_Join_Code    :: i32(2)

Violation_Type_Malformed                :: i32(0)
Violation_Severity_Warning              :: i32(0)
Violation_Severity_Final_Warning        :: i32(1)
Violation_Severity_Terminating_Connection :: i32(2)

Graphics_Mode_Simple     :: u8(0)
Graphics_Mode_Fancy      :: u8(1)
Graphics_Mode_Advanced   :: u8(2)
Graphics_Mode_Ray_Traced :: u8(3)

Client_Input_Lock_Camera           :: u32(1 << 1)
Client_Input_Lock_Movement         :: u32(1 << 2)
Client_Input_Lock_Lateral_Movement :: u32(1 << 4)
Client_Input_Lock_Sneak            :: u32(1 << 5)
Client_Input_Lock_Jump             :: u32(1 << 6)
Client_Input_Lock_Mount            :: u32(1 << 7)
Client_Input_Lock_Dismount         :: u32(1 << 8)
Client_Input_Lock_Move_Forward     :: u32(1 << 9)
Client_Input_Lock_Move_Backward    :: u32(1 << 10)
Client_Input_Lock_Move_Left        :: u32(1 << 11)
Client_Input_Lock_Move_Right       :: u32(1 << 12)

Agent_Animation :: struct {
    animation:         u8,
    entity_runtime_id: u64,
}

Camera :: struct {
    camera_entity_unique_id: i64,
    target_player_unique_id: i64,
}

Clientbound_Update_Sound_Data :: struct {
    server_sound_handle: u64,
    sound_event:         string,
}

Game_Test_Results :: struct {
    name:      string,
    succeeded: bool,
    error:     string,
}

Hurt_Armour :: struct {
    cause:        i32,
    damage:       i32,
    armour_slots: i64,
}

Lesson_Progress :: struct {
    identifier: string,
    action:     i32,
    score:      i32,
}

Motion_Prediction_Hints :: struct {
    entity_runtime_id: u64,
    velocity:          protocol.Vec3,
    on_ground:         bool,
}

Multi_Player_Settings :: struct {
    action_type: i32,
}

Packet_Violation_Warning :: struct {
    type:              i32,
    severity:          i32,
    packet_id:         i32,
    violation_context: string,
}

Request_Permissions :: struct {
    entity_unique_id:      i64,
    permission_level:      i32,
    requested_permissions: u16,
}

Update_Adventure_Settings :: struct {
    no_pvm:          bool,
    no_mvp:          bool,
    immutable_world: bool,
    show_name_tags:  bool,
    auto_jump:       bool,
}

Update_Client_Input_Locks :: struct {
    locks: u32,
}

Update_Client_Options :: struct {
    graphics_mode:    protocol.Optional(u8),
    filter_profanity: protocol.Optional(bool),
}

Actor_Event :: struct {
    entity_runtime_id: u64,
    event_type:        u8,
    event_data:        i32,
    fire_at_position:  protocol.Optional(protocol.Vec3),
}

Agent_Action :: struct {
    identifier: string,
    action:     i32,
    response:   []u8,
}

Block_Event :: struct {
    position:   protocol.Block_Pos,
    event_type: i32,
    event_data: i32,
}

Camera_Shake :: struct {
    intensity: f32,
    duration:  f32,
    type:      u8,
    action:    u8,
}

Code_Builder_Source :: struct {
    operation:   u8,
    category:    u8,
    code_status: u8,
}

Emote :: struct {
    entity_runtime_id: u64,
    emote_length:      u32,
    emote_id:          string,
    xuid:              string,
    platform_id:       string,
    flags:             u8,
}

Game_Test_Request :: struct {
    name:                string,
    rotation:            u8,
    repetitions:         i32,
    position:            protocol.Block_Pos,
    stop_on_error:       bool,
    tests_per_row:       i32,
    max_tests_per_batch: i32,
}

Lab_Table :: struct {
    action_type:   u8,
    position:      protocol.Block_Pos,
    reaction_type: u8,
}

Lectern_Update :: struct {
    page:       u8,
    page_count: u8,
    position:   protocol.Block_Pos,
}

NPC_Request :: struct {
    entity_runtime_id: u64,
    request_type:      u8,
    command_string:    string,
    action_type:       u8,
    scene_name:        string,
}

Player_Action :: struct {
    entity_runtime_id: u64,
    action_type:       i32,
    block_position:    protocol.Block_Pos,
    result_position:   protocol.Block_Pos,
    block_face:        i32,
}

Spawn_Particle_Effect :: struct {
    dimension:       u8,
    entity_unique_id: i64,
    position:        protocol.Vec3,
    particle_name:   string,
    molang_variables: protocol.Optional([]u8),
}

Client_Cache_Blob_Status :: struct {
    miss_hashes: []u64,
    hit_hashes:  []u64,
}

Client_Bound_Data_Driven_UI_Show_Screen :: struct {
    screen_id:        string,
    form_id:          u32,
    data_instance_id: protocol.Optional(u32),
}

Sub_Client_Login :: struct {
    connection_request: []u8,
}

Script_Custom_Event :: struct {
    event_name: string,
    event_data: []u8,
}

Emote_List :: struct {
    player_runtime_id: u64,
    emote_pieces:      []protocol.UUID,
}

Send_Party_Destination_Cookie :: struct {
    cookie:           string,
    intent:           string,
    destination_name: string,
}

Player_Toggle_Crafter_Slot_Request :: struct {
    pos_x:    i32,
    pos_y:    i32,
    pos_z:    i32,
    slot:     u8,
    disabled: bool,
}

Client_Camera_Aim_Assist :: struct {
    preset_id:       string,
    action:          u8,
    allow_aim_assist: bool,
}

Server_Bound_Data_Driven_Screen_Closed :: struct {
    form_id:      u32,
    close_reason: string,
}

Position_Tracking_DB_Client_Request :: struct {
    request_action: u8,
    tracking_id:    i32,
}

Party_Info :: struct {
    party_id:     string,
    party_leader: bool,
}

Party_Changed :: struct {
    party_info: protocol.Optional(Party_Info),
}

Player_Video_Capture_Action_Stop  :: u8(0)
Player_Video_Capture_Action_Start :: u8(1)

Player_Location_Type_Coordinates :: i32(0)
Player_Location_Type_Hide        :: i32(1)

Control_Scheme_Locked_Player_Relative_Strafe :: u8(0)
Control_Scheme_Camera_Relative                :: u8(1)
Control_Scheme_Camera_Relative_Strafe         :: u8(2)
Control_Scheme_Player_Relative                :: u8(3)
Control_Scheme_Player_Relative_Strafe         :: u8(4)

Movement_Effect_Type_Glide_Boost   :: i32(0)
Movement_Effect_Type_Dolphin_Boost :: i32(1)
Movement_Effect_Type_Geyser_Boost  :: i32(2)

Texture_Shift_Action_Invalid     :: u8(0)
Texture_Shift_Action_Initialize  :: u8(1)
Texture_Shift_Action_Start       :: u8(2)
Texture_Shift_Action_Set_Enabled :: u8(3)
Texture_Shift_Action_Sync        :: u8(4)

Hud_Element_Paper_Doll     :: i32(0)
Hud_Element_Armour         :: i32(1)
Hud_Element_Tool_Tips      :: i32(2)
Hud_Element_Touch_Controls :: i32(3)
Hud_Element_Crosshair      :: i32(4)
Hud_Element_Hot_Bar        :: i32(5)
Hud_Element_Health         :: i32(6)
Hud_Element_Progress_Bar   :: i32(7)
Hud_Element_Hunger         :: i32(8)
Hud_Element_Air_Bubbles    :: i32(9)
Hud_Element_Horse_Health   :: i32(10)
Hud_Element_Status_Effects :: i32(11)
Hud_Element_Item_Text      :: i32(12)

Hud_Visibility_Hide  :: i32(0)
Hud_Visibility_Reset :: i32(1)

Inventory_Layout_None             :: i32(0)
Inventory_Layout_Inventory_Only   :: i32(1)
Inventory_Layout_Default          :: i32(2)
Inventory_Layout_Recipe_Book_Only :: i32(3)

Inventory_Left_Tab_None         :: i32(0)
Inventory_Left_Tab_Construction :: i32(1)
Inventory_Left_Tab_Equipment    :: i32(2)
Inventory_Left_Tab_Items        :: i32(3)
Inventory_Left_Tab_Nature       :: i32(4)
Inventory_Left_Tab_Search       :: i32(5)
Inventory_Left_Tab_Survival     :: i32(6)

Inventory_Right_Tab_None        :: i32(0)
Inventory_Right_Tab_Full_Screen :: i32(1)
Inventory_Right_Tab_Crafting    :: i32(2)
Inventory_Right_Tab_Armour      :: i32(3)

Player_Update_Entity_Overrides_Type_Clear_All :: u8(0)
Player_Update_Entity_Overrides_Type_Remove    :: u8(1)
Player_Update_Entity_Overrides_Type_Int       :: u8(2)
Player_Update_Entity_Overrides_Type_Float     :: u8(3)

Set_Hud :: struct {
    elements:   []i32,
    visibility: i32,
}

Set_Player_Inventory_Options :: struct {
    left_inventory_tab:  i32,
    right_inventory_tab: i32,
    filtering:           bool,
    inventory_layout:    i32,
    crafting_layout:     i32,
}

Player_Update_Entity_Overrides :: struct {
    entity_unique_id: i64,
    property_index:   u32,
    type:             u8,
    int_value:        i32,
    float_value:      f32,
}

Camera_Aim_Assist_Action_Set   :: u8(0)
Camera_Aim_Assist_Action_Clear :: u8(1)

Camera_Aim_Assist :: struct {
    preset:            string,
    angle:             protocol.Vec2,
    distance:          f32,
    target_mode:       u8,
    action:            u8,
    show_debug_render: bool,
}

Change_Mob_Property :: struct {
    entity_unique_id: i64,
    property:         string,
    bool_value:       bool,
    string_value:     string,
    int_value:        i32,
    float_value:      f32,
}

Mob_Effect :: struct {
    entity_runtime_id: u64,
    operation:         u8,
    effect_type:       i32,
    amplifier:         i32,
    particles:         bool,
    duration:          i32,
    tick:              u64,
    ambient:           bool,
}

Interact_Action_Leave_Vehicle    :: u8(3)
Interact_Action_Mouse_Over_Entity :: u8(4)
Interact_Action_NPC_Open         :: u8(5)
Interact_Action_Open_Inventory   :: u8(6)

Move_Flag_On_Ground        :: u8(1 << 0)
Move_Flag_Teleport         :: u8(1 << 1)
Move_Flag_Force_Move       :: u8(1 << 2)
Move_Flag_Force_Completion :: u8(1 << 3)

Move_Actor_Delta_Flag_Has_X     :: u16(1 << 0)
Move_Actor_Delta_Flag_Has_Y     :: u16(1 << 1)
Move_Actor_Delta_Flag_Has_Z     :: u16(1 << 2)
Move_Actor_Delta_Flag_Has_Rot_X :: u16(1 << 3)
Move_Actor_Delta_Flag_Has_Rot_Y :: u16(1 << 4)
Move_Actor_Delta_Flag_Has_Rot_Z :: u16(1 << 5)
Move_Actor_Delta_Flag_On_Ground :: u16(1 << 6)
Move_Actor_Delta_Flag_Teleport  :: u16(1 << 7)
Move_Actor_Delta_Flag_Force_Move :: u16(1 << 8)

Play_Sound :: struct {
    sound_name: string,
    position:   protocol.Vec3,
    volume:     f32,
    pitch:      f32,
    handle:     protocol.Optional(u64),
}

Interact :: struct {
    action_type:              u8,
    target_entity_runtime_id: u64,
    position:                 protocol.Optional(protocol.Vec3),
}

Move_Actor_Absolute :: struct {
    entity_runtime_id: u64,
    flags:             u8,
    position:          protocol.Vec3,
    rotation:          protocol.Vec3,
}

Move_Actor_Delta :: struct {
    flags:             u16,
    entity_runtime_id: u64,
    position:          protocol.Vec3,
    rotation:          protocol.Vec3,
}

Container_Open :: struct {
    window_id:                  u8,
    container_type:             u8,
    container_position:         protocol.Block_Pos,
    container_entity_unique_id: i64,
}

Network_Chunk_Publisher_Update :: struct {
    position:     protocol.Block_Pos,
    radius:       u32,
    saved_chunks: []protocol.Chunk_Pos,
}

Animate_Action_Swing_Arm          :: u8(1)
Animate_Action_Stop_Sleep         :: u8(3)
Animate_Action_Critical_Hit       :: u8(4)
Animate_Action_Magic_Critical_Hit :: u8(5)

Animate_Swing_Source_None      :: u8(1)
Animate_Swing_Source_Build     :: u8(2)
Animate_Swing_Source_Mine      :: u8(3)
Animate_Swing_Source_Interact  :: u8(4)
Animate_Swing_Source_Attack    :: u8(5)
Animate_Swing_Source_Use_Item  :: u8(6)
Animate_Swing_Source_Throw_Item :: u8(7)
Animate_Swing_Source_Drop_Item :: u8(8)
Animate_Swing_Source_Event     :: u8(9)

Add_Painting :: struct {
    entity_unique_id:  i64,
    entity_runtime_id: u64,
    position:          protocol.Vec3,
    direction:         i32,
    title:             string,
}

Animate :: struct {
    action_type:       u8,
    entity_runtime_id: u64,
    data:              f32,
    swing_source:      u8,
}

Set_Actor_Link :: struct {
    entity_link: protocol.Entity_Link,
}

Map_Info_Request :: struct {
    map_id:        i64,
    client_pixels: []protocol.Pixel_Request,
}

Player_Armour_Damage :: struct {
    list: []protocol.Player_Armour_Damage_Entry,
}

Photo_Type_Portfolio  :: u8(0)
Photo_Type_Photo_Item :: u8(1)
Photo_Type_Book       :: u8(2)

Scoreboard_Sort_Order_Ascending  :: i32(0)
Scoreboard_Sort_Order_Descending :: i32(1)

Scoreboard_Slot_List       :: "list"
Scoreboard_Slot_Sidebar    :: "sidebar"
Scoreboard_Slot_Below_Name :: "belowname"

Level_Event :: struct {
    event_type: i32,
    position:   protocol.Vec3,
    event_data: i32,
}

Photo_Transfer :: struct {
    photo_name:             string,
    photo_data:             []u8,
    book_id:                string,
    photo_type:             u8,
    source_type:            u8,
    owner_entity_unique_id: i64,
    new_photo_name:         string,
}

Set_Display_Objective :: struct {
    display_slot:   string,
    objective_name: string,
    display_name:   string,
    criteria_name:  string,
    sort_order:     i32,
}

Level_Sound_Event :: struct {
    sound_type:              string,
    position:                protocol.Vec3,
    extra_data:              i32,
    entity_type:             string,
    baby_mob:                bool,
    disable_relative_volume: bool,
    entity_unique_id:        i64,
    fire_at_position:        protocol.Optional(protocol.Vec3),
}

Animate_Entity :: struct {
    animation:              string,
    next_state:             string,
    stop_condition:         string,
    stop_condition_version: i32,
    controller:             string,
    blend_out_time:         f32,
    entity_runtime_ids:     []u64,
}

Scoreboard_Action_Modify :: u8(0)
Scoreboard_Action_Remove :: u8(1)

Scoreboard_Identity_Action_Register :: u8(0)
Scoreboard_Identity_Action_Clear    :: u8(1)

Set_Score :: struct {
    action_type: u8,
    entries:     []protocol.Scoreboard_Entry,
}

Set_Scoreboard_Identity :: struct {
    action_type: u8,
    entries:     []protocol.Scoreboard_Identity_Entry,
}

Block_Update_Neighbours :: u32(1 << 0)
Block_Update_Network    :: u32(1 << 1)
Block_Update_No_Graphics :: u32(1 << 2)
Block_Update_Priority   :: u32(1 << 3)

Block_To_Entity_Transition :: u64(1)
Entity_To_Block_Transition :: u64(2)

Book_Action_Replace_Page :: u32(0)
Book_Action_Add_Page     :: u32(1)
Book_Action_Delete_Page  :: u32(2)
Book_Action_Swap_Pages   :: u32(3)
Book_Action_Sign         :: u32(4)

Soft_Enum_Action_Add    :: u8(0)
Soft_Enum_Action_Remove :: u8(1)
Soft_Enum_Action_Set    :: u8(2)

Update_Block :: struct {
    position:             protocol.Block_Pos,
    new_block_runtime_id: u32,
    flags:                u32,
    layer:                u32,
}

Update_Block_Synced :: struct {
    position:             protocol.Block_Pos,
    new_block_runtime_id: u32,
    flags:                u32,
    layer:                u32,
    entity_unique_id:     u64,
    transition_type:      u64,
}

Adventure_Settings :: struct {
    flags:                    u32,
    command_permission_level: u32,
    action_permissions:       u32,
    permission_level:         u32,
    custom_stored_permissions: u32,
    player_unique_id:         i64,
}

Book_Edit :: struct {
    inventory_slot:        i32,
    action_type:           u32,
    page_number:           i32,
    secondary_page_number: i32,
    text:                  string,
    photo_name:            string,
    title:                 string,
    author:                string,
    xuid:                  string,
}

Boss_Event :: struct {
    boss_entity_unique_id:   i64,
    player_unique_id:        i64,
    event_type:              u8,
    boss_bar_title:          string,
    filtered_boss_bar_title: string,
    health_percentage:       f32,
    colour:                  u8,
    overlay:                 u8,
}

Update_Soft_Enum :: struct {
    enum_type:   string,
    options:     []string,
    action_type: u8,
}

Unlocked_Recipes_Type_Empty              :: u32(0)
Unlocked_Recipes_Type_Initially_Unlocked :: u32(1)
Unlocked_Recipes_Type_Newly_Unlocked     :: u32(2)
Unlocked_Recipes_Type_Remove_Unlocked    :: u32(3)
Unlocked_Recipes_Type_Remove_All_Unlocked :: u32(4)

Unlocked_Recipes :: struct {
    unlock_type: u32,
    recipes:     []string,
}

Trim_Data :: struct {
    patterns:  []protocol.Trim_Pattern,
    materials: []protocol.Trim_Material,
}

Feature_Registry :: struct {
    features: []protocol.Generation_Feature,
}

Dimension_Data :: struct {
    definitions: []protocol.Dimension_Definition,
}

Server_Store_Info :: struct {
    store_info: protocol.Optional(protocol.Store_Entry_Point_Info),
}

Server_Presence_Info :: struct {
    presence_info: protocol.Optional(protocol.Presence_Info),
}

Camera_Aim_Assist_Actor_Priority :: struct {
    priority_data: []protocol.Camera_Aim_Assist_Actor_Priority_Data,
}

animate_swing_source_string :: proc(source: u8) -> string {
    switch source {
    case Animate_Swing_Source_None:       return "none"
    case Animate_Swing_Source_Build:      return "build"
    case Animate_Swing_Source_Mine:       return "mine"
    case Animate_Swing_Source_Interact:   return "interact"
    case Animate_Swing_Source_Attack:     return "attack"
    case Animate_Swing_Source_Use_Item:   return "useitem"
    case Animate_Swing_Source_Throw_Item: return "throwitem"
    case Animate_Swing_Source_Drop_Item:  return "dropitem"
    case Animate_Swing_Source_Event:      return "event"
    case:                                 return "unknown"
    }
}

animate_swing_source_from_string :: proc(
    source: string,
) -> (value: u8, err: mcpe_runtime.Error) {
    switch source {
    case "none":      value = Animate_Swing_Source_None
    case "build":     value = Animate_Swing_Source_Build
    case "mine":      value = Animate_Swing_Source_Mine
    case "interact":  value = Animate_Swing_Source_Interact
    case "attack":    value = Animate_Swing_Source_Attack
    case "useitem":   value = Animate_Swing_Source_Use_Item
    case "throwitem": value = Animate_Swing_Source_Throw_Item
    case "dropitem":  value = Animate_Swing_Source_Drop_Item
    case "event":     value = Animate_Swing_Source_Event
    case:
        err = packet_error(
            .Malformed,
            "gophertunnel.packet.animate_swing_source",
            "unknown swing source",
        )
    }
    return
}

Party_Destination_Cookie_Response :: struct {
    cookie:   string,
    accepted: bool,
}

Client_Bound_Control_Scheme_Set :: struct {
    control_scheme: u8,
}

Movement_Effect :: struct {
    entity_runtime_id: u64,
    type:              i32,
    duration:          i32,
    tick:              u64,
}

Player_Video_Capture :: struct {
    action:      u8,
    frame_rate:  i32,
    file_prefix: string,
}

Player_Location :: struct {
    type:             i32,
    entity_unique_id: i64,
    position:         protocol.Vec3,
}

Client_Bound_Texture_Shift :: struct {
    action_id:            u8,
    collection_name:      string,
    from_step:            string,
    to_step:              string,
    all_steps:            []string,
    current_length_ticks: u64,
    total_length_ticks:   u64,
    enabled:              bool,
}

destroy_client_bound_texture_shift :: proc(
    packet: Client_Bound_Texture_Shift,
    allocator := context.allocator,
) {
    delete(packet.collection_name, allocator)
    delete(packet.from_step, allocator)
    delete(packet.to_step, allocator)
    destroy_string_slice(packet.all_steps, allocator)
}

read_client_bound_texture_shift :: proc(
    input: ^protocol.Reader,
) -> (
    packet: Client_Bound_Texture_Shift,
    err: mcpe_runtime.Error,
) {
    packet.action_id = protocol.read_u8(input) or_return
    packet.collection_name = protocol.read_string(input) or_return
    packet.from_step, err = protocol.read_string(input)
    if err != nil {
        destroy_client_bound_texture_shift(packet, input.allocator)
        packet = {}
        return
    }
    packet.to_step, err = protocol.read_string(input)
    if err != nil {
        destroy_client_bound_texture_shift(packet, input.allocator)
        packet = {}
        return
    }
    packet.all_steps, err = read_string_slice(input)
    if err != nil {
        destroy_client_bound_texture_shift(packet, input.allocator)
        packet = {}
        return
    }
    packet.current_length_ticks, err = protocol.read_varuint64(input)
    if err != nil {
        destroy_client_bound_texture_shift(packet, input.allocator)
        packet = {}
        return
    }
    packet.total_length_ticks, err = protocol.read_varuint64(input)
    if err != nil {
        destroy_client_bound_texture_shift(packet, input.allocator)
        packet = {}
        return
    }
    packet.enabled, err = protocol.read_bool(input)
    if err != nil {
        destroy_client_bound_texture_shift(packet, input.allocator)
        packet = {}
    }
    return
}

write_varint32_slice :: proc(
    output: ^protocol.Writer,
    values: []i32,
) -> mcpe_runtime.Error {
    if len(values) > protocol.MAX_COLLECTION_ELEMENTS {
        return packet_error(
            .Limit_Exceeded,
            "gophertunnel.packet.write_varint32_slice",
            "int32 list exceeds entry limit",
        )
    }
    protocol.write_varuint32(output, u32(len(values)))
    for value in values {
        protocol.write_varint32(output, value)
    }
    return nil
}

read_varint32_slice :: proc(
    input: ^protocol.Reader,
) -> (values: []i32, err: mcpe_runtime.Error) {
    count := protocol.read_varuint32(input) or_return
    if count > protocol.MAX_COLLECTION_ELEMENTS {
        return nil, packet_error(
            .Limit_Exceeded,
            "gophertunnel.packet.read_varint32_slice",
            "int32 list exceeds entry limit",
        )
    }
    values = make([]i32, int(count), input.allocator)
    for &value in values {
        value, err = protocol.read_varint32(input)
        if err != nil {
            delete(values, input.allocator)
            values = nil
            return
        }
    }
    return
}

write_chunk_pos_slice_u32 :: proc(
    output: ^protocol.Writer,
    values: []protocol.Chunk_Pos,
) -> mcpe_runtime.Error {
    if len(values) > protocol.MAX_COLLECTION_ELEMENTS {
        return packet_error(
            .Limit_Exceeded,
            "gophertunnel.packet.write_chunk_pos_slice_u32",
            "chunk position list exceeds entry limit",
        )
    }
    protocol.write_u32(output, u32(len(values)))
    for value in values {
        protocol.write_chunk_pos(output, value)
    }
    return nil
}

read_chunk_pos_slice_u32 :: proc(
    input: ^protocol.Reader,
) -> (values: []protocol.Chunk_Pos, err: mcpe_runtime.Error) {
    count := protocol.read_u32(input) or_return
    if count > protocol.MAX_COLLECTION_ELEMENTS {
        return nil, packet_error(
            .Limit_Exceeded,
            "gophertunnel.packet.read_chunk_pos_slice_u32",
            "chunk position list exceeds entry limit",
        )
    }
    values = make([]protocol.Chunk_Pos, int(count), input.allocator)
    for &value in values {
        value, err = protocol.read_chunk_pos(input)
        if err != nil {
            delete(values, input.allocator)
            values = nil
            return
        }
    }
    return
}

write_pixel_request_slice_u32 :: proc(
    output: ^protocol.Writer,
    values: []protocol.Pixel_Request,
) -> mcpe_runtime.Error {
    if len(values) > protocol.MAX_COLLECTION_ELEMENTS {
        return packet_error(
            .Limit_Exceeded,
            "gophertunnel.packet.write_pixel_request_slice_u32",
            "pixel request list exceeds entry limit",
        )
    }
    protocol.write_u32(output, u32(len(values)))
    for value in values {
        protocol.write_pixel_request(output, value)
    }
    return nil
}

read_pixel_request_slice_u32 :: proc(
    input: ^protocol.Reader,
) -> (values: []protocol.Pixel_Request, err: mcpe_runtime.Error) {
    count := protocol.read_u32(input) or_return
    if count > protocol.MAX_COLLECTION_ELEMENTS {
        return nil, packet_error(
            .Limit_Exceeded,
            "gophertunnel.packet.read_pixel_request_slice_u32",
            "pixel request list exceeds entry limit",
        )
    }
    values = make([]protocol.Pixel_Request, int(count), input.allocator)
    for &value in values {
        value, err = protocol.read_pixel_request(input)
        if err != nil {
            delete(values, input.allocator)
            values = nil
            return
        }
    }
    return
}

write_armour_damage_slice :: proc(
    output: ^protocol.Writer,
    values: []protocol.Player_Armour_Damage_Entry,
) -> mcpe_runtime.Error {
    if len(values) > protocol.MAX_COLLECTION_ELEMENTS {
        return packet_error(
            .Limit_Exceeded,
            "gophertunnel.packet.write_armour_damage_slice",
            "armour damage list exceeds entry limit",
        )
    }
    protocol.write_varuint32(output, u32(len(values)))
    for value in values {
        protocol.write_player_armour_damage_entry(output, value)
    }
    return nil
}

read_armour_damage_slice :: proc(
    input: ^protocol.Reader,
) -> (
    values: []protocol.Player_Armour_Damage_Entry,
    err: mcpe_runtime.Error,
) {
    count := protocol.read_varuint32(input) or_return
    if count > protocol.MAX_COLLECTION_ELEMENTS {
        return nil, packet_error(
            .Limit_Exceeded,
            "gophertunnel.packet.read_armour_damage_slice",
            "armour damage list exceeds entry limit",
        )
    }
    values = make(
        []protocol.Player_Armour_Damage_Entry,
        int(count),
        input.allocator,
    )
    for &value in values {
        value, err = protocol.read_player_armour_damage_entry(input)
        if err != nil {
            delete(values, input.allocator)
            values = nil
            return
        }
    }
    return
}

write_varuint64_slice :: proc(
    output: ^protocol.Writer,
    values: []u64,
) -> mcpe_runtime.Error {
    if len(values) > protocol.MAX_COLLECTION_ELEMENTS {
        return packet_error(
            .Limit_Exceeded,
            "gophertunnel.packet.write_varuint64_slice",
            "varuint64 list exceeds entry limit",
        )
    }
    protocol.write_varuint32(output, u32(len(values)))
    for value in values {
        protocol.write_varuint64(output, value)
    }
    return nil
}

read_varuint64_slice :: proc(
    input: ^protocol.Reader,
) -> (values: []u64, err: mcpe_runtime.Error) {
    count := protocol.read_varuint32(input) or_return
    if count > protocol.MAX_COLLECTION_ELEMENTS {
        return nil, packet_error(
            .Limit_Exceeded,
            "gophertunnel.packet.read_varuint64_slice",
            "varuint64 list exceeds entry limit",
        )
    }
    values = make([]u64, int(count), input.allocator)
    for &value in values {
        value, err = protocol.read_varuint64(input)
        if err != nil {
            delete(values, input.allocator)
            values = nil
            return
        }
    }
    return
}

destroy_scoreboard_entries :: proc(
    values: []protocol.Scoreboard_Entry,
    allocator := context.allocator,
) {
    for value in values {
        delete(value.objective_name, allocator)
        delete(value.display_name, allocator)
    }
    delete(values, allocator)
}

write_scoreboard_entries :: proc(
    output: ^protocol.Writer,
    values: []protocol.Scoreboard_Entry,
    modify: bool,
) -> mcpe_runtime.Error {
    if len(values) > protocol.MAX_COLLECTION_ELEMENTS {
        return packet_error(
            .Limit_Exceeded,
            "gophertunnel.packet.write_scoreboard_entries",
            "scoreboard entry list exceeds entry limit",
        )
    }
    protocol.write_varuint32(output, u32(len(values)))
    for value in values {
        if modify {
            protocol.write_scoreboard_entry(output, value) or_return
        } else {
            protocol.write_score_remove_entry(output, value)
        }
    }
    return nil
}

read_scoreboard_entries :: proc(
    input: ^protocol.Reader,
    modify: bool,
) -> (
    values: []protocol.Scoreboard_Entry,
    err: mcpe_runtime.Error,
) {
    count := protocol.read_varuint32(input) or_return
    if count > protocol.MAX_COLLECTION_ELEMENTS {
        return nil, packet_error(
            .Limit_Exceeded,
            "gophertunnel.packet.read_scoreboard_entries",
            "scoreboard entry list exceeds entry limit",
        )
    }
    values = make(
        []protocol.Scoreboard_Entry,
        int(count),
        input.allocator,
    )
    for &value, index in values {
        if modify {
            value, err = protocol.read_scoreboard_entry(input)
        } else {
            value, err = protocol.read_score_remove_entry(input)
        }
        if err != nil {
            for previous in values[:index] {
                delete(previous.objective_name, input.allocator)
                delete(previous.display_name, input.allocator)
            }
            delete(values, input.allocator)
            values = nil
            return
        }
    }
    return
}

write_scoreboard_identity_entries :: proc(
    output: ^protocol.Writer,
    values: []protocol.Scoreboard_Identity_Entry,
    register: bool,
) -> mcpe_runtime.Error {
    if len(values) > protocol.MAX_COLLECTION_ELEMENTS {
        return packet_error(
            .Limit_Exceeded,
            "gophertunnel.packet.write_scoreboard_identity_entries",
            "scoreboard identity list exceeds entry limit",
        )
    }
    protocol.write_varuint32(output, u32(len(values)))
    for value in values {
        protocol.write_varint64(output, value.entry_id)
        if register {
            protocol.write_varint64(output, value.entity_unique_id)
        }
    }
    return nil
}

read_scoreboard_identity_entries :: proc(
    input: ^protocol.Reader,
    register: bool,
) -> (
    values: []protocol.Scoreboard_Identity_Entry,
    err: mcpe_runtime.Error,
) {
    count := protocol.read_varuint32(input) or_return
    if count > protocol.MAX_COLLECTION_ELEMENTS {
        return nil, packet_error(
            .Limit_Exceeded,
            "gophertunnel.packet.read_scoreboard_identity_entries",
            "scoreboard identity list exceeds entry limit",
        )
    }
    values = make(
        []protocol.Scoreboard_Identity_Entry,
        int(count),
        input.allocator,
    )
    for &value in values {
        value.entry_id, err = protocol.read_varint64(input)
        if err == nil && register {
            value.entity_unique_id, err =
                protocol.read_varint64(input)
        }
        if err != nil {
            delete(values, input.allocator)
            values = nil
            return
        }
    }
    return
}

write_trim_patterns :: proc(
    output: ^protocol.Writer,
    values: []protocol.Trim_Pattern,
) -> mcpe_runtime.Error {
    if len(values) > protocol.MAX_COLLECTION_ELEMENTS {
        return packet_error(.Limit_Exceeded, "gophertunnel.packet.write_trim_patterns", "trim pattern list exceeds entry limit")
    }
    protocol.write_varuint32(output, u32(len(values)))
    for value in values {
        protocol.write_trim_pattern(output, value)
    }
    return nil
}

read_trim_patterns :: proc(input: ^protocol.Reader) -> (
    values: []protocol.Trim_Pattern,
    err: mcpe_runtime.Error,
) {
    count := protocol.read_varuint32(input) or_return
    if count > protocol.MAX_COLLECTION_ELEMENTS {
        return nil, packet_error(.Limit_Exceeded, "gophertunnel.packet.read_trim_patterns", "trim pattern list exceeds entry limit")
    }
    values = make([]protocol.Trim_Pattern, int(count), input.allocator)
    for &value, index in values {
        value, err = protocol.read_trim_pattern(input)
        if err != nil {
            for previous in values[:index] {
                delete(previous.item_name, input.allocator)
                delete(previous.pattern_id, input.allocator)
            }
            delete(values, input.allocator)
            values = nil
            return
        }
    }
    return
}

write_trim_materials :: proc(
    output: ^protocol.Writer,
    values: []protocol.Trim_Material,
) -> mcpe_runtime.Error {
    if len(values) > protocol.MAX_COLLECTION_ELEMENTS {
        return packet_error(.Limit_Exceeded, "gophertunnel.packet.write_trim_materials", "trim material list exceeds entry limit")
    }
    protocol.write_varuint32(output, u32(len(values)))
    for value in values {
        protocol.write_trim_material(output, value)
    }
    return nil
}

read_trim_materials :: proc(input: ^protocol.Reader) -> (
    values: []protocol.Trim_Material,
    err: mcpe_runtime.Error,
) {
    count := protocol.read_varuint32(input) or_return
    if count > protocol.MAX_COLLECTION_ELEMENTS {
        return nil, packet_error(.Limit_Exceeded, "gophertunnel.packet.read_trim_materials", "trim material list exceeds entry limit")
    }
    values = make([]protocol.Trim_Material, int(count), input.allocator)
    for &value, index in values {
        value, err = protocol.read_trim_material(input)
        if err != nil {
            for previous in values[:index] {
                delete(previous.material_id, input.allocator)
                delete(previous.colour, input.allocator)
                delete(previous.item_name, input.allocator)
            }
            delete(values, input.allocator)
            values = nil
            return
        }
    }
    return
}

write_generation_features :: proc(
    output: ^protocol.Writer,
    values: []protocol.Generation_Feature,
) -> mcpe_runtime.Error {
    if len(values) > protocol.MAX_COLLECTION_ELEMENTS {
        return packet_error(.Limit_Exceeded, "gophertunnel.packet.write_generation_features", "generation feature list exceeds entry limit")
    }
    protocol.write_varuint32(output, u32(len(values)))
    for value in values {
        protocol.write_generation_feature(output, value)
    }
    return nil
}

read_generation_features :: proc(input: ^protocol.Reader) -> (
    values: []protocol.Generation_Feature,
    err: mcpe_runtime.Error,
) {
    count := protocol.read_varuint32(input) or_return
    if count > protocol.MAX_COLLECTION_ELEMENTS {
        return nil, packet_error(.Limit_Exceeded, "gophertunnel.packet.read_generation_features", "generation feature list exceeds entry limit")
    }
    values = make([]protocol.Generation_Feature, int(count), input.allocator)
    for &value, index in values {
        value, err = protocol.read_generation_feature(input)
        if err != nil {
            for previous in values[:index] {
                delete(previous.name, input.allocator)
                delete(previous.json, input.allocator)
            }
            delete(values, input.allocator)
            values = nil
            return
        }
    }
    return
}

write_dimension_definitions :: proc(
    output: ^protocol.Writer,
    values: []protocol.Dimension_Definition,
) -> mcpe_runtime.Error {
    if len(values) > protocol.MAX_COLLECTION_ELEMENTS {
        return packet_error(.Limit_Exceeded, "gophertunnel.packet.write_dimension_definitions", "dimension definition list exceeds entry limit")
    }
    protocol.write_varuint32(output, u32(len(values)))
    for value in values {
        protocol.write_dimension_definition(output, value)
    }
    return nil
}

read_dimension_definitions :: proc(input: ^protocol.Reader) -> (
    values: []protocol.Dimension_Definition,
    err: mcpe_runtime.Error,
) {
    count := protocol.read_varuint32(input) or_return
    if count > protocol.MAX_COLLECTION_ELEMENTS {
        return nil, packet_error(.Limit_Exceeded, "gophertunnel.packet.read_dimension_definitions", "dimension definition list exceeds entry limit")
    }
    values = make([]protocol.Dimension_Definition, int(count), input.allocator)
    for &value, index in values {
        value, err = protocol.read_dimension_definition(input)
        if err != nil {
            for previous in values[:index] {
                delete(previous.name, input.allocator)
            }
            delete(values, input.allocator)
            values = nil
            return
        }
    }
    return
}

write_aim_assist_priorities :: proc(
    output: ^protocol.Writer,
    values: []protocol.Camera_Aim_Assist_Actor_Priority_Data,
) -> mcpe_runtime.Error {
    if len(values) > protocol.MAX_COLLECTION_ELEMENTS {
        return packet_error(
            .Limit_Exceeded,
            "gophertunnel.packet.write_aim_assist_priorities",
            "aim assist priority list exceeds entry limit",
        )
    }
    protocol.write_varuint32(output, u32(len(values)))
    for value in values {
        protocol.write_camera_aim_assist_actor_priority_data(
            output,
            value,
        )
    }
    return nil
}

read_aim_assist_priorities :: proc(
    input: ^protocol.Reader,
) -> (
    values: []protocol.Camera_Aim_Assist_Actor_Priority_Data,
    err: mcpe_runtime.Error,
) {
    count := protocol.read_varuint32(input) or_return
    if count > protocol.MAX_COLLECTION_ELEMENTS {
        return nil, packet_error(
            .Limit_Exceeded,
            "gophertunnel.packet.read_aim_assist_priorities",
            "aim assist priority list exceeds entry limit",
        )
    }
    values = make(
        []protocol.Camera_Aim_Assist_Actor_Priority_Data,
        int(count),
        input.allocator,
    )
    for &value in values {
        value, err =
            protocol.read_camera_aim_assist_actor_priority_data(input)
        if err != nil {
            delete(values, input.allocator)
            values = nil
            return
        }
    }
    return
}

write_u64_slice :: proc(
    output: ^protocol.Writer,
    values: []u64,
) -> mcpe_runtime.Error {
    if len(values) > protocol.MAX_COLLECTION_ELEMENTS {
        return packet_error(
            .Limit_Exceeded,
            "gophertunnel.packet.write_u64_slice",
            "u64 list exceeds entry limit",
        )
    }
    protocol.write_varuint32(output, u32(len(values)))
    for value in values {
        protocol.write_u64(output, value)
    }
    return nil
}

read_u64_slice :: proc(
    input: ^protocol.Reader,
) -> (values: []u64, err: mcpe_runtime.Error) {
    count := protocol.read_varuint32(input) or_return
    if count > protocol.MAX_COLLECTION_ELEMENTS {
        return nil, packet_error(
            .Limit_Exceeded,
            "gophertunnel.packet.read_u64_slice",
            "u64 list exceeds entry limit",
        )
    }
    values = make([]u64, int(count), input.allocator)
    for &value in values {
        value, err = protocol.read_u64(input)
        if err != nil {
            delete(values, input.allocator)
            values = nil
            return
        }
    }
    return
}

write_uuid_slice :: proc(
    output: ^protocol.Writer,
    values: []protocol.UUID,
) -> mcpe_runtime.Error {
    if len(values) > protocol.MAX_COLLECTION_ELEMENTS {
        return packet_error(
            .Limit_Exceeded,
            "gophertunnel.packet.write_uuid_slice",
            "UUID list exceeds entry limit",
        )
    }
    protocol.write_varuint32(output, u32(len(values)))
    for value in values {
        protocol.write_uuid(output, value)
    }
    return nil
}

read_uuid_slice :: proc(
    input: ^protocol.Reader,
) -> (values: []protocol.UUID, err: mcpe_runtime.Error) {
    count := protocol.read_varuint32(input) or_return
    if count > protocol.MAX_COLLECTION_ELEMENTS {
        return nil, packet_error(
            .Limit_Exceeded,
            "gophertunnel.packet.read_uuid_slice",
            "UUID list exceeds entry limit",
        )
    }
    values = make([]protocol.UUID, int(count), input.allocator)
    for &value in values {
        value, err = protocol.read_uuid(input)
        if err != nil {
            delete(values, input.allocator)
            values = nil
            return
        }
    }
    return
}

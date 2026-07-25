package gt_packet

import protocol "mcpe:gophertunnel/minecraft/protocol"

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

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

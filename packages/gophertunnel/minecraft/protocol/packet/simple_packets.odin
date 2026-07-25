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

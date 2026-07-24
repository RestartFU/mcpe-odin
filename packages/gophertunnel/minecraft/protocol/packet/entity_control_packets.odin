package gt_packet

import protocol "mcpe:gophertunnel/minecraft/protocol"
import mcpe_runtime "mcpe:runtime"

Simulation_Type_Game    :: u8(0)
Simulation_Type_Editor  :: u8(1)
Simulation_Type_Test    :: u8(2)
Simulation_Type_Invalid :: u8(3)

Remove_Actor :: struct {
    entity_unique_id: i64,
}

Take_Item_Actor :: struct {
    item_entity_runtime_id:  u64,
    taker_entity_runtime_id: u64,
}

Block_Pick_Request :: struct {
    position:      protocol.Block_Pos,
    add_block_nbt: bool,
    hot_bar_slot:  u8,
}

Actor_Pick_Request :: struct {
    entity_unique_id: i64,
    hot_bar_slot:     u8,
    with_data:        bool,
}

Set_Actor_Motion :: struct {
    entity_runtime_id: u64,
    velocity:          protocol.Vec3,
    tick:              u64,
}

Modal_Form_Request :: struct {
    form_id:   u32,
    form_data: []u8,
}

Show_Profile :: struct {
    xuid: string,
}

Remove_Objective :: struct {
    objective_name: string,
}

Set_Local_Player_As_Initialised :: struct {
    entity_runtime_id: u64,
}

Update_Player_Game_Type :: struct {
    game_type:        i32,
    player_unique_id: i64,
    tick:             u64,
}

Filter_Text :: struct {
    text:        string,
    from_server: bool,
}

Simulation_Type :: struct {
    simulation_type: u8,
}

Toast_Request :: struct {
    title:   string,
    message: string,
}

Award_Achievement :: struct {
    achievement_id: i32,
}

Client_Bound_Close_Form :: struct {}

read_toast_request :: proc(
    input: ^protocol.Reader,
) -> (packet: Toast_Request, err: mcpe_runtime.Error) {
    packet.title = protocol.read_string(input) or_return
    packet.message, err = protocol.read_string(input)
    if err != nil {
        delete(packet.title, input.allocator)
        packet.title = ""
    }
    return
}

read_filter_text :: proc(
    input: ^protocol.Reader,
) -> (packet: Filter_Text, err: mcpe_runtime.Error) {
    packet.text = protocol.read_string(input) or_return
    packet.from_server, err = protocol.read_bool(input)
    if err != nil {
        delete(packet.text, input.allocator)
        packet.text = ""
    }
    return
}

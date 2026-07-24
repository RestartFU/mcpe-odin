package gt_packet

import protocol "mcpe:gophertunnel/minecraft/protocol"
import mcpe_runtime "mcpe:runtime"

Spawn_Type_Player :: i32(0)
Spawn_Type_World  :: i32(1)

Respawn_State_Searching_For_Spawn :: u8(0)
Respawn_State_Ready_To_Spawn      :: u8(1)
Respawn_State_Client_Ready_To_Spawn :: u8(2)

Game_Type_Survival            :: i32(0)
Game_Type_Creative            :: i32(1)
Game_Type_Adventure           :: i32(2)
Game_Type_Survival_Spectator  :: i32(3)
Game_Type_Creative_Spectator  :: i32(4)
Game_Type_Default             :: i32(5)
Game_Type_Spectator           :: i32(6)

Simple_Event_Commands_Enabled               :: u16(1)
Simple_Event_Commands_Disabled              :: u16(2)
Simple_Event_Unlock_World_Template_Settings :: u16(3)

Show_Credits_Status_Start :: i32(0)
Show_Credits_Status_End   :: i32(1)

Set_Spawn_Position :: struct {
    spawn_type:     i32,
    position:       protocol.Block_Pos,
    dimension:      i32,
    spawn_position: protocol.Block_Pos,
}

Respawn :: struct {
    position:          protocol.Vec3,
    state:             u8,
    entity_runtime_id: u64,
}

Player_Hot_Bar :: struct {
    selected_hot_bar_slot: u32,
    window_id:             u8,
    select_hot_bar_slot:   bool,
}

Set_Commands_Enabled :: struct {
    enabled: bool,
}

Set_Player_Game_Type :: struct {
    game_type: i32,
}

Simple_Event :: struct {
    event_type: u16,
}

Spawn_Experience_Orb :: struct {
    position:          protocol.Vec3,
    experience_amount: i32,
}

Show_Credits :: struct {
    player_runtime_id: u64,
    status_type:       i32,
}

Transfer :: struct {
    address:      string,
    port:         u16,
    reload_world: bool,
}

Stop_Sound :: struct {
    sound_name:        string,
    stop_all:          bool,
    stop_music_legacy: bool,
}

Set_Last_Hurt_By :: struct {
    entity_type: i32,
}

Set_Default_Game_Type :: struct {
    game_type: i32,
}

read_transfer :: proc(
    input: ^protocol.Reader,
) -> (packet: Transfer, err: mcpe_runtime.Error) {
    packet.address = protocol.read_string(input) or_return
    packet.port, err = protocol.read_u16(input)
    if err != nil {
        delete(packet.address, input.allocator)
        packet.address = ""
        return
    }
    packet.reload_world, err = protocol.read_bool(input)
    if err != nil {
        delete(packet.address, input.allocator)
        packet.address = ""
    }
    return
}

read_stop_sound :: proc(
    input: ^protocol.Reader,
) -> (packet: Stop_Sound, err: mcpe_runtime.Error) {
    packet.sound_name = protocol.read_string(input) or_return
    packet.stop_all, err = protocol.read_bool(input)
    if err != nil {
        delete(packet.sound_name, input.allocator)
        packet.sound_name = ""
        return
    }
    packet.stop_music_legacy, err = protocol.read_bool(input)
    if err != nil {
        delete(packet.sound_name, input.allocator)
        packet.sound_name = ""
    }
    return
}

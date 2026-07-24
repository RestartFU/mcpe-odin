package gt_packet

import "core:slice"
import "core:testing"
import mcpe_runtime "mcpe:runtime"

@(test)
header_round_trip_preserves_sub_clients :: proc(t: ^testing.T) {
    original: Packet = Request_Network_Settings{client_protocol = 1001}
    data, encode_err := encode_packet(original, 2, 3)
    testing.expect(t, encode_err == nil)
    if encode_err != nil {
        mcpe_runtime.destroy_error(encode_err)
        return
    }
    defer delete(data)
    decoded, header, decode_err := decode_packet(data)
    testing.expect(t, decode_err == nil)
    if decode_err != nil {
        mcpe_runtime.destroy_error(decode_err)
        return
    }
    defer destroy_packet(&decoded)
    testing.expect_value(t, header.packet_id, IDRequestNetworkSettings)
    testing.expect_value(t, header.sender_sub_client, u8(2))
    testing.expect_value(t, header.target_sub_client, u8(3))
    #partial switch packet in decoded {
    case Request_Network_Settings:
        testing.expect_value(t, packet.client_protocol, i32(1001))
    case:
        testing.expect(t, false, "unexpected packet type")
    }
}

@(test)
disconnect_hidden_screen_omits_messages :: proc(t: ^testing.T) {
    visible: Packet = Disconnect{
        reason = 57,
        message = "bye",
        filtered_message = "bye",
    }
    hidden: Packet = Disconnect{
        reason = 57,
        hide_disconnection_screen = true,
        message = "must not be encoded",
    }
    visible_data, visible_err := encode_packet(visible)
    hidden_data, hidden_err := encode_packet(hidden)
    testing.expect(t, visible_err == nil)
    testing.expect(t, hidden_err == nil)
    if visible_err != nil {
        mcpe_runtime.destroy_error(visible_err)
    }
    if hidden_err != nil {
        mcpe_runtime.destroy_error(hidden_err)
    }
    if visible_err == nil && hidden_err == nil {
        testing.expect(t, len(hidden_data) < len(visible_data))
    }
    delete(visible_data)
    delete(hidden_data)
}

@(test)
unknown_packets_preserve_raw_payload :: proc(t: ^testing.T) {
    original: Packet = Unknown_Packet{
        packet_id = 0x155,
        payload = []u8{1, 2, 3, 4},
    }
    data, encode_err := encode_packet(original)
    testing.expect(t, encode_err == nil)
    if encode_err != nil {
        mcpe_runtime.destroy_error(encode_err)
        return
    }
    defer delete(data)
    decoded, header, decode_err := decode_packet(data)
    testing.expect(t, decode_err == nil)
    if decode_err != nil {
        mcpe_runtime.destroy_error(decode_err)
        return
    }
    defer destroy_packet(&decoded)
    testing.expect_value(t, header.packet_id, u32(0x155))
    #partial switch packet in decoded {
    case Unknown_Packet:
        testing.expect(t, slice.equal(packet.payload, []u8{1, 2, 3, 4}))
    case:
        testing.expect(t, false, "unexpected packet type")
    }
}

@(test)
packet_header_width_is_validated :: proc(t: ^testing.T) {
    invalid_id: Packet = Unknown_Packet{packet_id = 0x400}
    _, id_err := encode_packet(invalid_id)
    testing.expect(t, id_err != nil)
    if id_err != nil {
        testing.expect_value(
            t,
            id_err.kind,
            mcpe_runtime.Error_Kind.Invalid_Argument,
        )
        mcpe_runtime.destroy_error(id_err)
    }

    valid: Packet = Set_Time{time = 1}
    _, client_err := encode_packet(valid, 4, 0)
    testing.expect(t, client_err != nil)
    if client_err != nil {
        testing.expect_value(
            t,
            client_err.kind,
            mcpe_runtime.Error_Kind.Invalid_Argument,
        )
        mcpe_runtime.destroy_error(client_err)
    }
}

@(test)
modeled_packets_reject_trailing_bytes :: proc(t: ^testing.T) {
    original: Packet = Set_Time{time = 42}
    data, encode_err := encode_packet(original)
    testing.expect(t, encode_err == nil)
    if encode_err != nil {
        mcpe_runtime.destroy_error(encode_err)
        return
    }
    defer delete(data)
    extended := make([]u8, len(data) + 1)
    defer delete(extended)
    copy(extended, data)
    extended[len(data)] = 0xff
    decoded, _, decode_err := decode_packet(extended)
    testing.expect(t, decoded == nil)
    testing.expect(t, decode_err != nil)
    if decode_err != nil {
        testing.expect_value(
            t,
            decode_err.kind,
            mcpe_runtime.Error_Kind.Malformed,
        )
        mcpe_runtime.destroy_error(decode_err)
    }
}

@(test)
game_state_packets_round_trip :: proc(t: ^testing.T) {
    packets := [?]Packet{
        Set_Spawn_Position{
            spawn_type = Spawn_Type_World,
            position = {-12, 64, 3456},
            dimension = 2,
            spawn_position = {-100, 70, 200},
        },
        Respawn{
            position = {1.25, -2.5, 9.75},
            state = Respawn_State_Client_Ready_To_Spawn,
            entity_runtime_id = 0x1234_5678,
        },
        Player_Hot_Bar{
            selected_hot_bar_slot = 7,
            window_id = 3,
            select_hot_bar_slot = true,
        },
        Set_Commands_Enabled{enabled = true},
        Set_Player_Game_Type{game_type = Game_Type_Spectator},
        Simple_Event{event_type = Simple_Event_Commands_Disabled},
        Spawn_Experience_Orb{
            position = {-1.5, 64.25, 100.75},
            experience_amount = 2477,
        },
        Show_Credits{
            player_runtime_id = 0x1020_3040,
            status_type = Show_Credits_Status_End,
        },
        Transfer{
            address = "example.org",
            port = 19132,
            reload_world = true,
        },
        Stop_Sound{
            sound_name = "music.game",
            stop_music_legacy = true,
        },
        Set_Last_Hurt_By{entity_type = -17},
        Set_Default_Game_Type{game_type = Game_Type_Creative},
    }
    ids := [?]u32{
        IDSetSpawnPosition,
        IDRespawn,
        IDPlayerHotBar,
        IDSetCommandsEnabled,
        IDSetPlayerGameType,
        IDSimpleEvent,
        IDSpawnExperienceOrb,
        IDShowCredits,
        IDTransfer,
        IDStopSound,
        IDSetLastHurtBy,
        IDSetDefaultGameType,
    }
    for original, index in packets {
        data, encode_err := encode_packet(original)
        testing.expect(t, encode_err == nil)
        if encode_err != nil {
            mcpe_runtime.destroy_error(encode_err)
            continue
        }
        decoded, header, decode_err := decode_packet(data)
        testing.expect(t, decode_err == nil)
        if decode_err != nil {
            mcpe_runtime.destroy_error(decode_err)
            delete(data)
            continue
        }
        testing.expect_value(t, header.packet_id, ids[index])
        reencoded, reencode_err := encode_packet(decoded)
        testing.expect(t, reencode_err == nil)
        if reencode_err == nil {
            testing.expect(t, slice.equal(data, reencoded))
            delete(reencoded)
        } else {
            mcpe_runtime.destroy_error(reencode_err)
        }
        destroy_packet(&decoded)
        delete(data)
    }
}

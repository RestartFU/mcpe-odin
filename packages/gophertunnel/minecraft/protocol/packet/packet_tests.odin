package gt_packet

import "core:slice"
import "core:testing"
import protocol "mcpe:gophertunnel/minecraft/protocol"
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

@(test)
dimension_packets_round_trip_optional_loading_screen_id :: proc(
    t: ^testing.T,
) {
    packets := [?]Packet{
        Change_Dimension{
            dimension = Dimension_Nether,
            position = {8.5, 72.25, -3.75},
            respawn = true,
            loading_screen_id = protocol.option(u32(0x1234_5678)),
        },
        Change_Dimension{
            dimension = Dimension_End,
            position = {0, 80, 0},
        },
        Server_Bound_Loading_Screen{
            type = Loading_Screen_Type_Start,
            loading_screen_id = protocol.option(u32(0x1234_5678)),
        },
        Server_Bound_Loading_Screen{
            type = Loading_Screen_Type_End,
        },
    }
    ids := [?]u32{
        IDChangeDimension,
        IDChangeDimension,
        IDServerBoundLoadingScreen,
        IDServerBoundLoadingScreen,
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

@(test)
entity_control_packets_round_trip :: proc(t: ^testing.T) {
    form_data := `{"type":"modal"}`
    packets := [?]Packet{
        Remove_Actor{entity_unique_id = -0x1020_3040},
        Take_Item_Actor{
            item_entity_runtime_id = 0x1020,
            taker_entity_runtime_id = 0x3040,
        },
        Block_Pick_Request{
            position = {-12, 64, 3456},
            add_block_nbt = true,
            hot_bar_slot = 7,
        },
        Actor_Pick_Request{
            entity_unique_id = -0x0102_0304_0506_0708,
            hot_bar_slot = 8,
            with_data = true,
        },
        Set_Actor_Motion{
            entity_runtime_id = 0x1020_3040,
            velocity = {1.25, -2.5, 9.75},
            tick = 123_456,
        },
        Modal_Form_Request{
            form_id = 42,
            form_data = transmute([]u8)form_data,
        },
        Show_Profile{xuid = "2533274790395904"},
        Remove_Objective{objective_name = "kills"},
        Set_Local_Player_As_Initialised{
            entity_runtime_id = 0x1234_5678,
        },
        Update_Player_Game_Type{
            game_type = Game_Type_Adventure,
            player_unique_id = -123_456,
            tick = 98_765,
        },
        Filter_Text{text = "hello", from_server = true},
        Simulation_Type{simulation_type = Simulation_Type_Test},
        Toast_Request{title = "Title", message = "Message"},
        Award_Achievement{achievement_id = -1234},
        Client_Bound_Close_Form{},
    }
    ids := [?]u32{
        IDRemoveActor,
        IDTakeItemActor,
        IDBlockPickRequest,
        IDActorPickRequest,
        IDSetActorMotion,
        IDModalFormRequest,
        IDShowProfile,
        IDRemoveObjective,
        IDSetLocalPlayerAsInitialised,
        IDUpdatePlayerGameType,
        IDFilterText,
        IDSimulationType,
        IDToastRequest,
        IDAwardAchievement,
        IDClientBoundCloseForm,
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

@(test)
owned_entity_control_fields_are_cleaned_on_truncation :: proc(
    t: ^testing.T,
) {
    packets := [?]Packet{
        Filter_Text{text = "hello", from_server = true},
        Toast_Request{title = "Title", message = "Message"},
    }
    for original in packets {
        data, encode_err := encode_packet(original)
        testing.expect(t, encode_err == nil)
        if encode_err != nil {
            mcpe_runtime.destroy_error(encode_err)
            continue
        }
        decoded, _, decode_err := decode_packet(data[:len(data) - 1])
        testing.expect(t, decoded == nil)
        testing.expect(t, decode_err != nil)
        if decode_err != nil {
            mcpe_runtime.destroy_error(decode_err)
        }
        delete(data)
    }
}

@(test)
resource_pack_transfer_packets_round_trip :: proc(t: ^testing.T) {
    packets := [?]Packet{
        Login{
            client_protocol = 1001,
            connection_request = []u8{1, 2, 3, 4},
        },
        Resource_Pack_Client_Response{
            response = Pack_Response_Send_Packs,
            packs_to_download = []string{"pack-one_1.0.0", "pack-two_2.0.0"},
        },
        Resource_Pack_Data_Info{
            uuid = "d2d3a4b5-c6d7-48e9-a001-020304050607",
            data_chunk_size = 1_048_576,
            chunk_count = 16,
            size = 15_500_000,
            hash = []u8{0xde, 0xad, 0xbe, 0xef},
            premium = true,
            pack_type = Resource_Pack_Type_Resources,
        },
        Resource_Pack_Chunk_Data{
            uuid = "d2d3a4b5-c6d7-48e9-a001-020304050607",
            chunk_index = 7,
            data_offset = 7 * 1_048_576,
            data = []u8{9, 8, 7, 6},
        },
        Resource_Pack_Chunk_Request{
            uuid = "d2d3a4b5-c6d7-48e9-a001-020304050607",
            chunk_index = -1,
        },
    }
    ids := [?]u32{
        IDLogin,
        IDResourcePackClientResponse,
        IDResourcePackDataInfo,
        IDResourcePackChunkData,
        IDResourcePackChunkRequest,
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

@(test)
simple_packets_round_trip :: proc(t: ^testing.T) {
    packets := [?]Packet{
        Client_Bound_Data_Driven_UI_Reload{},
        Refresh_Entitlements{},
        Resource_Packs_Ready_For_Validation{},
        Ticking_Areas_Load_Status{preload = true},
        Add_Behaviour_Tree{behaviour_tree = "tree"},
        Client_Start_Item_Cooldown{
            category = "ender_pearl",
            duration = -20,
        },
        Remove_Volume_Entity{
            entity_runtime_id = 12345,
            dimension = -1,
        },
        On_Screen_Texture_Animation{animation_type = 0x1234_5678},
        Automation_Client_Connect{server_uri = "localhost:8000/ws"},
        Photo_Info_Request{photo_id = -123_456_789},
        Map_Create_Locked_Copy{
            original_map_id = -7,
            new_map_id = 9001,
        },
        Script_Message{
            identifier = "mcpe:test",
            data = []u8{0, 1, 2, 255},
        },
        Open_Sign{position = {-12, 64, 3456}, front_side = true},
        Client_Bound_Data_Driven_UI_Close_Screen{
            form_id = protocol.option(u32(42)),
        },
        Available_Actor_Identifiers{
            serialised_entity_identifiers = []u8{10, 0, 0},
        },
        Current_Structure_Feature{
            current_feature = "minecraft:village",
        },
        Server_Stats{server_time = 12.5, network_time = 3.25},
        Anvil_Damage{
            damage = 2,
            anvil_position = {-12, 64, 3456},
        },
        Debug_Info{player_unique_id = -99, data = []u8{4, 5, 6}},
        Create_Photo{
            entity_unique_id = -7,
            photo_name = "photo",
            item_name = "portfolio",
        },
        Code_Builder{
            url = "ws://localhost:8080",
            should_open_code_builder = true,
        },
        Education_Resource_URI{
            resource = {
                button_name = "Learn",
                link_uri = "https://example.org/lesson",
            },
        },
        Player_Fog{
            stack = []string{"minecraft:fog_ocean", "custom:fog"},
        },
        Death_Info{
            cause = "suffocation",
            messages = []string{"one", "two"},
        },
        Client_Cache_Status{enabled = true},
        Level_Event_Generic{
            event_id = 2026,
            serialised_event_data = []u8{1, 2, 3},
        },
        Container_Close{
            window_id = 4,
            container_type = 12,
            server_side = true,
        },
        Container_Set_Data{window_id = 5, key = -2, value = 300},
        GUI_Data_Pick_Item{
            item_name = "Sword",
            item_effects = "+7 Attack",
            hot_bar_slot = -1,
        },
        Completed_Using_Item{used_item_id = -1234, use_method = 1},
        Agent_Animation{
            animation = 7,
            entity_runtime_id = u64(1) << 40 | 9,
        },
        Camera{
            camera_entity_unique_id = -7,
            target_player_unique_id = 9001,
        },
        Clientbound_Update_Sound_Data{
            server_sound_handle = 0x0123_4567_89ab_cdef,
            sound_event = Sound_Data_Event_Stop,
        },
        Game_Test_Results{
            name = "test:name",
            succeeded = false,
            error = "failed",
        },
        Hurt_Armour{cause = -2, damage = 7, armour_slots = 0x11},
        Lesson_Progress{
            identifier = "lesson.one",
            action = Lesson_Action_Complete,
            score = 99,
        },
        Motion_Prediction_Hints{
            entity_runtime_id = u64(1) << 40 | 10,
            velocity = {1.25, -2.5, 3.75},
            on_ground = true,
        },
        Multi_Player_Settings{action_type = Refresh_Join_Code},
        Packet_Violation_Warning{
            type = Violation_Type_Malformed,
            severity = Violation_Severity_Final_Warning,
            packet_id = 42,
            violation_context = "bad payload",
        },
        Request_Permissions{
            entity_unique_id = -9001,
            permission_level = 2,
            requested_permissions = 0x1234,
        },
        Update_Adventure_Settings{
            no_pvm = true,
            no_mvp = false,
            immutable_world = true,
            show_name_tags = false,
            auto_jump = true,
        },
        Update_Client_Input_Locks{
            locks = Client_Input_Lock_Camera | Client_Input_Lock_Jump,
        },
        Update_Client_Options{
            graphics_mode = protocol.option(Graphics_Mode_Advanced),
            filter_profanity = protocol.option(true),
        },
    }
    ids := [?]u32{
        IDClientBoundDataDrivenUIReload,
        IDRefreshEntitlements,
        IDResourcePacksReadyForValidation,
        IDTickingAreasLoadStatus,
        IDAddBehaviourTree,
        IDClientStartItemCooldown,
        IDRemoveVolumeEntity,
        IDOnScreenTextureAnimation,
        IDAutomationClientConnect,
        IDPhotoInfoRequest,
        IDMapCreateLockedCopy,
        IDScriptMessage,
        IDOpenSign,
        IDClientBoundDataDrivenUICloseScreen,
        IDAvailableActorIdentifiers,
        IDCurrentStructureFeature,
        IDServerStats,
        IDAnvilDamage,
        IDDebugInfo,
        IDCreatePhoto,
        IDCodeBuilder,
        IDEducationResourceURI,
        IDPlayerFog,
        IDDeathInfo,
        IDClientCacheStatus,
        IDLevelEventGeneric,
        IDContainerClose,
        IDContainerSetData,
        IDGUIDataPickItem,
        IDCompletedUsingItem,
        IDAgentAnimation,
        IDCamera,
        IDClientboundUpdateSoundData,
        IDGameTestResults,
        IDHurtArmour,
        IDLessonProgress,
        IDMotionPredictionHints,
        IDMultiPlayerSettings,
        IDPacketViolationWarning,
        IDRequestPermissions,
        IDUpdateAdventureSettings,
        IDUpdateClientInputLocks,
        IDUpdateClientOptions,
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

@(test)
item_cooldown_decode_cleans_partial_string :: proc(t: ^testing.T) {
    decoded, _, err := decode_packet(
        []u8{0xb0, 0x01, 0x01, 'x', 0x80},
    )
    testing.expect(t, decoded == nil)
    testing.expect(t, err != nil)
    if err != nil {
        mcpe_runtime.destroy_error(err)
    }
}

@(test)
simple_packet_decode_cleans_partial_values :: proc(t: ^testing.T) {
    packets := [?]Packet{
        Create_Photo{
            entity_unique_id = -7,
            photo_name = "photo",
            item_name = "portfolio",
        },
        Code_Builder{
            url = "ws://localhost:8080",
            should_open_code_builder = true,
        },
        Education_Resource_URI{
            resource = {
                button_name = "Learn",
                link_uri = "https://example.org/lesson",
            },
        },
        Player_Fog{stack = []string{"one", "two"}},
        Death_Info{cause = "suffocation", messages = []string{"one"}},
        GUI_Data_Pick_Item{
            item_name = "Sword",
            item_effects = "+7 Attack",
            hot_bar_slot = -1,
        },
        Game_Test_Results{
            name = "test:name",
            succeeded = false,
            error = "failed",
        },
    }
    for original in packets {
        encoded, encode_err := encode_packet(original)
        testing.expect(t, encode_err == nil)
        if encode_err != nil {
            mcpe_runtime.destroy_error(encode_err)
            continue
        }
        decoded, _, decode_err :=
            decode_packet(encoded[:len(encoded) - 1])
        testing.expect(t, decoded == nil)
        testing.expect(t, decode_err != nil)
        if decode_err != nil {
            mcpe_runtime.destroy_error(decode_err)
        }
        delete(encoded)
    }
}

@(test)
simple_packet_string_lists_are_bounded :: proc(t: ^testing.T) {
    entries := make(
        []string,
        protocol.MAX_COLLECTION_ELEMENTS + 1,
    )
    defer delete(entries)
    _, err := encode_packet(Player_Fog{stack = entries})
    testing.expect(t, err != nil)
    if err != nil {
        testing.expect_value(
            t,
            err.kind,
            mcpe_runtime.Error_Kind.Limit_Exceeded,
        )
        mcpe_runtime.destroy_error(err)
    }
}

@(test)
resource_pack_response_entry_count_is_bounded :: proc(t: ^testing.T) {
    decoded, _, err := decode_packet(
        []u8{
            u8(IDResourcePackClientResponse),
            Pack_Response_Send_Packs,
            1,
            4,
        },
    )
    testing.expect(t, decoded == nil)
    testing.expect(t, err != nil)
    if err != nil {
        testing.expect_value(
            t,
            err.kind,
            mcpe_runtime.Error_Kind.Limit_Exceeded,
        )
        mcpe_runtime.destroy_error(err)
    }

    entries := make(
        []string,
        MAX_RESOURCE_PACK_RESPONSE_ENTRIES + 1,
    )
    defer delete(entries)
    _, encode_err := encode_packet(
        Resource_Pack_Client_Response{
            response = Pack_Response_Send_Packs,
            packs_to_download = entries,
        },
    )
    testing.expect(t, encode_err != nil)
    if encode_err != nil {
        testing.expect_value(
            t,
            encode_err.kind,
            mcpe_runtime.Error_Kind.Limit_Exceeded,
        )
        mcpe_runtime.destroy_error(encode_err)
    }
}

@(test)
owned_resource_pack_fields_are_cleaned_on_truncation :: proc(
    t: ^testing.T,
) {
    packets := [?]Packet{
        Login{
            client_protocol = 1001,
            connection_request = []u8{1, 2, 3},
        },
        Resource_Pack_Client_Response{
            response = Pack_Response_Send_Packs,
            packs_to_download = []string{"one", "two"},
        },
        Resource_Pack_Data_Info{
            uuid = "pack",
            hash = []u8{1, 2, 3},
        },
        Resource_Pack_Chunk_Data{
            uuid = "pack",
            data = []u8{1, 2, 3},
        },
        Resource_Pack_Chunk_Request{uuid = "pack", chunk_index = 1},
    }
    for original in packets {
        data, encode_err := encode_packet(original)
        testing.expect(t, encode_err == nil)
        if encode_err != nil {
            mcpe_runtime.destroy_error(encode_err)
            continue
        }
        decoded, _, decode_err := decode_packet(data[:len(data) - 1])
        testing.expect(t, decoded == nil)
        testing.expect(t, decode_err != nil)
        if decode_err != nil {
            mcpe_runtime.destroy_error(decode_err)
        }
        delete(data)
    }
}

@(test)
resource_pack_handshake_packets_round_trip :: proc(t: ^testing.T) {
    pack_uuid := protocol.UUID{
        0x00,
        0x11,
        0x22,
        0x33,
        0x44,
        0x55,
        0x66,
        0x77,
        0x88,
        0x99,
        0xaa,
        0xbb,
        0xcc,
        0xdd,
        0xee,
        0xff,
    }
    packets := [?]Packet{
        Resource_Packs_Info{
            texture_pack_required = true,
            has_addons = true,
            has_scripts = true,
            force_disable_vibrant_visuals = true,
            world_template_uuid = pack_uuid,
            world_template_version = "1.0.0",
            texture_packs = []protocol.Texture_Pack_Info{
                {
                    uuid = pack_uuid,
                    version = "2.0.0",
                    size = 15_500_000,
                    content_key = "content-key",
                    sub_pack_name = "sub-pack",
                    content_identity = "identity",
                    has_scripts = true,
                    addon_pack = true,
                    rtx_enabled = true,
                    download_url = "https://example.org/pack.zip",
                },
            },
        },
        Resource_Pack_Stack{
            texture_pack_required = true,
            texture_packs = []protocol.Stack_Resource_Pack{
                {
                    uuid = "00112233-4455-6677-8899-aabbccddeeff",
                    version = "2.0.0",
                    sub_pack_name = "sub-pack",
                },
            },
            base_game_version = "1.26.30",
            experiments = []protocol.Experiment_Data{
                {name = "experiment", enabled = true},
            },
            experiments_previously_toggled = true,
            include_editor_packs = true,
        },
    }
    ids := [?]u32{IDResourcePacksInfo, IDResourcePackStack}
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

@(test)
nested_resource_pack_fields_are_cleaned_on_truncation :: proc(
    t: ^testing.T,
) {
    packets := [?]Packet{
        Resource_Packs_Info{
            world_template_version = "1.0.0",
            texture_packs = []protocol.Texture_Pack_Info{
                {
                    version = "2.0.0",
                    content_key = "key",
                    sub_pack_name = "sub",
                    content_identity = "identity",
                    download_url = "url",
                },
            },
        },
        Resource_Pack_Stack{
            texture_packs = []protocol.Stack_Resource_Pack{
                {uuid = "uuid", version = "1.0.0", sub_pack_name = "sub"},
            },
            base_game_version = "1.26.30",
            experiments = []protocol.Experiment_Data{
                {name = "experiment", enabled = true},
            },
        },
    }
    for original in packets {
        data, encode_err := encode_packet(original)
        testing.expect(t, encode_err == nil)
        if encode_err != nil {
            mcpe_runtime.destroy_error(encode_err)
            continue
        }
        decoded, _, decode_err := decode_packet(data[:len(data) - 1])
        testing.expect(t, decoded == nil)
        testing.expect(t, decode_err != nil)
        if decode_err != nil {
            mcpe_runtime.destroy_error(decode_err)
        }
        delete(data)
    }
}

@(test)
text_packet_variants_round_trip :: proc(t: ^testing.T) {
    packets := [?]Packet{
        Text{text_type = Text_Type_Raw, message = "raw message"},
        Text{
            text_type = Text_Type_Chat,
            source_name = "Steve",
            message = "hello",
            xuid = "2533274790395904",
            platform_chat_id = "platform",
            filtered_message = protocol.option(string("filtered hello")),
        },
        Text{
            text_type = Text_Type_Translation,
            needs_translation = true,
            message = "chat.type.text",
            parameters = []string{"Steve", "hello"},
        },
    }
    for original in packets {
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
        testing.expect_value(t, header.packet_id, IDText)
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

@(test)
text_packet_rejects_empty_message_and_cleans_truncation :: proc(
    t: ^testing.T,
) {
    _, empty_err := encode_packet(Text{text_type = Text_Type_Chat})
    testing.expect(t, empty_err != nil)
    if empty_err != nil {
        testing.expect_value(
            t,
            empty_err.kind,
            mcpe_runtime.Error_Kind.Invalid_Argument,
        )
        mcpe_runtime.destroy_error(empty_err)
    }
    _, type_err := encode_packet(
        Text{text_type = 12, message = "invalid"},
    )
    testing.expect(t, type_err != nil)
    if type_err != nil {
        testing.expect_value(
            t,
            type_err.kind,
            mcpe_runtime.Error_Kind.Invalid_Argument,
        )
        mcpe_runtime.destroy_error(type_err)
    }
    ignored_parameters := make(
        []string,
        protocol.MAX_COLLECTION_ELEMENTS + 1,
    )
    ignored_data, ignored_err := encode_packet(
        Text{
            text_type = Text_Type_Raw,
            message = "parameters ignored",
            parameters = ignored_parameters,
        },
    )
    testing.expect(t, ignored_err == nil)
    if ignored_err != nil {
        mcpe_runtime.destroy_error(ignored_err)
    }
    delete(ignored_data)
    delete(ignored_parameters)

    original: Packet = Text{
        text_type = Text_Type_Chat,
        source_name = "Steve",
        message = "hello",
        xuid = "2533274790395904",
        filtered_message = protocol.option(string("filtered")),
    }
    data, encode_err := encode_packet(original)
    testing.expect(t, encode_err == nil)
    if encode_err != nil {
        mcpe_runtime.destroy_error(encode_err)
        return
    }
    decoded, _, decode_err := decode_packet(data[:len(data) - 1])
    testing.expect(t, decoded == nil)
    testing.expect(t, decode_err != nil)
    if decode_err != nil {
        mcpe_runtime.destroy_error(decode_err)
    }
    delete(data)
}

@(test)
ui_packets_round_trip :: proc(t: ^testing.T) {
    offer_id := protocol.UUID{
        0x00,
        0x11,
        0x22,
        0x33,
        0x44,
        0x55,
        0x66,
        0x77,
        0x88,
        0x99,
        0xaa,
        0xbb,
        0xcc,
        0xdd,
        0xee,
        0xff,
    }
    packets := [?]Packet{
        Set_Title{
            action_type = Title_Action_Set_Title,
            text = "Welcome",
            fade_in_duration = 10,
            remain_duration = 70,
            fade_out_duration = 20,
            xuid = "2533274790395904",
            platform_online_id = "1234",
            filtered_message = "Filtered Welcome",
        },
        Show_Store_Offer{
            offer_id = offer_id,
            type = Store_Offer_Type_Dressing_Room,
        },
        Purchase_Receipt{receipts = []string{"receipt-one", "receipt-two"}},
        Modal_Form_Response{
            form_id = 42,
            response_data = protocol.option([]u8{1, 2, 3}),
            cancel_reason = protocol.option(
                Modal_Form_Cancel_Reason_User_Busy,
            ),
        },
        Server_Settings_Request{},
        Server_Settings_Response{
            form_id = 43,
            form_data = []u8{4, 5, 6},
        },
        Settings_Command{
            command_line = "gamerule showcoordinates true",
            suppress_output = true,
        },
    }
    ids := [?]u32{
        IDSetTitle,
        IDShowStoreOffer,
        IDPurchaseReceipt,
        IDModalFormResponse,
        IDServerSettingsRequest,
        IDServerSettingsResponse,
        IDSettingsCommand,
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

@(test)
owned_ui_fields_are_cleaned_on_truncation :: proc(t: ^testing.T) {
    packets := [?]Packet{
        Set_Title{text = "title", filtered_message = "filtered"},
        Purchase_Receipt{receipts = []string{"one", "two"}},
        Modal_Form_Response{
            form_id = 1,
            response_data = protocol.option([]u8{1, 2, 3}),
            cancel_reason = protocol.option(
                Modal_Form_Cancel_Reason_User_Closed,
            ),
        },
        Server_Settings_Response{form_id = 2, form_data = []u8{1, 2, 3}},
        Settings_Command{command_line = "command", suppress_output = true},
    }
    for original in packets {
        data, encode_err := encode_packet(original)
        testing.expect(t, encode_err == nil)
        if encode_err != nil {
            mcpe_runtime.destroy_error(encode_err)
            continue
        }
        decoded, _, decode_err := decode_packet(data[:len(data) - 1])
        testing.expect(t, decoded == nil)
        testing.expect(t, decode_err != nil)
        if decode_err != nil {
            mcpe_runtime.destroy_error(decode_err)
        }
        delete(data)
    }
}

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
        Actor_Event{
            entity_runtime_id = u64(1) << 40 | 11,
            event_type = 2,
            event_data = -3,
            fire_at_position = protocol.option(protocol.Vec3{1, 2, 3}),
        },
        Agent_Action{
            identifier = "action-id",
            action = 4,
            response = []u8{1, 2, 3},
        },
        Block_Event{
            position = {-12, 64, 3456},
            event_type = 1,
            event_data = 1,
        },
        Camera_Shake{
            intensity = 2.5,
            duration = 4.25,
            type = 1,
            action = 0,
        },
        Code_Builder_Source{operation = 2, category = 1, code_status = 5},
        Emote{
            entity_runtime_id = u64(1) << 40 | 12,
            emote_length = 80,
            emote_id = "emote-id",
            xuid = "1234",
            platform_id = "platform",
            flags = 3,
        },
        Game_Test_Request{
            name = "test:name",
            rotation = 2,
            repetitions = 3,
            position = {-12, 64, 3456},
            stop_on_error = true,
            tests_per_row = 4,
            max_tests_per_batch = 5,
        },
        Lab_Table{
            action_type = 1,
            position = {-12, 64, 3456},
            reaction_type = 7,
        },
        Lectern_Update{
            page = 2,
            page_count = 10,
            position = {-12, 64, 3456},
        },
        NPC_Request{
            entity_runtime_id = u64(1) << 40 | 13,
            request_type = 1,
            command_string = "/say hello",
            action_type = 2,
            scene_name = "scene",
        },
        Player_Action{
            entity_runtime_id = u64(1) << 40 | 14,
            action_type = -2,
            block_position = {-12, 64, 3456},
            result_position = {-11, 65, 3457},
            block_face = 3,
        },
        Spawn_Particle_Effect{
            dimension = 2,
            entity_unique_id = -1,
            position = {1.25, 2.5, 3.75},
            particle_name = "minecraft:test",
            molang_variables = protocol.option([]u8{
                '{', '"', 'x', '"', ':', '1', '}',
            }),
        },
        Client_Cache_Blob_Status{
            miss_hashes = []u64{1, 0x0123_4567_89ab_cdef},
            hit_hashes = []u64{2, 3},
        },
        Client_Bound_Data_Driven_UI_Show_Screen{
            screen_id = "screen:test",
            form_id = 42,
            data_instance_id = protocol.option(u32(99)),
        },
        Sub_Client_Login{connection_request = []u8{1, 2, 3, 4}},
        Script_Custom_Event{
            event_name = "test:event",
            event_data = []u8{4, 5, 6},
        },
        Emote_List{
            player_runtime_id = u64(1) << 40 | 15,
            emote_pieces = []protocol.UUID{protocol.UUID{}},
        },
        Send_Party_Destination_Cookie{
            cookie = "opaque",
            intent = "OptIn",
            destination_name = "server",
        },
        Player_Toggle_Crafter_Slot_Request{
            pos_x = -12,
            pos_y = 64,
            pos_z = 3456,
            slot = 8,
            disabled = true,
        },
        Client_Camera_Aim_Assist{
            preset_id = "preset",
            action = 1,
            allow_aim_assist = true,
        },
        Server_Bound_Data_Driven_Screen_Closed{
            form_id = 42,
            close_reason = "userbusy",
        },
        Position_Tracking_DB_Client_Request{
            request_action = 0,
            tracking_id = -99,
        },
        Party_Changed{
            party_info = protocol.option(Party_Info{
                party_id = "party",
                party_leader = true,
            }),
        },
        Party_Destination_Cookie_Response{
            cookie = "opaque",
            accepted = true,
        },
        Client_Bound_Control_Scheme_Set{
            control_scheme = Control_Scheme_Camera_Relative_Strafe,
        },
        Movement_Effect{
            entity_runtime_id = u64(1) << 40 | 16,
            type = Movement_Effect_Type_Dolphin_Boost,
            duration = 40,
            tick = 123456,
        },
        Player_Video_Capture{
            action = Player_Video_Capture_Action_Start,
            frame_rate = 60,
            file_prefix = "capture-",
        },
        Player_Location{
            type = Player_Location_Type_Coordinates,
            entity_unique_id = -99,
            position = {1.25, 2.5, 3.75},
        },
        Client_Bound_Texture_Shift{
            action_id = Texture_Shift_Action_Sync,
            collection_name = "collection",
            from_step = "one",
            to_step = "two",
            all_steps = []string{"one", "two"},
            current_length_ticks = 10,
            total_length_ticks = 20,
            enabled = true,
        },
        Set_Hud{
            elements = []i32{Hud_Element_Crosshair, Hud_Element_Hot_Bar},
            visibility = Hud_Visibility_Hide,
        },
        Set_Player_Inventory_Options{
            left_inventory_tab = Inventory_Left_Tab_Search,
            right_inventory_tab = Inventory_Right_Tab_Crafting,
            filtering = true,
            inventory_layout = Inventory_Layout_Default,
            crafting_layout = Inventory_Layout_Recipe_Book_Only,
        },
        Player_Update_Entity_Overrides{
            entity_unique_id = -99,
            property_index = 7,
            type = Player_Update_Entity_Overrides_Type_Float,
            float_value = 2.5,
        },
        Camera_Aim_Assist{
            preset = "preset",
            angle = {12.5, 8.25},
            distance = 32,
            target_mode = 1,
            action = Camera_Aim_Assist_Action_Set,
            show_debug_render = true,
        },
        Change_Mob_Property{
            entity_unique_id = -99,
            property = "minecraft:test",
            bool_value = true,
            string_value = "value",
            int_value = -7,
            float_value = 2.5,
        },
        Mob_Effect{
            entity_runtime_id = u64(1) << 40 | 17,
            operation = 1,
            effect_type = 1,
            amplifier = 2,
            particles = true,
            duration = 600,
            tick = 123456,
            ambient = false,
        },
        Play_Sound{
            sound_name = "note.pling",
            position = {1.25, 2.5, -3.75},
            volume = 0.75,
            pitch = 1.25,
            handle = protocol.option(u64(42)),
        },
        Interact{
            action_type = Interact_Action_Mouse_Over_Entity,
            target_entity_runtime_id = u64(1) << 40 | 18,
            position = protocol.option(protocol.Vec3{1.25, 2.5, 3.75}),
        },
        Move_Actor_Absolute{
            entity_runtime_id = u64(1) << 40 | 19,
            flags = Move_Flag_On_Ground,
            position = {1.25, 2.5, 3.75},
            rotation = {45, 90, 180},
        },
        Move_Actor_Delta{
            entity_runtime_id = u64(1) << 40 | 20,
            flags = Move_Actor_Delta_Flag_Has_X |
                    Move_Actor_Delta_Flag_Has_Z |
                    Move_Actor_Delta_Flag_Has_Rot_Y,
            position = {1.25, 0, 3.75},
            rotation = {0, 90, 0},
        },
        Container_Open{
            window_id = 4,
            container_type = 12,
            container_position = {-12, 64, 3456},
            container_entity_unique_id = -99,
        },
        Network_Chunk_Publisher_Update{
            position = {-12, 64, 3456},
            radius = 128,
            saved_chunks = []protocol.Chunk_Pos{{-2, 3}, {4, -5}},
        },
        Add_Painting{
            entity_unique_id = -99,
            entity_runtime_id = u64(1) << 40 | 21,
            position = {1.25, 2.5, 3.75},
            direction = 2,
            title = "Kebab",
        },
        Animate{
            action_type = Animate_Action_Swing_Arm,
            entity_runtime_id = u64(1) << 40 | 22,
            data = 1.25,
            swing_source = Animate_Swing_Source_Attack,
        },
        Set_Actor_Link{
            entity_link = {
                ridden_entity_unique_id = -7,
                rider_entity_unique_id = -99,
                type = protocol.Entity_Link_Rider,
                immediate = true,
                rider_initiated = true,
                vehicle_angular_velocity = 1.5,
            },
        },
        Map_Info_Request{
            map_id = -99,
            client_pixels = []protocol.Pixel_Request{{
                colour = {r = 1, g = 2, b = 3, a = 4},
                index = 300,
            }},
        },
        Player_Armour_Damage{
            list = []protocol.Player_Armour_Damage_Entry{
                {armour_slot = 0, damage = 7},
                {armour_slot = 3, damage = -2},
            },
        },
        Level_Event{
            event_type = 2001,
            position = {1.25, 2.5, 3.75},
            event_data = -7,
        },
        Photo_Transfer{
            photo_name = "photo.png",
            photo_data = []u8{1, 2, 3, 4},
            book_id = "book",
            photo_type = Photo_Type_Photo_Item,
            source_type = Photo_Type_Portfolio,
            owner_entity_unique_id = -99,
            new_photo_name = "renamed.png",
        },
        Set_Display_Objective{
            display_slot = Scoreboard_Slot_Sidebar,
            objective_name = "kills",
            display_name = "Kills",
            criteria_name = "dummy",
            sort_order = Scoreboard_Sort_Order_Descending,
        },
        Level_Sound_Event{
            sound_type = "step",
            position = {1.25, 2.5, 3.75},
            extra_data = -7,
            entity_type = "minecraft:zombie",
            baby_mob = true,
            disable_relative_volume = false,
            entity_unique_id = -99,
            fire_at_position = protocol.option(protocol.Vec3{4, 5, 6}),
        },
        Animate_Entity{
            animation = "animation.test",
            next_state = "default",
            stop_condition = "query.is_on_ground",
            stop_condition_version = 1,
            controller = "controller.animation.test",
            blend_out_time = 0.25,
            entity_runtime_ids = []u64{
                u64(1) << 40 | 23,
                u64(1) << 40 | 24,
            },
        },
        Set_Score{
            action_type = Scoreboard_Action_Modify,
            entries = []protocol.Scoreboard_Entry{{
                entry_id = 7,
                objective_name = "kills",
                score = 42,
                identity_type = protocol.Scoreboard_Identity_Fake_Player,
                display_name = "Player",
            }},
        },
        Set_Scoreboard_Identity{
            action_type = Scoreboard_Identity_Action_Register,
            entries = []protocol.Scoreboard_Identity_Entry{{
                entry_id = 7,
                entity_unique_id = -99,
            }},
        },
        Update_Block{
            position = {-12, 64, 3456},
            new_block_runtime_id = 42,
            flags = Block_Update_Network,
            layer = 1,
        },
        Update_Block_Synced{
            position = {-12, 64, 3456},
            new_block_runtime_id = 42,
            flags = Block_Update_Network,
            layer = 1,
            entity_unique_id = u64(1) << 40 | 25,
            transition_type = Block_To_Entity_Transition,
        },
        Adventure_Settings{
            flags = u32(1 << 6),
            command_permission_level = 2,
            action_permissions = u32(1 << 0) | u32(1 << 7),
            permission_level = 1,
            custom_stored_permissions = 7,
            player_unique_id = -99,
        },
        Book_Edit{
            inventory_slot = 2,
            action_type = Book_Action_Replace_Page,
            page_number = 3,
            text = "hello",
            photo_name = "photo.png",
        },
        Boss_Event{
            boss_entity_unique_id = -7,
            player_unique_id = -99,
            event_type = 0,
            boss_bar_title = "Boss",
            filtered_boss_bar_title = "Boss",
            health_percentage = 0.75,
            colour = 5,
            overlay = 2,
        },
        Update_Soft_Enum{
            enum_type = "targets",
            options = []string{"one", "two"},
            action_type = Soft_Enum_Action_Set,
        },
        Unlocked_Recipes{
            unlock_type = Unlocked_Recipes_Type_Newly_Unlocked,
            recipes = []string{"minecraft:bread", "minecraft:cake"},
        },
        Trim_Data{
            patterns = []protocol.Trim_Pattern{{
                item_name =
                    "minecraft:spire_armor_trim_smithing_template",
                pattern_id = "spire",
            }},
            materials = []protocol.Trim_Material{{
                material_id = "gold",
                colour = "§6",
                item_name = "minecraft:gold_ingot",
            }},
        },
        Feature_Registry{
            features = []protocol.Generation_Feature{{
                name = "minecraft:test",
                json = transmute([]u8)string(`{"format_version":"1.0"}`),
            }},
        },
        Dimension_Data{
            definitions = []protocol.Dimension_Definition{{
                name = "custom:test",
                range = {320, -64},
                generator = protocol.Generator_Overworld,
                dimension_type = 1000,
            }},
        },
        Server_Store_Info{
            store_info = protocol.option(protocol.Store_Entry_Point_Info{
                store_id = "store-id",
                store_name = "Store",
            }),
        },
        Server_Presence_Info{
            presence_info = protocol.option(protocol.Presence_Info{
                experience_name = protocol.option("Experience"),
                world_name = protocol.option("World"),
                rich_presence_id = "presence-id",
            }),
        },
        Camera_Aim_Assist_Actor_Priority{
            priority_data =
                []protocol.Camera_Aim_Assist_Actor_Priority_Data{{
                    preset_index = 1,
                    category_index = 2,
                    actor_index = 3,
                    priority = 4,
                }},
        },
        Correct_Player_Move_Prediction{
            prediction_type = Prediction_Type_Vehicle,
            position = {1.25, 2.5, 3.75},
            delta = {-0.25, 0.5, 0.75},
            rotation = {45, 90},
            vehicle_angular_velocity = protocol.option(f32(1.5)),
            on_ground = true,
            tick = 123456,
        },
        Update_Abilities{
            ability_data = {
                entity_unique_id = -99,
                player_permissions = 1,
                command_permissions = 2,
                layers = []protocol.Ability_Layer{{
                    type = protocol.Ability_Layer_Type_Base,
                    abilities = u32(1 << 10) | u32(1 << 9),
                    values = u32(1 << 10),
                    fly_speed = 0.05,
                    vertical_fly_speed = 1,
                    walk_speed = 0.1,
                }},
            },
        },
        Client_Cheat_Ability{
            ability_data = {
                entity_unique_id = -99,
                player_permissions = 1,
                command_permissions = 2,
                layers = []protocol.Ability_Layer{{
                    type = protocol.Ability_Layer_Type_Base,
                    abilities = u32(1 << 10) | u32(1 << 9),
                    values = u32(1 << 10),
                    fly_speed = 0.05,
                    vertical_fly_speed = 1,
                    walk_speed = 0.1,
                }},
            },
        },
        Container_Registry_Cleanup{
            removed_containers = []protocol.Full_Container_Name{{
                container_id = 0,
                dynamic_container_id = protocol.option(u32(42)),
            }},
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
        IDActorEvent,
        IDAgentAction,
        IDBlockEvent,
        IDCameraShake,
        IDCodeBuilderSource,
        IDEmote,
        IDGameTestRequest,
        IDLabTable,
        IDLecternUpdate,
        IDNPCRequest,
        IDPlayerAction,
        IDSpawnParticleEffect,
        IDClientCacheBlobStatus,
        IDClientBoundDataDrivenUIShowScreen,
        IDSubClientLogin,
        IDScriptCustomEvent,
        IDEmoteList,
        IDSendPartyDestinationCookie,
        IDPlayerToggleCrafterSlotRequest,
        IDClientCameraAimAssist,
        IDServerBoundDataDrivenScreenClosed,
        IDPositionTrackingDBClientRequest,
        IDPartyChanged,
        IDPartyDestinationCookieResponse,
        IDClientBoundControlSchemeSet,
        IDMovementEffect,
        IDPlayerVideoCapture,
        IDPlayerLocation,
        IDClientBoundTextureShift,
        IDSetHud,
        IDSetPlayerInventoryOptions,
        IDPlayerUpdateEntityOverrides,
        IDCameraAimAssist,
        IDChangeMobProperty,
        IDMobEffect,
        IDPlaySound,
        IDInteract,
        IDMoveActorAbsolute,
        IDMoveActorDelta,
        IDContainerOpen,
        IDNetworkChunkPublisherUpdate,
        IDAddPainting,
        IDAnimate,
        IDSetActorLink,
        IDMapInfoRequest,
        IDPlayerArmourDamage,
        IDLevelEvent,
        IDPhotoTransfer,
        IDSetDisplayObjective,
        IDLevelSoundEvent,
        IDAnimateEntity,
        IDSetScore,
        IDSetScoreboardIdentity,
        IDUpdateBlock,
        IDUpdateBlockSynced,
        IDAdventureSettings,
        IDBookEdit,
        IDBossEvent,
        IDUpdateSoftEnum,
        IDUnlockedRecipes,
        IDTrimData,
        IDFeatureRegistry,
        IDDimensionData,
        IDServerStoreInfo,
        IDServerPresenceInfo,
        IDCameraAimAssistActorPriority,
        IDCorrectPlayerMovePrediction,
        IDUpdateAbilities,
        IDClientCheatAbility,
        IDContainerRegistryCleanup,
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
        Agent_Action{
            identifier = "action-id",
            action = 4,
            response = []u8{1, 2, 3},
        },
        Emote{
            entity_runtime_id = 12,
            emote_length = 80,
            emote_id = "emote-id",
            xuid = "1234",
            platform_id = "platform",
            flags = 3,
        },
        NPC_Request{
            entity_runtime_id = 13,
            request_type = 1,
            command_string = "/say hello",
            action_type = 2,
            scene_name = "scene",
        },
        Spawn_Particle_Effect{
            dimension = 2,
            entity_unique_id = -1,
            position = {1.25, 2.5, 3.75},
            particle_name = "minecraft:test",
            molang_variables = protocol.option([]u8{1, 2, 3}),
        },
        Client_Cache_Blob_Status{
            miss_hashes = []u64{1, 2},
            hit_hashes = []u64{3, 4},
        },
        Client_Bound_Data_Driven_UI_Show_Screen{
            screen_id = "screen:test",
            form_id = 42,
            data_instance_id = protocol.option(u32(99)),
        },
        Script_Custom_Event{
            event_name = "test:event",
            event_data = []u8{4, 5, 6},
        },
        Send_Party_Destination_Cookie{
            cookie = "opaque",
            intent = "OptIn",
            destination_name = "server",
        },
        Client_Camera_Aim_Assist{
            preset_id = "preset",
            action = 1,
            allow_aim_assist = true,
        },
        Party_Changed{
            party_info = protocol.option(Party_Info{
                party_id = "party",
                party_leader = true,
            }),
        },
        Party_Destination_Cookie_Response{
            cookie = "opaque",
            accepted = true,
        },
        Player_Video_Capture{
            action = Player_Video_Capture_Action_Start,
            frame_rate = 60,
            file_prefix = "capture-",
        },
        Client_Bound_Texture_Shift{
            action_id = Texture_Shift_Action_Sync,
            collection_name = "collection",
            from_step = "one",
            to_step = "two",
            all_steps = []string{"one", "two"},
            current_length_ticks = 10,
            total_length_ticks = 20,
            enabled = true,
        },
        Set_Hud{
            elements = []i32{Hud_Element_Crosshair, Hud_Element_Hot_Bar},
            visibility = Hud_Visibility_Hide,
        },
        Camera_Aim_Assist{
            preset = "preset",
            angle = {12.5, 8.25},
            distance = 32,
            target_mode = 1,
            action = Camera_Aim_Assist_Action_Set,
            show_debug_render = true,
        },
        Change_Mob_Property{
            entity_unique_id = -99,
            property = "minecraft:test",
            bool_value = true,
            string_value = "value",
            int_value = -7,
            float_value = 2.5,
        },
        Play_Sound{
            sound_name = "note.pling",
            position = {1.25, 2.5, -3.75},
            volume = 0.75,
            pitch = 1.25,
            handle = protocol.option(u64(42)),
        },
        Network_Chunk_Publisher_Update{
            position = {-12, 64, 3456},
            radius = 128,
            saved_chunks = []protocol.Chunk_Pos{{-2, 3}, {4, -5}},
        },
        Add_Painting{
            entity_unique_id = -99,
            entity_runtime_id = u64(1) << 40 | 21,
            position = {1.25, 2.5, 3.75},
            direction = 2,
            title = "Kebab",
        },
        Map_Info_Request{
            map_id = -99,
            client_pixels = []protocol.Pixel_Request{{
                colour = {r = 1, g = 2, b = 3, a = 4},
                index = 300,
            }},
        },
        Player_Armour_Damage{
            list = []protocol.Player_Armour_Damage_Entry{
                {armour_slot = 0, damage = 7},
                {armour_slot = 3, damage = -2},
            },
        },
        Photo_Transfer{
            photo_name = "photo.png",
            photo_data = []u8{1, 2, 3, 4},
            book_id = "book",
            photo_type = Photo_Type_Photo_Item,
            source_type = Photo_Type_Portfolio,
            owner_entity_unique_id = -99,
            new_photo_name = "renamed.png",
        },
        Set_Display_Objective{
            display_slot = Scoreboard_Slot_Sidebar,
            objective_name = "kills",
            display_name = "Kills",
            criteria_name = "dummy",
            sort_order = Scoreboard_Sort_Order_Descending,
        },
        Level_Sound_Event{
            sound_type = "step",
            position = {1.25, 2.5, 3.75},
            extra_data = -7,
            entity_type = "minecraft:zombie",
            baby_mob = true,
            disable_relative_volume = false,
            entity_unique_id = -99,
            fire_at_position = protocol.option(protocol.Vec3{4, 5, 6}),
        },
        Animate_Entity{
            animation = "animation.test",
            next_state = "default",
            stop_condition = "query.is_on_ground",
            stop_condition_version = 1,
            controller = "controller.animation.test",
            blend_out_time = 0.25,
            entity_runtime_ids = []u64{
                u64(1) << 40 | 23,
                u64(1) << 40 | 24,
            },
        },
        Set_Score{
            action_type = Scoreboard_Action_Modify,
            entries = []protocol.Scoreboard_Entry{{
                entry_id = 7,
                objective_name = "kills",
                score = 42,
                identity_type = protocol.Scoreboard_Identity_Fake_Player,
                display_name = "Player",
            }},
        },
        Set_Scoreboard_Identity{
            action_type = Scoreboard_Identity_Action_Register,
            entries = []protocol.Scoreboard_Identity_Entry{{
                entry_id = 7,
                entity_unique_id = -99,
            }},
        },
        Book_Edit{
            inventory_slot = 2,
            action_type = Book_Action_Replace_Page,
            page_number = 3,
            text = "hello",
            photo_name = "photo.png",
        },
        Boss_Event{
            boss_entity_unique_id = -7,
            player_unique_id = -99,
            event_type = 0,
            boss_bar_title = "Boss",
            filtered_boss_bar_title = "Boss",
            health_percentage = 0.75,
            colour = 5,
            overlay = 2,
        },
        Update_Soft_Enum{
            enum_type = "targets",
            options = []string{"one", "two"},
            action_type = Soft_Enum_Action_Set,
        },
        Unlocked_Recipes{
            unlock_type = Unlocked_Recipes_Type_Newly_Unlocked,
            recipes = []string{"minecraft:bread", "minecraft:cake"},
        },
        Trim_Data{
            patterns = []protocol.Trim_Pattern{{
                item_name =
                    "minecraft:spire_armor_trim_smithing_template",
                pattern_id = "spire",
            }},
            materials = []protocol.Trim_Material{{
                material_id = "gold",
                colour = "§6",
                item_name = "minecraft:gold_ingot",
            }},
        },
        Feature_Registry{
            features = []protocol.Generation_Feature{{
                name = "minecraft:test",
                json = transmute([]u8)string(`{"format_version":"1.0"}`),
            }},
        },
        Dimension_Data{
            definitions = []protocol.Dimension_Definition{{
                name = "custom:test",
                range = {320, -64},
                generator = protocol.Generator_Overworld,
                dimension_type = 1000,
            }},
        },
        Server_Store_Info{
            store_info = protocol.option(protocol.Store_Entry_Point_Info{
                store_id = "store-id",
                store_name = "Store",
            }),
        },
        Server_Presence_Info{
            presence_info = protocol.option(protocol.Presence_Info{
                experience_name = protocol.option("Experience"),
                world_name = protocol.option("World"),
                rich_presence_id = "presence-id",
            }),
        },
        Camera_Aim_Assist_Actor_Priority{
            priority_data =
                []protocol.Camera_Aim_Assist_Actor_Priority_Data{{
                    preset_index = 1,
                    category_index = 2,
                    actor_index = 3,
                    priority = 4,
                }},
        },
        Update_Abilities{
            ability_data = {
                entity_unique_id = -99,
                player_permissions = 1,
                command_permissions = 2,
                layers = []protocol.Ability_Layer{{
                    type = protocol.Ability_Layer_Type_Base,
                    abilities = u32(1 << 10) | u32(1 << 9),
                    values = u32(1 << 10),
                    fly_speed = 0.05,
                    vertical_fly_speed = 1,
                    walk_speed = 0.1,
                }},
            },
        },
        Container_Registry_Cleanup{
            removed_containers = []protocol.Full_Container_Name{{
                container_id = 0,
                dynamic_container_id = protocol.option(u32(42)),
            }},
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

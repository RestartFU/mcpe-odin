package gophertunnel_fixtures

import "core:fmt"
import nbt "mcpe:gophertunnel/minecraft/nbt"
import protocol "mcpe:gophertunnel/minecraft/protocol"
import login "mcpe:gophertunnel/minecraft/protocol/login"
import packet "mcpe:gophertunnel/minecraft/protocol/packet"
import mcpe_runtime "mcpe:runtime"

emit :: proc(name: string, data: []u8) {
    fmt.printf("%s ", name)
    for value in data {
        fmt.printf("%02x", value)
    }
    fmt.println()
}

emit_dump :: proc(name: string, root: ^nbt.Value) {
    data, encode_err := nbt.marshal(root, .Little_Endian)
    assert(encode_err == nil)
    defer delete(data)
    text, dump_err := nbt.dump(data, .Little_Endian)
    assert(dump_err == nil)
    defer delete(text)
    emit(name, transmute([]u8)text)
}

emit_identity_validation :: proc(
    name: string,
    data: login.Identity_Data,
) {
    err := login.validate_identity_data(data)
    valid := u8(1)
    if err != nil {
        valid = 0
        mcpe_runtime.destroy_error(err)
    }
    emit(name, []u8{valid})
}

emit_device_id_format :: proc(name, value: string) {
    format := login.device_id_format(login.Device_ID(value))
    emit(name, []u8{u8(format)})
}

emit_packet :: proc(
    name: string,
    value: packet.Packet,
    sender_sub_client: u8 = 0,
    target_sub_client: u8 = 0,
) {
    data, err := packet.encode_packet(
        value,
        sender_sub_client,
        target_sub_client,
    )
    assert(err == nil)
    defer delete(data)
    emit(name, data)
}

nbt_fixture :: proc() -> nbt.Value {
    list_one := nbt.new_value(nbt.value_int(1))
    list_two := nbt.new_value(nbt.value_int(-2))
    list_three := nbt.new_value(nbt.value_int(3))
    list := make([]^nbt.Value, 3)
    list[0] = list_one
    list[1] = list_two
    list[2] = list_three
    nested_value := nbt.new_value(nbt.value_string("inside"))
    nested_entries := make([]nbt.Named_Value, 1)
    nested_entries[0] = {name = "Name", value = nested_value}
    nested := nbt.new_value({
        tag = .Compound,
        compound = nested_entries,
    })
    entries := make([]nbt.Named_Value, 12)
    entries[0] = {
        name = "Byte",
        value = nbt.new_value(nbt.value_byte(0x7f)),
    }
    entries[1] = {
        name = "Short",
        value = nbt.new_value(nbt.value_short(-1234)),
    }
    entries[2] = {
        name = "Int",
        value = nbt.new_value(nbt.value_int(-123_456)),
    }
    entries[3] = {
        name = "Long",
        value = nbt.new_value(nbt.value_long(-1_234_567_890_123)),
    }
    entries[4] = {
        name = "Float",
        value = nbt.new_value(nbt.value_float(123.5)),
    }
    entries[5] = {
        name = "Double",
        value = nbt.new_value(nbt.value_double(-987.25)),
    }
    entries[6] = {
        name = "Bytes",
        value = nbt.new_value(nbt.value_byte_array([]u8{1, 2, 3, 4})),
    }
    entries[7] = {
        name = "String",
        value = nbt.new_value(nbt.value_string("Minecraft")),
    }
    entries[8] = {
        name = "List",
        value = nbt.new_value({
            tag = .List,
            list_type = .Int,
            list = list,
        }),
    }
    entries[9] = {name = "Nested", value = nested}
    entries[10] = {
        name = "Ints",
        value = nbt.new_value(nbt.value_int_array([]i32{-1, 0, 1})),
    }
    entries[11] = {
        name = "Longs",
        value = nbt.new_value(
            nbt.value_long_array([]i64{min(i64), max(i64)}),
        ),
    }
    return {tag = .Compound, compound = entries}
}

main :: proc() {
    identity := login.Identity_Data{
        xuid = "2533274790395904",
        identity = "00112233-4455-6677-8899-aabbccddeeff",
        display_name = "Steve",
    }
    emit_identity_validation("login_identity_valid", identity)
    identity.display_name = "A#"
    emit_identity_validation("login_identity_online_regex_quirk", identity)
    identity.xuid = ""
    identity.display_name = "É#"
    emit_identity_validation("login_identity_offline_unicode", identity)
    identity.display_name = "###"
    emit_identity_validation("login_identity_invalid_name", identity)
    identity.display_name = "Steve"
    identity.identity = "00000000-0000-0000-0000-000000000000"
    emit_identity_validation("login_identity_nil_uuid", identity)
    identity.identity = "00112233-4455-6677-8899-aabbccddeeff"
    identity.xuid = "not-a-number"
    emit_identity_validation("login_identity_invalid_xuid", identity)
    identity.xuid = "2533274790395904"
    identity.identity = "00112233445566778899aabbccddeeff"
    emit_identity_validation("login_identity_raw_uuid", identity)
    identity.identity = "URN:UUID:00112233-4455-6677-8899-aabbccddeeff"
    emit_identity_validation("login_identity_urn_uuid", identity)
    identity.identity = "!00112233-4455-6677-8899-aabbccddeeff?"
    emit_identity_validation("login_identity_wrapped_uuid", identity)
    identity.identity = "00112233-4455-6677-8899-aabbccddeeff"
    identity.display_name = "Steve Alex"
    emit_identity_validation("login_identity_single_space", identity)
    identity.display_name = "Steve"
    identity.xuid = "1_2"
    emit_identity_validation("login_identity_xuid_underscore", identity)
    identity.xuid = "+1"
    emit_identity_validation("login_identity_xuid_plus", identity)
    emit_device_id_format(
        "login_device_id_lower_hex",
        "ada3dfa4622f4e2fb2c14a496d52db96",
    )
    emit_device_id_format(
        "login_device_id_mixed_hex",
        "Ada3DFA4622F4E2FB2C14A496D52DB96",
    )
    emit_device_id_format(
        "login_device_id_uuid",
        "00112233-4455-6677-8899-aabbccddeeff",
    )
    emit_device_id_format(
        "login_device_id_base64",
        "VlhnpI7TuWyfHiUx3WYwFvQQHbDkv505h6VVo40Cngw=",
    )
    emit_device_id_format(
        "login_device_id_unpadded_base64",
        "VlhnpI7TuWyfHiUx3WYwFvQQHbDkv505h6VVo40Cngw",
    )
    emit_device_id_format(
        "login_device_id_invalid",
        "not-a-device-id",
    )

    output := protocol.writer()
    defer protocol.writer_destroy(&output)

    protocol.write_u16(&output, 0x1234)
    protocol.write_i16(&output, -1234)
    protocol.write_u32(&output, 0x1234_5678)
    protocol.write_i32(&output, -123_456)
    protocol.write_be_i32(&output, 0x1234_5678)
    protocol.write_u64(&output, 0x0123_4567_89ab_cdef)
    protocol.write_i64(&output, -123_456_789)
    protocol.write_f32(&output, 123.5)
    protocol.write_f64(&output, -987.25)
    protocol.write_bool(&output, true)
    protocol.write_bool(&output, false)

    varuint32_values := [?]u32{0, 1, 127, 128, 255, 300, max(u32)}
    for value in varuint32_values {
        protocol.write_varuint32(&output, value)
    }
    varint32_values := [?]i32{
        min(i32),
        -1_000_000,
        -1,
        0,
        1,
        1_000_000,
        max(i32),
    }
    for value in varint32_values {
        protocol.write_varint32(&output, value)
    }
    varuint64_values := [?]u64{0, 1, 127, 128, 300, max(u64)}
    for value in varuint64_values {
        protocol.write_varuint64(&output, value)
    }
    varint64_values := [?]i64{
        min(i64),
        -1_000_000_000_000,
        -1,
        0,
        1,
        max(i64),
    }
    for value in varint64_values {
        protocol.write_varint64(&output, value)
    }

    protocol.write_string(&output, "Minecraft")
    protocol.write_string_utf(&output, "Bedrock")
    protocol.write_byte_slice(&output, []u8{1, 2, 3, 4})
    protocol.write_vec2(&output, {1.25, -2.5})
    protocol.write_vec3(&output, {1.25, -2.5, 9.75})
    protocol.write_block_pos(&output, {-12, 64, 3456})
    protocol.write_chunk_pos(&output, {-100, 200})
    protocol.write_sub_chunk_pos(&output, {-2, 10, 44})
    protocol.write_sound_pos(&output, {1.25, -2.5, 9.75})
    protocol.write_byte_float(&output, 180)
    protocol.write_uuid(
        &output,
        {
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
        },
    )
    colour := protocol.RGBA{r = 1, g = 2, b = 3, a = 4}
    protocol.write_rgba(&output, colour)
    protocol.write_var_rgba(&output, colour)
    emit("protocol_codec", protocol.writer_bytes(&output))

    root := nbt_fixture()
    encodings := [?]nbt.Encoding{
        .Network_Little_Endian,
        .Little_Endian,
        .Network_Big_Endian,
        .Big_Endian,
    }
    names := [?]string{
        "nbt_network_little",
        "nbt_little",
        "nbt_network_big",
        "nbt_big",
    }
    for encoding, index in encodings {
        data, encode_err := nbt.marshal(&root, encoding)
        assert(encode_err == nil)
        emit(names[index], data)
        delete(data)
    }

    dump_list := nbt.value_list(
        .Int,
        []nbt.Value{
            nbt.value_int(1),
            nbt.value_int(-2),
            nbt.value_int(3),
        },
    )
    dump_root := nbt.value_compound(
        []nbt.Named_Value{nbt.named_value("Values", dump_list)},
    )
    defer nbt.destroy_value(&dump_root)
    emit_dump("nbt_dump", &dump_root)

    inner := nbt.new_value(
        nbt.value_list(.Int, []nbt.Value{nbt.value_int(1)}),
    )
    nested_children := make([]^nbt.Value, 1)
    nested_children[0] = inner
    nested_root := nbt.value_compound(
        []nbt.Named_Value{
            nbt.named_value(
                "Values",
                {
                    tag = .List,
                    list_type = .List,
                    list = nested_children,
                },
            ),
        },
    )
    defer nbt.destroy_value(&nested_root)
    emit_dump("nbt_dump_nested", &nested_root)

    empty_string_root := nbt.value_compound(
        []nbt.Named_Value{
            nbt.named_value(
                "Values",
                {tag = .List, list_type = .String},
            ),
        },
    )
    defer nbt.destroy_value(&empty_string_root)
    emit_dump("nbt_dump_empty_string", &empty_string_root)

    empty_int_root := nbt.value_compound(
        []nbt.Named_Value{
            nbt.named_value(
                "Values",
                {tag = .List, list_type = .Int},
            ),
        },
    )
    defer nbt.destroy_value(&empty_int_root)
    emit_dump("nbt_dump_empty_int", &empty_int_root)

    emit_packet(
        "packet_request_network_settings",
        packet.Request_Network_Settings{client_protocol = 1001},
        2,
        3,
    )
    emit_packet(
        "packet_network_settings",
        packet.Network_Settings{
            compression_threshold = 256,
            compression_algorithm = packet.Compression_Algorithm_Snappy,
            client_throttle = true,
            client_throttle_threshold = 12,
            client_throttle_scalar = 0.75,
        },
    )
    emit_packet(
        "packet_disconnect",
        packet.Disconnect{
            reason = 57,
            message = "Disconnected",
            filtered_message = "Filtered",
        },
    )
    emit_packet(
        "packet_disconnect_hidden",
        packet.Disconnect{
            reason = 57,
            hide_disconnection_screen = true,
        },
    )
    emit_packet(
        "packet_set_time",
        packet.Set_Time{time = -12_345},
    )
    emit_packet(
        "packet_network_stack_latency",
        packet.Network_Stack_Latency{
            timestamp = -1_234_567_890,
            needs_response = true,
        },
    )
    emit_packet(
        "packet_set_spawn_position",
        packet.Set_Spawn_Position{
            spawn_type = packet.Spawn_Type_World,
            position = {-12, 64, 3456},
            dimension = 2,
            spawn_position = {-100, 70, 200},
        },
    )
    emit_packet(
        "packet_respawn",
        packet.Respawn{
            position = {1.25, -2.5, 9.75},
            state = packet.Respawn_State_Client_Ready_To_Spawn,
            entity_runtime_id = 0x1234_5678,
        },
    )
    emit_packet(
        "packet_player_hot_bar",
        packet.Player_Hot_Bar{
            selected_hot_bar_slot = 7,
            window_id = 3,
            select_hot_bar_slot = true,
        },
    )
    emit_packet(
        "packet_set_commands_enabled",
        packet.Set_Commands_Enabled{enabled = true},
    )
    emit_packet(
        "packet_set_player_game_type",
        packet.Set_Player_Game_Type{
            game_type = packet.Game_Type_Spectator,
        },
    )
    emit_packet(
        "packet_simple_event",
        packet.Simple_Event{
            event_type = packet.Simple_Event_Commands_Disabled,
        },
    )
    emit_packet(
        "packet_spawn_experience_orb",
        packet.Spawn_Experience_Orb{
            position = {-1.5, 64.25, 100.75},
            experience_amount = 2477,
        },
    )
    emit_packet(
        "packet_show_credits",
        packet.Show_Credits{
            player_runtime_id = 0x1020_3040,
            status_type = packet.Show_Credits_Status_End,
        },
    )
    emit_packet(
        "packet_transfer",
        packet.Transfer{
            address = "example.org",
            port = 19132,
            reload_world = true,
        },
    )
    emit_packet(
        "packet_stop_sound",
        packet.Stop_Sound{
            sound_name = "music.game",
            stop_music_legacy = true,
        },
    )
    emit_packet(
        "packet_set_last_hurt_by",
        packet.Set_Last_Hurt_By{entity_type = -17},
    )
    emit_packet(
        "packet_set_default_game_type",
        packet.Set_Default_Game_Type{
            game_type = packet.Game_Type_Creative,
        },
    )
    emit_packet(
        "packet_change_dimension",
        packet.Change_Dimension{
            dimension = packet.Dimension_Nether,
            position = {8.5, 72.25, -3.75},
            respawn = true,
            loading_screen_id = protocol.option(u32(0x1234_5678)),
        },
    )
    emit_packet(
        "packet_change_dimension_without_loading_screen",
        packet.Change_Dimension{
            dimension = packet.Dimension_End,
            position = {0, 80, 0},
        },
    )
    emit_packet(
        "packet_server_bound_loading_screen",
        packet.Server_Bound_Loading_Screen{
            type = packet.Loading_Screen_Type_Start,
            loading_screen_id = protocol.option(u32(0x1234_5678)),
        },
    )
    emit_packet(
        "packet_server_bound_loading_screen_without_id",
        packet.Server_Bound_Loading_Screen{
            type = packet.Loading_Screen_Type_End,
        },
    )
    emit_packet(
        "packet_remove_actor",
        packet.Remove_Actor{entity_unique_id = -0x1020_3040},
    )
    emit_packet(
        "packet_take_item_actor",
        packet.Take_Item_Actor{
            item_entity_runtime_id = 0x1020,
            taker_entity_runtime_id = 0x3040,
        },
    )
    emit_packet(
        "packet_block_pick_request",
        packet.Block_Pick_Request{
            position = {-12, 64, 3456},
            add_block_nbt = true,
            hot_bar_slot = 7,
        },
    )
    emit_packet(
        "packet_actor_pick_request",
        packet.Actor_Pick_Request{
            entity_unique_id = -0x0102_0304_0506_0708,
            hot_bar_slot = 8,
            with_data = true,
        },
    )
    emit_packet(
        "packet_set_actor_motion",
        packet.Set_Actor_Motion{
            entity_runtime_id = 0x1020_3040,
            velocity = {1.25, -2.5, 9.75},
            tick = 123_456,
        },
    )
    form_data := `{"type":"modal"}`
    emit_packet(
        "packet_modal_form_request",
        packet.Modal_Form_Request{
            form_id = 42,
            form_data = transmute([]u8)form_data,
        },
    )
    emit_packet(
        "packet_show_profile",
        packet.Show_Profile{xuid = "2533274790395904"},
    )
    emit_packet(
        "packet_remove_objective",
        packet.Remove_Objective{objective_name = "kills"},
    )
    emit_packet(
        "packet_set_local_player_as_initialised",
        packet.Set_Local_Player_As_Initialised{
            entity_runtime_id = 0x1234_5678,
        },
    )
    emit_packet(
        "packet_update_player_game_type",
        packet.Update_Player_Game_Type{
            game_type = packet.Game_Type_Adventure,
            player_unique_id = -123_456,
            tick = 98_765,
        },
    )
    emit_packet(
        "packet_filter_text",
        packet.Filter_Text{text = "hello", from_server = true},
    )
    emit_packet(
        "packet_simulation_type",
        packet.Simulation_Type{
            simulation_type = packet.Simulation_Type_Test,
        },
    )
    emit_packet(
        "packet_toast_request",
        packet.Toast_Request{title = "Title", message = "Message"},
    )
    emit_packet(
        "packet_award_achievement",
        packet.Award_Achievement{achievement_id = -1234},
    )
    emit_packet(
        "packet_client_bound_close_form",
        packet.Client_Bound_Close_Form{},
    )
    emit_packet(
        "packet_login",
        packet.Login{
            client_protocol = 1001,
            connection_request = []u8{1, 2, 3, 4},
        },
    )
    emit_packet(
        "packet_resource_pack_client_response",
        packet.Resource_Pack_Client_Response{
            response = packet.Pack_Response_Send_Packs,
            packs_to_download = []string{
                "pack-one_1.0.0",
                "pack-two_2.0.0",
            },
        },
    )
    emit_packet(
        "packet_resource_pack_data_info",
        packet.Resource_Pack_Data_Info{
            uuid = "d2d3a4b5-c6d7-48e9-a001-020304050607",
            data_chunk_size = 1_048_576,
            chunk_count = 16,
            size = 15_500_000,
            hash = []u8{0xde, 0xad, 0xbe, 0xef},
            premium = true,
            pack_type = packet.Resource_Pack_Type_Resources,
        },
    )
    emit_packet(
        "packet_resource_pack_chunk_data",
        packet.Resource_Pack_Chunk_Data{
            uuid = "d2d3a4b5-c6d7-48e9-a001-020304050607",
            chunk_index = 7,
            data_offset = 7 * 1_048_576,
            data = []u8{9, 8, 7, 6},
        },
    )
    emit_packet(
        "packet_resource_pack_chunk_request",
        packet.Resource_Pack_Chunk_Request{
            uuid = "d2d3a4b5-c6d7-48e9-a001-020304050607",
            chunk_index = -1,
        },
    )
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
    emit_packet(
        "packet_resource_packs_info",
        packet.Resource_Packs_Info{
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
    )
    emit_packet(
        "packet_resource_pack_stack",
        packet.Resource_Pack_Stack{
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
    )
    emit_packet(
        "packet_text_raw",
        packet.Text{
            text_type = packet.Text_Type_Raw,
            message = "raw message",
        },
    )
    emit_packet(
        "packet_text_chat",
        packet.Text{
            text_type = packet.Text_Type_Chat,
            source_name = "Steve",
            message = "hello",
            xuid = "2533274790395904",
            platform_chat_id = "platform",
            filtered_message = protocol.option(string("filtered hello")),
        },
    )
    emit_packet(
        "packet_text_translation",
        packet.Text{
            text_type = packet.Text_Type_Translation,
            needs_translation = true,
            message = "chat.type.text",
            parameters = []string{"Steve", "hello"},
        },
    )
    emit_packet(
        "packet_set_title",
        packet.Set_Title{
            action_type = packet.Title_Action_Set_Title,
            text = "Welcome",
            fade_in_duration = 10,
            remain_duration = 70,
            fade_out_duration = 20,
            xuid = "2533274790395904",
            platform_online_id = "1234",
            filtered_message = "Filtered Welcome",
        },
    )
    emit_packet(
        "packet_show_store_offer",
        packet.Show_Store_Offer{
            offer_id = pack_uuid,
            type = packet.Store_Offer_Type_Dressing_Room,
        },
    )
    emit_packet(
        "packet_purchase_receipt",
        packet.Purchase_Receipt{
            receipts = []string{"receipt-one", "receipt-two"},
        },
    )
    emit_packet(
        "packet_modal_form_response",
        packet.Modal_Form_Response{
            form_id = 42,
            response_data = protocol.option([]u8{1, 2, 3}),
            cancel_reason = protocol.option(
                packet.Modal_Form_Cancel_Reason_User_Busy,
            ),
        },
    )
    emit_packet(
        "packet_server_settings_request",
        packet.Server_Settings_Request{},
    )
    emit_packet(
        "packet_server_settings_response",
        packet.Server_Settings_Response{
            form_id = 43,
            form_data = []u8{4, 5, 6},
        },
    )
    emit_packet(
        "packet_settings_command",
        packet.Settings_Command{
            command_line = "gamerule showcoordinates true",
            suppress_output = true,
        },
    )
    emit_packet(
        "packet_ui_reload",
        packet.Client_Bound_Data_Driven_UI_Reload{},
    )
    emit_packet(
        "packet_refresh_entitlements",
        packet.Refresh_Entitlements{},
    )
    emit_packet(
        "packet_packs_ready_validation",
        packet.Resource_Packs_Ready_For_Validation{},
    )
    emit_packet(
        "packet_ticking_areas",
        packet.Ticking_Areas_Load_Status{preload = true},
    )
    emit_packet(
        "packet_behaviour_tree",
        packet.Add_Behaviour_Tree{behaviour_tree = "tree"},
    )
    emit_packet(
        "packet_item_cooldown",
        packet.Client_Start_Item_Cooldown{
            category = "ender_pearl",
            duration = -20,
        },
    )
    emit_packet(
        "packet_remove_volume",
        packet.Remove_Volume_Entity{
            entity_runtime_id = 12345,
            dimension = -1,
        },
    )
    emit_packet(
        "packet_screen_animation",
        packet.On_Screen_Texture_Animation{
            animation_type = 0x1234_5678,
        },
    )
    emit_packet(
        "packet_automation_connect",
        packet.Automation_Client_Connect{
            server_uri = "localhost:8000/ws",
        },
    )
    emit_packet(
        "packet_photo_info",
        packet.Photo_Info_Request{photo_id = -123_456_789},
    )
    emit_packet(
        "packet_map_locked_copy",
        packet.Map_Create_Locked_Copy{
            original_map_id = -7,
            new_map_id = 9001,
        },
    )
    emit_packet(
        "packet_script_message",
        packet.Script_Message{
            identifier = "mcpe:test",
            data = []u8{0, 1, 2, 255},
        },
    )
    emit_packet(
        "packet_open_sign",
        packet.Open_Sign{
            position = {-12, 64, 3456},
            front_side = true,
        },
    )
    emit_packet(
        "packet_ui_close_screen",
        packet.Client_Bound_Data_Driven_UI_Close_Screen{
            form_id = protocol.option(u32(42)),
        },
    )
    emit_packet(
        "packet_actor_identifiers",
        packet.Available_Actor_Identifiers{
            serialised_entity_identifiers = []u8{10, 0, 0},
        },
    )
    emit_packet(
        "packet_current_structure",
        packet.Current_Structure_Feature{
            current_feature = "minecraft:village",
        },
    )
    emit_packet(
        "packet_server_stats",
        packet.Server_Stats{
            server_time = 12.5,
            network_time = 3.25,
        },
    )
    emit_packet(
        "packet_anvil_damage",
        packet.Anvil_Damage{
            damage = 2,
            anvil_position = {-12, 64, 3456},
        },
    )
    emit_packet(
        "packet_debug_info",
        packet.Debug_Info{
            player_unique_id = -99,
            data = []u8{4, 5, 6},
        },
    )
    emit_packet(
        "packet_create_photo",
        packet.Create_Photo{
            entity_unique_id = -7,
            photo_name = "photo",
            item_name = "portfolio",
        },
    )
    emit_packet(
        "packet_code_builder",
        packet.Code_Builder{
            url = "ws://localhost:8080",
            should_open_code_builder = true,
        },
    )
    emit_packet(
        "packet_education_resource",
        packet.Education_Resource_URI{
            resource = {
                button_name = "Learn",
                link_uri = "https://example.org/lesson",
            },
        },
    )
    emit_packet(
        "packet_player_fog",
        packet.Player_Fog{
            stack = []string{"minecraft:fog_ocean", "custom:fog"},
        },
    )
    emit_packet(
        "packet_death_info",
        packet.Death_Info{
            cause = "suffocation",
            messages = []string{"one", "two"},
        },
    )
    emit_packet(
        "packet_client_cache_status",
        packet.Client_Cache_Status{enabled = true},
    )
    emit_packet(
        "packet_level_event_generic",
        packet.Level_Event_Generic{
            event_id = 2026,
            serialised_event_data = []u8{1, 2, 3},
        },
    )
    emit_packet(
        "packet_container_close",
        packet.Container_Close{
            window_id = 4,
            container_type = 12,
            server_side = true,
        },
    )
    emit_packet(
        "packet_container_set_data",
        packet.Container_Set_Data{
            window_id = 5,
            key = -2,
            value = 300,
        },
    )
    emit_packet(
        "packet_gui_pick_item",
        packet.GUI_Data_Pick_Item{
            item_name = "Sword",
            item_effects = "+7 Attack",
            hot_bar_slot = -1,
        },
    )
    emit_packet(
        "packet_completed_item",
        packet.Completed_Using_Item{
            used_item_id = -1234,
            use_method = 1,
        },
    )
    emit_packet(
        "packet_agent_animation",
        packet.Agent_Animation{
            animation = 7,
            entity_runtime_id = u64(1) << 40 | 9,
        },
    )
    emit_packet(
        "packet_camera",
        packet.Camera{
            camera_entity_unique_id = -7,
            target_player_unique_id = 9001,
        },
    )
    emit_packet(
        "packet_update_sound_data",
        packet.Clientbound_Update_Sound_Data{
            server_sound_handle = 0x0123_4567_89ab_cdef,
            sound_event = packet.Sound_Data_Event_Stop,
        },
    )
    emit_packet(
        "packet_game_test_results",
        packet.Game_Test_Results{
            name = "test:name",
            succeeded = false,
            error = "failed",
        },
    )
    emit_packet(
        "packet_hurt_armour",
        packet.Hurt_Armour{cause = -2, damage = 7, armour_slots = 0x11},
    )
    emit_packet(
        "packet_lesson_progress",
        packet.Lesson_Progress{
            identifier = "lesson.one",
            action = packet.Lesson_Action_Complete,
            score = 99,
        },
    )
    emit_packet(
        "packet_motion_hints",
        packet.Motion_Prediction_Hints{
            entity_runtime_id = u64(1) << 40 | 10,
            velocity = {1.25, -2.5, 3.75},
            on_ground = true,
        },
    )
    emit_packet(
        "packet_multiplayer_settings",
        packet.Multi_Player_Settings{
            action_type = packet.Refresh_Join_Code,
        },
    )
    emit_packet(
        "packet_violation_warning",
        packet.Packet_Violation_Warning{
            type = packet.Violation_Type_Malformed,
            severity = packet.Violation_Severity_Final_Warning,
            packet_id = 42,
            violation_context = "bad payload",
        },
    )
    emit_packet(
        "packet_request_permissions",
        packet.Request_Permissions{
            entity_unique_id = -9001,
            permission_level = 2,
            requested_permissions = 0x1234,
        },
    )
    emit_packet(
        "packet_update_adventure",
        packet.Update_Adventure_Settings{
            no_pvm = true,
            no_mvp = false,
            immutable_world = true,
            show_name_tags = false,
            auto_jump = true,
        },
    )
    emit_packet(
        "packet_input_locks",
        packet.Update_Client_Input_Locks{
            locks = packet.Client_Input_Lock_Camera |
                    packet.Client_Input_Lock_Jump,
        },
    )
    emit_packet(
        "packet_client_options",
        packet.Update_Client_Options{
            graphics_mode = protocol.option(
                packet.Graphics_Mode_Advanced,
            ),
            filter_profanity = protocol.option(true),
        },
    )
    emit_packet(
        "packet_actor_event",
        packet.Actor_Event{
            entity_runtime_id = u64(1) << 40 | 11,
            event_type = 2,
            event_data = -3,
            fire_at_position = protocol.option(protocol.Vec3{1, 2, 3}),
        },
    )
    emit_packet(
        "packet_agent_action",
        packet.Agent_Action{
            identifier = "action-id",
            action = 4,
            response = []u8{1, 2, 3},
        },
    )
    emit_packet(
        "packet_block_event",
        packet.Block_Event{
            position = {-12, 64, 3456},
            event_type = 1,
            event_data = 1,
        },
    )
    emit_packet(
        "packet_camera_shake",
        packet.Camera_Shake{
            intensity = 2.5,
            duration = 4.25,
            type = 1,
            action = 0,
        },
    )
    emit_packet(
        "packet_code_builder_source",
        packet.Code_Builder_Source{
            operation = 2,
            category = 1,
            code_status = 5,
        },
    )
    emit_packet(
        "packet_emote",
        packet.Emote{
            entity_runtime_id = u64(1) << 40 | 12,
            emote_length = 80,
            emote_id = "emote-id",
            xuid = "1234",
            platform_id = "platform",
            flags = 3,
        },
    )
    emit_packet(
        "packet_game_test_request",
        packet.Game_Test_Request{
            name = "test:name",
            rotation = 2,
            repetitions = 3,
            position = {-12, 64, 3456},
            stop_on_error = true,
            tests_per_row = 4,
            max_tests_per_batch = 5,
        },
    )
    emit_packet(
        "packet_lab_table",
        packet.Lab_Table{
            action_type = 1,
            position = {-12, 64, 3456},
            reaction_type = 7,
        },
    )
    emit_packet(
        "packet_lectern_update",
        packet.Lectern_Update{
            page = 2,
            page_count = 10,
            position = {-12, 64, 3456},
        },
    )
    emit_packet(
        "packet_npc_request",
        packet.NPC_Request{
            entity_runtime_id = u64(1) << 40 | 13,
            request_type = 1,
            command_string = "/say hello",
            action_type = 2,
            scene_name = "scene",
        },
    )
    emit_packet(
        "packet_player_action",
        packet.Player_Action{
            entity_runtime_id = u64(1) << 40 | 14,
            action_type = -2,
            block_position = {-12, 64, 3456},
            result_position = {-11, 65, 3457},
            block_face = 3,
        },
    )
    emit_packet(
        "packet_spawn_particle",
        packet.Spawn_Particle_Effect{
            dimension = 2,
            entity_unique_id = -1,
            position = {1.25, 2.5, 3.75},
            particle_name = "minecraft:test",
            molang_variables = protocol.option(
                transmute([]u8)string(`{"x":1}`),
            ),
        },
    )
    emit_packet(
        "packet_cache_blob_status",
        packet.Client_Cache_Blob_Status{
            miss_hashes = []u64{1, 0x0123_4567_89ab_cdef},
            hit_hashes = []u64{2, 3},
        },
    )
    emit_packet(
        "packet_data_ui_show",
        packet.Client_Bound_Data_Driven_UI_Show_Screen{
            screen_id = "screen:test",
            form_id = 42,
            data_instance_id = protocol.option(u32(99)),
        },
    )
    emit_packet(
        "packet_sub_client_login",
        packet.Sub_Client_Login{
            connection_request = []u8{1, 2, 3, 4},
        },
    )
    emit_packet(
        "packet_script_custom_event",
        packet.Script_Custom_Event{
            event_name = "test:event",
            event_data = []u8{4, 5, 6},
        },
    )
    emit_packet(
        "packet_emote_list",
        packet.Emote_List{
            player_runtime_id = u64(1) << 40 | 15,
            emote_pieces = []protocol.UUID{pack_uuid},
        },
    )
    emit_packet(
        "packet_party_cookie",
        packet.Send_Party_Destination_Cookie{
            cookie = "opaque",
            intent = "OptIn",
            destination_name = "server",
        },
    )
    emit_packet(
        "packet_toggle_crafter",
        packet.Player_Toggle_Crafter_Slot_Request{
            pos_x = -12,
            pos_y = 64,
            pos_z = 3456,
            slot = 8,
            disabled = true,
        },
    )
    emit_packet(
        "packet_client_aim_assist",
        packet.Client_Camera_Aim_Assist{
            preset_id = "preset",
            action = 1,
            allow_aim_assist = true,
        },
    )
    emit_packet(
        "packet_data_screen_closed",
        packet.Server_Bound_Data_Driven_Screen_Closed{
            form_id = 42,
            close_reason = "userbusy",
        },
    )
    emit_packet(
        "packet_position_tracking_request",
        packet.Position_Tracking_DB_Client_Request{
            request_action = 0,
            tracking_id = -99,
        },
    )
    emit_packet(
        "packet_party_changed",
        packet.Party_Changed{
            party_info = protocol.option(packet.Party_Info{
                party_id = "party",
                party_leader = true,
            }),
        },
    )
    emit_packet(
        "packet_party_cookie_response",
        packet.Party_Destination_Cookie_Response{
            cookie = "opaque",
            accepted = true,
        },
    )
    emit_packet(
        "packet_control_scheme_set",
        packet.Client_Bound_Control_Scheme_Set{
            control_scheme = packet.Control_Scheme_Camera_Relative_Strafe,
        },
    )
    emit_packet(
        "packet_movement_effect",
        packet.Movement_Effect{
            entity_runtime_id = u64(1) << 40 | 16,
            type = packet.Movement_Effect_Type_Dolphin_Boost,
            duration = 40,
            tick = 123456,
        },
    )
    emit_packet(
        "packet_player_video_capture",
        packet.Player_Video_Capture{
            action = packet.Player_Video_Capture_Action_Start,
            frame_rate = 60,
            file_prefix = "capture-",
        },
    )
    emit_packet(
        "packet_player_location",
        packet.Player_Location{
            type = packet.Player_Location_Type_Coordinates,
            entity_unique_id = -99,
            position = {1.25, 2.5, 3.75},
        },
    )
    emit_packet(
        "packet_texture_shift",
        packet.Client_Bound_Texture_Shift{
            action_id = packet.Texture_Shift_Action_Sync,
            collection_name = "collection",
            from_step = "one",
            to_step = "two",
            all_steps = []string{"one", "two"},
            current_length_ticks = 10,
            total_length_ticks = 20,
            enabled = true,
        },
    )
    emit_packet(
        "packet_set_hud",
        packet.Set_Hud{
            elements = []i32{
                packet.Hud_Element_Crosshair,
                packet.Hud_Element_Hot_Bar,
            },
            visibility = packet.Hud_Visibility_Hide,
        },
    )
    emit_packet(
        "packet_inventory_options",
        packet.Set_Player_Inventory_Options{
            left_inventory_tab = packet.Inventory_Left_Tab_Search,
            right_inventory_tab = packet.Inventory_Right_Tab_Crafting,
            filtering = true,
            inventory_layout = packet.Inventory_Layout_Default,
            crafting_layout = packet.Inventory_Layout_Recipe_Book_Only,
        },
    )
    emit_packet(
        "packet_entity_overrides",
        packet.Player_Update_Entity_Overrides{
            entity_unique_id = -99,
            property_index = 7,
            type = packet.Player_Update_Entity_Overrides_Type_Float,
            float_value = 2.5,
        },
    )
    emit_packet(
        "packet_camera_aim_assist",
        packet.Camera_Aim_Assist{
            preset = "preset",
            angle = {12.5, 8.25},
            distance = 32,
            target_mode = 1,
            action = packet.Camera_Aim_Assist_Action_Set,
            show_debug_render = true,
        },
    )
    emit_packet(
        "packet_change_mob_property",
        packet.Change_Mob_Property{
            entity_unique_id = -99,
            property = "minecraft:test",
            bool_value = true,
            string_value = "value",
            int_value = -7,
            float_value = 2.5,
        },
    )
    emit_packet(
        "packet_mob_effect",
        packet.Mob_Effect{
            entity_runtime_id = u64(1) << 40 | 17,
            operation = 1,
            effect_type = 1,
            amplifier = 2,
            particles = true,
            duration = 600,
            tick = 123456,
            ambient = false,
        },
    )

    batch_time, batch_time_err := packet.encode_packet(
        packet.Set_Time{time = 42},
    )
    assert(batch_time_err == nil)
    defer delete(batch_time)
    batch_settings, batch_settings_err := packet.encode_packet(
        packet.Request_Network_Settings{client_protocol = 1001},
    )
    assert(batch_settings_err == nil)
    defer delete(batch_settings)
    batch, batch_err := packet.encode_batch(
        [][]u8{batch_time, batch_settings},
    )
    assert(batch_err == nil)
    defer delete(batch)
    emit("packet_batch", batch)

    go_flate := []u8{
        0xed, 0xca, 0xc1, 0x0d, 0x00, 0x10, 0x0c, 0x40,
        0xd1, 0x55, 0x3a, 0x8b, 0xbb, 0x21, 0xa4, 0x2a,
        0x11, 0xa1, 0x52, 0xf6, 0x8f, 0x93, 0x2d, 0xfe,
        0x3b, 0xbf, 0xdc, 0x97, 0x69, 0x94, 0x76, 0x25,
        0x59, 0x0d, 0xd7, 0x21, 0xbb, 0xe8, 0xb0, 0x2b,
        0xea, 0x73, 0x87, 0x9d, 0xd3, 0x7d, 0x49, 0x26,
        0x91, 0x48, 0x24, 0x12, 0x89, 0x44, 0x22, 0xfd,
        0xf4, 0x00,
    }
    go_flate_decoded, go_flate_err := packet.decompress_flate(
        go_flate,
        2368,
    )
    assert(go_flate_err == nil)
    defer delete(go_flate_decoded)
    emit("flate_go_to_odin", go_flate_decoded)

    odin_flate_text := "Odin raw DEFLATE"
    odin_flate_input := transmute([]u8)odin_flate_text
    odin_flate, odin_flate_err := packet.compress_flate(
        odin_flate_input,
    )
    assert(odin_flate_err == nil)
    defer delete(odin_flate)
    odin_flate_decoded, odin_decode_err := packet.decompress_flate(
        odin_flate,
        len(odin_flate_input),
    )
    assert(odin_decode_err == nil)
    defer delete(odin_flate_decoded)
    emit("flate_odin_to_go", odin_flate_decoded)
}

package gt_packet

import "core:mem"
import protocol "mcpe:gophertunnel/minecraft/protocol"
import mcpe_runtime "mcpe:runtime"

Compression_Algorithm_Flate  :: u16(0)
Compression_Algorithm_Snappy :: u16(1)
Compression_Algorithm_None   :: u16(0xffff)

Play_Status_Login_Success                :: i32(0)
Play_Status_Login_Failed_Client          :: i32(1)
Play_Status_Login_Failed_Server          :: i32(2)
Play_Status_Player_Spawn                 :: i32(3)
Play_Status_Login_Failed_Invalid_Tenant  :: i32(4)
Play_Status_Login_Failed_Vanilla_Edu     :: i32(5)
Play_Status_Login_Failed_Edu_Vanilla     :: i32(6)
Play_Status_Login_Failed_Server_Full     :: i32(7)
Play_Status_Login_Failed_Editor_Vanilla  :: i32(8)
Play_Status_Login_Failed_Vanilla_Editor  :: i32(9)

Play_Status :: struct {
    status: i32,
}

Server_To_Client_Handshake :: struct {
    jwt: []u8,
}

Client_To_Server_Handshake :: struct {}

Disconnect :: struct {
    reason:                    i32,
    hide_disconnection_screen: bool,
    message:                   string,
    filtered_message:          string,
}

Set_Time :: struct {
    time: i32,
}

Set_Health :: struct {
    health: i32,
}

Set_Difficulty :: struct {
    difficulty: u32,
}

Request_Chunk_Radius :: struct {
    chunk_radius:     i32,
    max_chunk_radius: u8,
}

Chunk_Radius_Updated :: struct {
    chunk_radius: i32,
}

Network_Stack_Latency :: struct {
    timestamp:      i64,
    needs_response: bool,
}

Network_Settings :: struct {
    compression_threshold:      u16,
    compression_algorithm:      u16,
    client_throttle:            bool,
    client_throttle_threshold:  u8,
    client_throttle_scalar:     f32,
}

Request_Network_Settings :: struct {
    client_protocol: i32,
}

modeled_packet_id :: proc(id: u32) -> bool {
    switch id {
    case IDLogin,
         IDPlayStatus,
         IDServerToClientHandshake,
         IDClientToServerHandshake,
         IDDisconnect,
         IDResourcePacksInfo,
         IDResourcePackStack,
         IDResourcePackClientResponse,
         IDText,
         IDSetTime,
         IDRemoveActor,
         IDTakeItemActor,
         IDBlockPickRequest,
         IDActorPickRequest,
         IDSetActorMotion,
         IDSetHealth,
         IDSetSpawnPosition,
         IDRespawn,
         IDPlayerHotBar,
         IDSetCommandsEnabled,
         IDSetDifficulty,
         IDChangeDimension,
         IDSetPlayerGameType,
         IDSimpleEvent,
         IDSpawnExperienceOrb,
         IDRequestChunkRadius,
         IDChunkRadiusUpdated,
         IDShowCredits,
         IDResourcePackDataInfo,
         IDResourcePackChunkData,
         IDResourcePackChunkRequest,
         IDTransfer,
         IDStopSound,
         IDSetTitle,
         IDShowStoreOffer,
         IDPurchaseReceipt,
         IDSetLastHurtBy,
         IDModalFormRequest,
         IDModalFormResponse,
         IDServerSettingsRequest,
         IDServerSettingsResponse,
         IDShowProfile,
         IDSetDefaultGameType,
         IDRemoveObjective,
         IDSetLocalPlayerAsInitialised,
         IDNetworkStackLatency,
         IDSettingsCommand,
         IDNetworkSettings,
         IDUpdatePlayerGameType,
         IDFilterText,
         IDSimulationType,
         IDToastRequest,
         IDRequestNetworkSettings,
         IDAwardAchievement,
         IDClientBoundCloseForm,
         IDServerBoundLoadingScreen,
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
         IDCompletedUsingItem:
        return true
    }
    return false
}

write_payload :: proc(
    output: ^protocol.Writer,
    value: Packet,
) -> mcpe_runtime.Error {
    switch packet in value {
    case Login:
        protocol.write_be_i32(output, packet.client_protocol)
        protocol.write_byte_slice(output, packet.connection_request)
    case Play_Status:
        protocol.write_be_i32(output, packet.status)
    case Server_To_Client_Handshake:
        protocol.write_byte_slice(output, packet.jwt)
    case Client_To_Server_Handshake:
    case Disconnect:
        protocol.write_varint32(output, packet.reason)
        protocol.write_bool(output, packet.hide_disconnection_screen)
        if !packet.hide_disconnection_screen {
            protocol.write_string(output, packet.message)
            protocol.write_string(output, packet.filtered_message)
        }
    case Resource_Packs_Info:
        if len(packet.texture_packs) > protocol.MAX_COLLECTION_ELEMENTS {
            return packet_error(
                .Limit_Exceeded,
                "gophertunnel.packet.write",
                "texture pack list exceeds entry limit",
            )
        }
        protocol.write_bool(output, packet.texture_pack_required)
        protocol.write_bool(output, packet.has_addons)
        protocol.write_bool(output, packet.has_scripts)
        protocol.write_bool(output, packet.force_disable_vibrant_visuals)
        protocol.write_uuid(output, packet.world_template_uuid)
        protocol.write_string(output, packet.world_template_version)
        protocol.write_u16(output, u16(len(packet.texture_packs)))
        for pack in packet.texture_packs {
            protocol.write_texture_pack_info(output, pack)
        }
    case Resource_Pack_Stack:
        if len(packet.texture_packs) > protocol.MAX_COLLECTION_ELEMENTS ||
           len(packet.experiments) > protocol.MAX_COLLECTION_ELEMENTS {
            return packet_error(
                .Limit_Exceeded,
                "gophertunnel.packet.write",
                "resource pack stack exceeds entry limit",
            )
        }
        protocol.write_bool(output, packet.texture_pack_required)
        protocol.write_varuint32(output, u32(len(packet.texture_packs)))
        for pack in packet.texture_packs {
            protocol.write_stack_resource_pack(output, pack)
        }
        protocol.write_string(output, packet.base_game_version)
        protocol.write_u32(output, u32(len(packet.experiments)))
        for experiment in packet.experiments {
            protocol.write_experiment_data(output, experiment)
        }
        protocol.write_bool(
            output,
            packet.experiments_previously_toggled,
        )
        protocol.write_bool(output, packet.include_editor_packs)
    case Resource_Pack_Client_Response:
        if len(packet.packs_to_download) >
           MAX_RESOURCE_PACK_RESPONSE_ENTRIES {
            return packet_error(
                .Limit_Exceeded,
                "gophertunnel.packet.write",
                "resource pack response exceeds entry limit",
            )
        }
        protocol.write_u8(output, packet.response)
        protocol.write_u16(output, u16(len(packet.packs_to_download)))
        for entry in packet.packs_to_download {
            protocol.write_string(output, entry)
        }
    case Text:
        if !valid_text_type(packet.text_type) {
            return packet_error(
                .Invalid_Argument,
                "gophertunnel.packet.write",
                "unknown text type",
            )
        }
        if len(packet.message) == 0 {
            return packet_error(
                .Invalid_Argument,
                "gophertunnel.packet.write",
                "message cannot be empty",
            )
        }
        if text_type_has_parameters(packet.text_type) &&
           len(packet.parameters) > protocol.MAX_COLLECTION_ELEMENTS {
            return packet_error(
                .Limit_Exceeded,
                "gophertunnel.packet.write",
                "text parameter list exceeds entry limit",
            )
        }
        protocol.write_bool(output, packet.needs_translation)
        protocol.write_u8(output, text_category(packet.text_type))
        protocol.write_u8(output, packet.text_type)
        switch packet.text_type {
        case Text_Type_Chat, Text_Type_Whisper, Text_Type_Announcement:
            protocol.write_string(output, packet.source_name)
            protocol.write_string(output, packet.message)
        case Text_Type_Raw,
             Text_Type_Tip,
             Text_Type_System,
             Text_Type_Object,
             Text_Type_Object_Whisper,
             Text_Type_Object_Announcement:
            protocol.write_string(output, packet.message)
        case Text_Type_Translation,
             Text_Type_Popup,
             Text_Type_Jukebox_Popup:
            protocol.write_string(output, packet.message)
            protocol.write_varuint32(output, u32(len(packet.parameters)))
            for parameter in packet.parameters {
                protocol.write_string(output, parameter)
            }
        }
        protocol.write_string(output, packet.xuid)
        protocol.write_string(output, packet.platform_chat_id)
        protocol.write_bool(output, packet.filtered_message.set)
        if packet.filtered_message.set {
            protocol.write_string(output, packet.filtered_message.value)
        }
    case Set_Time:
        protocol.write_varint32(output, packet.time)
    case Remove_Actor:
        protocol.write_varint64(output, packet.entity_unique_id)
    case Take_Item_Actor:
        protocol.write_varuint64(output, packet.item_entity_runtime_id)
        protocol.write_varuint64(output, packet.taker_entity_runtime_id)
    case Block_Pick_Request:
        protocol.write_block_pos(output, packet.position)
        protocol.write_bool(output, packet.add_block_nbt)
        protocol.write_u8(output, packet.hot_bar_slot)
    case Actor_Pick_Request:
        protocol.write_i64(output, packet.entity_unique_id)
        protocol.write_u8(output, packet.hot_bar_slot)
        protocol.write_bool(output, packet.with_data)
    case Set_Actor_Motion:
        protocol.write_varuint64(output, packet.entity_runtime_id)
        protocol.write_vec3(output, packet.velocity)
        protocol.write_varuint64(output, packet.tick)
    case Set_Health:
        protocol.write_varint32(output, packet.health)
    case Set_Spawn_Position:
        protocol.write_varint32(output, packet.spawn_type)
        protocol.write_block_pos(output, packet.position)
        protocol.write_varint32(output, packet.dimension)
        protocol.write_block_pos(output, packet.spawn_position)
    case Respawn:
        protocol.write_vec3(output, packet.position)
        protocol.write_u8(output, packet.state)
        protocol.write_varuint64(output, packet.entity_runtime_id)
    case Player_Hot_Bar:
        protocol.write_varuint32(output, packet.selected_hot_bar_slot)
        protocol.write_u8(output, packet.window_id)
        protocol.write_bool(output, packet.select_hot_bar_slot)
    case Set_Commands_Enabled:
        protocol.write_bool(output, packet.enabled)
    case Set_Difficulty:
        protocol.write_varuint32(output, packet.difficulty)
    case Change_Dimension:
        protocol.write_varint32(output, packet.dimension)
        protocol.write_vec3(output, packet.position)
        protocol.write_bool(output, packet.respawn)
        write_optional_u32(output, packet.loading_screen_id)
    case Set_Player_Game_Type:
        protocol.write_varint32(output, packet.game_type)
    case Simple_Event:
        protocol.write_u16(output, packet.event_type)
    case Spawn_Experience_Orb:
        protocol.write_vec3(output, packet.position)
        protocol.write_varint32(output, packet.experience_amount)
    case Request_Chunk_Radius:
        protocol.write_varint32(output, packet.chunk_radius)
        protocol.write_u8(output, packet.max_chunk_radius)
    case Chunk_Radius_Updated:
        protocol.write_varint32(output, packet.chunk_radius)
    case Show_Credits:
        protocol.write_varuint64(output, packet.player_runtime_id)
        protocol.write_varint32(output, packet.status_type)
    case Resource_Pack_Data_Info:
        protocol.write_string(output, packet.uuid)
        protocol.write_u32(output, packet.data_chunk_size)
        protocol.write_u32(output, packet.chunk_count)
        protocol.write_u64(output, packet.size)
        protocol.write_byte_slice(output, packet.hash)
        protocol.write_bool(output, packet.premium)
        protocol.write_u8(output, packet.pack_type)
    case Resource_Pack_Chunk_Data:
        protocol.write_string(output, packet.uuid)
        protocol.write_u32(output, packet.chunk_index)
        protocol.write_u64(output, packet.data_offset)
        protocol.write_byte_slice(output, packet.data)
    case Resource_Pack_Chunk_Request:
        protocol.write_string(output, packet.uuid)
        protocol.write_i32(output, packet.chunk_index)
    case Transfer:
        protocol.write_string(output, packet.address)
        protocol.write_u16(output, packet.port)
        protocol.write_bool(output, packet.reload_world)
    case Stop_Sound:
        protocol.write_string(output, packet.sound_name)
        protocol.write_bool(output, packet.stop_all)
        protocol.write_bool(output, packet.stop_music_legacy)
    case Set_Title:
        protocol.write_varint32(output, packet.action_type)
        protocol.write_string(output, packet.text)
        protocol.write_varint32(output, packet.fade_in_duration)
        protocol.write_varint32(output, packet.remain_duration)
        protocol.write_varint32(output, packet.fade_out_duration)
        protocol.write_string(output, packet.xuid)
        protocol.write_string(output, packet.platform_online_id)
        protocol.write_string(output, packet.filtered_message)
    case Show_Store_Offer:
        protocol.write_uuid(output, packet.offer_id)
        protocol.write_u8(output, packet.type)
    case Purchase_Receipt:
        if len(packet.receipts) > protocol.MAX_COLLECTION_ELEMENTS {
            return packet_error(
                .Limit_Exceeded,
                "gophertunnel.packet.write",
                "receipt list exceeds entry limit",
            )
        }
        protocol.write_varuint32(output, u32(len(packet.receipts)))
        for receipt in packet.receipts {
            protocol.write_string(output, receipt)
        }
    case Set_Last_Hurt_By:
        protocol.write_varint32(output, packet.entity_type)
    case Modal_Form_Request:
        protocol.write_varuint32(output, packet.form_id)
        protocol.write_byte_slice(output, packet.form_data)
    case Modal_Form_Response:
        protocol.write_varuint32(output, packet.form_id)
        protocol.write_bool(output, packet.response_data.set)
        if packet.response_data.set {
            protocol.write_byte_slice(output, packet.response_data.value)
        }
        protocol.write_bool(output, packet.cancel_reason.set)
        if packet.cancel_reason.set {
            protocol.write_u8(output, packet.cancel_reason.value)
        }
    case Server_Settings_Request:
    case Server_Settings_Response:
        protocol.write_varuint32(output, packet.form_id)
        protocol.write_byte_slice(output, packet.form_data)
    case Show_Profile:
        protocol.write_string(output, packet.xuid)
    case Set_Default_Game_Type:
        protocol.write_varint32(output, packet.game_type)
    case Remove_Objective:
        protocol.write_string(output, packet.objective_name)
    case Set_Local_Player_As_Initialised:
        protocol.write_varuint64(output, packet.entity_runtime_id)
    case Network_Stack_Latency:
        protocol.write_i64(output, packet.timestamp)
        protocol.write_bool(output, packet.needs_response)
    case Settings_Command:
        protocol.write_string(output, packet.command_line)
        protocol.write_bool(output, packet.suppress_output)
    case Network_Settings:
        protocol.write_u16(output, packet.compression_threshold)
        protocol.write_u16(output, packet.compression_algorithm)
        protocol.write_bool(output, packet.client_throttle)
        protocol.write_u8(output, packet.client_throttle_threshold)
        protocol.write_f32(output, packet.client_throttle_scalar)
    case Update_Player_Game_Type:
        protocol.write_varint32(output, packet.game_type)
        protocol.write_varint64(output, packet.player_unique_id)
        protocol.write_varuint64(output, packet.tick)
    case Filter_Text:
        protocol.write_string(output, packet.text)
        protocol.write_bool(output, packet.from_server)
    case Simulation_Type:
        protocol.write_u8(output, packet.simulation_type)
    case Toast_Request:
        protocol.write_string(output, packet.title)
        protocol.write_string(output, packet.message)
    case Request_Network_Settings:
        protocol.write_be_i32(output, packet.client_protocol)
    case Award_Achievement:
        protocol.write_i32(output, packet.achievement_id)
    case Client_Bound_Close_Form:
    case Server_Bound_Loading_Screen:
        protocol.write_varint32(output, packet.type)
        write_optional_u32(output, packet.loading_screen_id)
    case Client_Bound_Data_Driven_UI_Reload,
         Refresh_Entitlements,
         Resource_Packs_Ready_For_Validation:
    case Ticking_Areas_Load_Status:
        protocol.write_bool(output, packet.preload)
    case Add_Behaviour_Tree:
        protocol.write_string(output, packet.behaviour_tree)
    case Client_Start_Item_Cooldown:
        protocol.write_string(output, packet.category)
        protocol.write_varint32(output, packet.duration)
    case Remove_Volume_Entity:
        protocol.write_varuint32(output, packet.entity_runtime_id)
        protocol.write_varint32(output, packet.dimension)
    case On_Screen_Texture_Animation:
        protocol.write_u32(output, packet.animation_type)
    case Automation_Client_Connect:
        protocol.write_string(output, packet.server_uri)
    case Photo_Info_Request:
        protocol.write_varint64(output, packet.photo_id)
    case Map_Create_Locked_Copy:
        protocol.write_varint64(output, packet.original_map_id)
        protocol.write_varint64(output, packet.new_map_id)
    case Script_Message:
        protocol.write_string(output, packet.identifier)
        protocol.write_byte_slice(output, packet.data)
    case Open_Sign:
        protocol.write_block_pos(output, packet.position)
        protocol.write_bool(output, packet.front_side)
    case Client_Bound_Data_Driven_UI_Close_Screen:
        write_optional_u32(output, packet.form_id)
    case Available_Actor_Identifiers:
        protocol.write_bytes(
            output,
            packet.serialised_entity_identifiers,
        )
    case Current_Structure_Feature:
        protocol.write_string(output, packet.current_feature)
    case Server_Stats:
        protocol.write_f32(output, packet.server_time)
        protocol.write_f32(output, packet.network_time)
    case Anvil_Damage:
        protocol.write_u8(output, packet.damage)
        protocol.write_block_pos(output, packet.anvil_position)
    case Debug_Info:
        protocol.write_varint64(output, packet.player_unique_id)
        protocol.write_byte_slice(output, packet.data)
    case Create_Photo:
        protocol.write_i64(output, packet.entity_unique_id)
        protocol.write_string(output, packet.photo_name)
        protocol.write_string(output, packet.item_name)
    case Code_Builder:
        protocol.write_string(output, packet.url)
        protocol.write_bool(output, packet.should_open_code_builder)
    case Education_Resource_URI:
        protocol.write_education_shared_resource_uri(
            output,
            packet.resource,
        )
    case Player_Fog:
        write_string_slice(output, packet.stack) or_return
    case Death_Info:
        protocol.write_string(output, packet.cause)
        write_string_slice(output, packet.messages) or_return
    case Client_Cache_Status:
        protocol.write_bool(output, packet.enabled)
    case Level_Event_Generic:
        protocol.write_varint32(output, packet.event_id)
        protocol.write_bytes(output, packet.serialised_event_data)
    case Container_Close:
        protocol.write_u8(output, packet.window_id)
        protocol.write_u8(output, packet.container_type)
        protocol.write_bool(output, packet.server_side)
    case Container_Set_Data:
        protocol.write_u8(output, packet.window_id)
        protocol.write_varint32(output, packet.key)
        protocol.write_varint32(output, packet.value)
    case GUI_Data_Pick_Item:
        protocol.write_string(output, packet.item_name)
        protocol.write_string(output, packet.item_effects)
        protocol.write_i32(output, packet.hot_bar_slot)
    case Completed_Using_Item:
        protocol.write_i16(output, packet.used_item_id)
        protocol.write_i32(output, packet.use_method)
    case Unknown_Packet:
        protocol.write_bytes(output, packet.payload)
    case:
        return packet_error(
            .Invalid_Argument,
            "gophertunnel.packet.write",
            "nil packet",
        )
    }
    return nil
}

encode_packet :: proc(
    value: Packet,
    sender_sub_client: u8 = 0,
    target_sub_client: u8 = 0,
    allocator: mem.Allocator = context.allocator,
) -> (data: []u8, err: mcpe_runtime.Error) {
    id := packet_id(value) or_return
    output := protocol.writer(0, 64, allocator)
    defer protocol.writer_destroy(&output)
    write_header(
        &output,
        {
            packet_id = id,
            sender_sub_client = sender_sub_client,
            target_sub_client = target_sub_client,
        },
    ) or_return
    write_payload(&output, value) or_return
    encoded := protocol.writer_bytes(&output)
    data = make([]u8, len(encoded), allocator)
    copy(data, encoded)
    return
}

read_disconnect :: proc(
    input: ^protocol.Reader,
) -> (packet: Disconnect, err: mcpe_runtime.Error) {
    packet.reason = protocol.read_varint32(input) or_return
    packet.hide_disconnection_screen = protocol.read_bool(input) or_return
    if packet.hide_disconnection_screen {
        return
    }
    packet.message = protocol.read_string(input) or_return
    packet.filtered_message, err = protocol.read_string(input)
    if err != nil {
        delete(packet.message, input.allocator)
        packet.message = ""
    }
    return
}

clone_payload :: proc(
    input: ^protocol.Reader,
) -> (payload: []u8, err: mcpe_runtime.Error) {
    borrowed := protocol.read_remaining_bytes(input)
    payload = make([]u8, len(borrowed), input.allocator)
    copy(payload, borrowed)
    return
}

decode_packet :: proc(
    data: []u8,
    allocator: mem.Allocator = context.allocator,
) -> (
    value: Packet,
    header: Header,
    err: mcpe_runtime.Error,
) {
    input := protocol.reader(data, 0, true, allocator)
    header = read_header(&input) or_return
    switch header.packet_id {
    case IDLogin:
        packet := Login{}
        packet.client_protocol = protocol.read_be_i32(&input) or_return
        packet.connection_request =
            protocol.read_byte_slice(&input) or_return
        value = packet
    case IDPlayStatus:
        packet := Play_Status{}
        packet.status = protocol.read_be_i32(&input) or_return
        value = packet
    case IDServerToClientHandshake:
        packet := Server_To_Client_Handshake{}
        packet.jwt = protocol.read_byte_slice(&input) or_return
        value = packet
    case IDClientToServerHandshake:
        value = Client_To_Server_Handshake{}
    case IDDisconnect:
        value = read_disconnect(&input) or_return
    case IDResourcePacksInfo:
        value = read_resource_packs_info(&input) or_return
    case IDResourcePackStack:
        value = read_resource_pack_stack(&input) or_return
    case IDResourcePackClientResponse:
        value = read_resource_pack_client_response(&input) or_return
    case IDText:
        value = read_text(&input) or_return
    case IDSetTime:
        packet := Set_Time{}
        packet.time = protocol.read_varint32(&input) or_return
        value = packet
    case IDRemoveActor:
        packet := Remove_Actor{}
        packet.entity_unique_id = protocol.read_varint64(&input) or_return
        value = packet
    case IDTakeItemActor:
        packet := Take_Item_Actor{}
        packet.item_entity_runtime_id =
            protocol.read_varuint64(&input) or_return
        packet.taker_entity_runtime_id =
            protocol.read_varuint64(&input) or_return
        value = packet
    case IDBlockPickRequest:
        packet := Block_Pick_Request{}
        packet.position = protocol.read_block_pos(&input) or_return
        packet.add_block_nbt = protocol.read_bool(&input) or_return
        packet.hot_bar_slot = protocol.read_u8(&input) or_return
        value = packet
    case IDActorPickRequest:
        packet := Actor_Pick_Request{}
        packet.entity_unique_id = protocol.read_i64(&input) or_return
        packet.hot_bar_slot = protocol.read_u8(&input) or_return
        packet.with_data = protocol.read_bool(&input) or_return
        value = packet
    case IDSetActorMotion:
        packet := Set_Actor_Motion{}
        packet.entity_runtime_id =
            protocol.read_varuint64(&input) or_return
        packet.velocity = protocol.read_vec3(&input) or_return
        packet.tick = protocol.read_varuint64(&input) or_return
        value = packet
    case IDSetHealth:
        packet := Set_Health{}
        packet.health = protocol.read_varint32(&input) or_return
        value = packet
    case IDSetSpawnPosition:
        packet := Set_Spawn_Position{}
        packet.spawn_type = protocol.read_varint32(&input) or_return
        packet.position = protocol.read_block_pos(&input) or_return
        packet.dimension = protocol.read_varint32(&input) or_return
        packet.spawn_position = protocol.read_block_pos(&input) or_return
        value = packet
    case IDRespawn:
        packet := Respawn{}
        packet.position = protocol.read_vec3(&input) or_return
        packet.state = protocol.read_u8(&input) or_return
        packet.entity_runtime_id =
            protocol.read_varuint64(&input) or_return
        value = packet
    case IDPlayerHotBar:
        packet := Player_Hot_Bar{}
        packet.selected_hot_bar_slot =
            protocol.read_varuint32(&input) or_return
        packet.window_id = protocol.read_u8(&input) or_return
        packet.select_hot_bar_slot = protocol.read_bool(&input) or_return
        value = packet
    case IDSetCommandsEnabled:
        packet := Set_Commands_Enabled{}
        packet.enabled = protocol.read_bool(&input) or_return
        value = packet
    case IDSetDifficulty:
        packet := Set_Difficulty{}
        packet.difficulty = protocol.read_varuint32(&input) or_return
        value = packet
    case IDChangeDimension:
        packet := Change_Dimension{}
        packet.dimension = protocol.read_varint32(&input) or_return
        packet.position = protocol.read_vec3(&input) or_return
        packet.respawn = protocol.read_bool(&input) or_return
        packet.loading_screen_id = read_optional_u32(&input) or_return
        value = packet
    case IDSetPlayerGameType:
        packet := Set_Player_Game_Type{}
        packet.game_type = protocol.read_varint32(&input) or_return
        value = packet
    case IDSimpleEvent:
        packet := Simple_Event{}
        packet.event_type = protocol.read_u16(&input) or_return
        value = packet
    case IDSpawnExperienceOrb:
        packet := Spawn_Experience_Orb{}
        packet.position = protocol.read_vec3(&input) or_return
        packet.experience_amount =
            protocol.read_varint32(&input) or_return
        value = packet
    case IDRequestChunkRadius:
        packet := Request_Chunk_Radius{}
        packet.chunk_radius = protocol.read_varint32(&input) or_return
        packet.max_chunk_radius = protocol.read_u8(&input) or_return
        value = packet
    case IDChunkRadiusUpdated:
        packet := Chunk_Radius_Updated{}
        packet.chunk_radius = protocol.read_varint32(&input) or_return
        value = packet
    case IDShowCredits:
        packet := Show_Credits{}
        packet.player_runtime_id =
            protocol.read_varuint64(&input) or_return
        packet.status_type = protocol.read_varint32(&input) or_return
        value = packet
    case IDResourcePackDataInfo:
        value = read_resource_pack_data_info(&input) or_return
    case IDResourcePackChunkData:
        value = read_resource_pack_chunk_data(&input) or_return
    case IDResourcePackChunkRequest:
        value = read_resource_pack_chunk_request(&input) or_return
    case IDTransfer:
        value = read_transfer(&input) or_return
    case IDStopSound:
        value = read_stop_sound(&input) or_return
    case IDSetTitle:
        value = read_set_title(&input) or_return
    case IDShowStoreOffer:
        packet := Show_Store_Offer{}
        packet.offer_id = protocol.read_uuid(&input) or_return
        packet.type = protocol.read_u8(&input) or_return
        value = packet
    case IDPurchaseReceipt:
        value = read_purchase_receipt(&input) or_return
    case IDSetLastHurtBy:
        packet := Set_Last_Hurt_By{}
        packet.entity_type = protocol.read_varint32(&input) or_return
        value = packet
    case IDModalFormRequest:
        packet := Modal_Form_Request{}
        packet.form_id = protocol.read_varuint32(&input) or_return
        packet.form_data = protocol.read_byte_slice(&input) or_return
        value = packet
    case IDModalFormResponse:
        value = read_modal_form_response(&input) or_return
    case IDServerSettingsRequest:
        value = Server_Settings_Request{}
    case IDServerSettingsResponse:
        value = read_server_settings_response(&input) or_return
    case IDShowProfile:
        packet := Show_Profile{}
        packet.xuid = protocol.read_string(&input) or_return
        value = packet
    case IDSetDefaultGameType:
        packet := Set_Default_Game_Type{}
        packet.game_type = protocol.read_varint32(&input) or_return
        value = packet
    case IDRemoveObjective:
        packet := Remove_Objective{}
        packet.objective_name = protocol.read_string(&input) or_return
        value = packet
    case IDSetLocalPlayerAsInitialised:
        packet := Set_Local_Player_As_Initialised{}
        packet.entity_runtime_id =
            protocol.read_varuint64(&input) or_return
        value = packet
    case IDNetworkStackLatency:
        packet := Network_Stack_Latency{}
        packet.timestamp = protocol.read_i64(&input) or_return
        packet.needs_response = protocol.read_bool(&input) or_return
        value = packet
    case IDSettingsCommand:
        value = read_settings_command(&input) or_return
    case IDNetworkSettings:
        packet := Network_Settings{}
        packet.compression_threshold = protocol.read_u16(&input) or_return
        packet.compression_algorithm = protocol.read_u16(&input) or_return
        packet.client_throttle = protocol.read_bool(&input) or_return
        packet.client_throttle_threshold =
            protocol.read_u8(&input) or_return
        packet.client_throttle_scalar =
            protocol.read_f32(&input) or_return
        value = packet
    case IDUpdatePlayerGameType:
        packet := Update_Player_Game_Type{}
        packet.game_type = protocol.read_varint32(&input) or_return
        packet.player_unique_id = protocol.read_varint64(&input) or_return
        packet.tick = protocol.read_varuint64(&input) or_return
        value = packet
    case IDFilterText:
        value = read_filter_text(&input) or_return
    case IDSimulationType:
        packet := Simulation_Type{}
        packet.simulation_type = protocol.read_u8(&input) or_return
        value = packet
    case IDToastRequest:
        value = read_toast_request(&input) or_return
    case IDRequestNetworkSettings:
        packet := Request_Network_Settings{}
        packet.client_protocol = protocol.read_be_i32(&input) or_return
        value = packet
    case IDAwardAchievement:
        packet := Award_Achievement{}
        packet.achievement_id = protocol.read_i32(&input) or_return
        value = packet
    case IDClientBoundCloseForm:
        value = Client_Bound_Close_Form{}
    case IDServerBoundLoadingScreen:
        packet := Server_Bound_Loading_Screen{}
        packet.type = protocol.read_varint32(&input) or_return
        packet.loading_screen_id = read_optional_u32(&input) or_return
        value = packet
    case IDClientBoundDataDrivenUIReload:
        value = Client_Bound_Data_Driven_UI_Reload{}
    case IDRefreshEntitlements:
        value = Refresh_Entitlements{}
    case IDResourcePacksReadyForValidation:
        value = Resource_Packs_Ready_For_Validation{}
    case IDTickingAreasLoadStatus:
        packet := Ticking_Areas_Load_Status{}
        packet.preload = protocol.read_bool(&input) or_return
        value = packet
    case IDAddBehaviourTree:
        packet := Add_Behaviour_Tree{}
        packet.behaviour_tree = protocol.read_string(&input) or_return
        value = packet
    case IDClientStartItemCooldown:
        packet := Client_Start_Item_Cooldown{}
        packet.category = protocol.read_string(&input) or_return
        packet.duration, err = protocol.read_varint32(&input)
        if err != nil {
            delete(packet.category, allocator)
            packet.category = ""
            return
        }
        value = packet
    case IDRemoveVolumeEntity:
        packet := Remove_Volume_Entity{}
        packet.entity_runtime_id =
            protocol.read_varuint32(&input) or_return
        packet.dimension = protocol.read_varint32(&input) or_return
        value = packet
    case IDOnScreenTextureAnimation:
        packet := On_Screen_Texture_Animation{}
        packet.animation_type = protocol.read_u32(&input) or_return
        value = packet
    case IDAutomationClientConnect:
        packet := Automation_Client_Connect{}
        packet.server_uri = protocol.read_string(&input) or_return
        value = packet
    case IDPhotoInfoRequest:
        packet := Photo_Info_Request{}
        packet.photo_id = protocol.read_varint64(&input) or_return
        value = packet
    case IDMapCreateLockedCopy:
        packet := Map_Create_Locked_Copy{}
        packet.original_map_id = protocol.read_varint64(&input) or_return
        packet.new_map_id = protocol.read_varint64(&input) or_return
        value = packet
    case IDScriptMessage:
        packet := Script_Message{}
        packet.identifier = protocol.read_string(&input) or_return
        packet.data, err = protocol.read_byte_slice(&input)
        if err != nil {
            delete(packet.identifier, allocator)
            packet.identifier = ""
            return
        }
        value = packet
    case IDOpenSign:
        packet := Open_Sign{}
        packet.position = protocol.read_block_pos(&input) or_return
        packet.front_side = protocol.read_bool(&input) or_return
        value = packet
    case IDClientBoundDataDrivenUICloseScreen:
        packet := Client_Bound_Data_Driven_UI_Close_Screen{}
        packet.form_id = read_optional_u32(&input) or_return
        value = packet
    case IDAvailableActorIdentifiers:
        packet := Available_Actor_Identifiers{}
        packet.serialised_entity_identifiers =
            clone_payload(&input) or_return
        value = packet
    case IDCurrentStructureFeature:
        packet := Current_Structure_Feature{}
        packet.current_feature = protocol.read_string(&input) or_return
        value = packet
    case IDServerStats:
        packet := Server_Stats{}
        packet.server_time = protocol.read_f32(&input) or_return
        packet.network_time = protocol.read_f32(&input) or_return
        value = packet
    case IDAnvilDamage:
        packet := Anvil_Damage{}
        packet.damage = protocol.read_u8(&input) or_return
        packet.anvil_position = protocol.read_block_pos(&input) or_return
        value = packet
    case IDDebugInfo:
        packet := Debug_Info{}
        packet.player_unique_id =
            protocol.read_varint64(&input) or_return
        packet.data = protocol.read_byte_slice(&input) or_return
        value = packet
    case IDCreatePhoto:
        packet := Create_Photo{}
        packet.entity_unique_id = protocol.read_i64(&input) or_return
        packet.photo_name = protocol.read_string(&input) or_return
        packet.item_name, err = protocol.read_string(&input)
        if err != nil {
            delete(packet.photo_name, allocator)
            packet.photo_name = ""
            return
        }
        value = packet
    case IDCodeBuilder:
        packet := Code_Builder{}
        packet.url = protocol.read_string(&input) or_return
        packet.should_open_code_builder, err =
            protocol.read_bool(&input)
        if err != nil {
            delete(packet.url, allocator)
            packet.url = ""
            return
        }
        value = packet
    case IDEducationResourceURI:
        packet := Education_Resource_URI{}
        packet.resource =
            protocol.read_education_shared_resource_uri(&input) or_return
        value = packet
    case IDPlayerFog:
        packet := Player_Fog{}
        packet.stack = read_string_slice(&input) or_return
        value = packet
    case IDDeathInfo:
        packet := Death_Info{}
        packet.cause = protocol.read_string(&input) or_return
        packet.messages, err = read_string_slice(&input)
        if err != nil {
            delete(packet.cause, allocator)
            packet.cause = ""
            return
        }
        value = packet
    case IDClientCacheStatus:
        packet := Client_Cache_Status{}
        packet.enabled = protocol.read_bool(&input) or_return
        value = packet
    case IDLevelEventGeneric:
        packet := Level_Event_Generic{}
        packet.event_id = protocol.read_varint32(&input) or_return
        packet.serialised_event_data = clone_payload(&input) or_return
        value = packet
    case IDContainerClose:
        packet := Container_Close{}
        packet.window_id = protocol.read_u8(&input) or_return
        packet.container_type = protocol.read_u8(&input) or_return
        packet.server_side = protocol.read_bool(&input) or_return
        value = packet
    case IDContainerSetData:
        packet := Container_Set_Data{}
        packet.window_id = protocol.read_u8(&input) or_return
        packet.key = protocol.read_varint32(&input) or_return
        packet.value = protocol.read_varint32(&input) or_return
        value = packet
    case IDGUIDataPickItem:
        packet := GUI_Data_Pick_Item{}
        packet.item_name = protocol.read_string(&input) or_return
        packet.item_effects, err = protocol.read_string(&input)
        if err != nil {
            delete(packet.item_name, allocator)
            packet.item_name = ""
            return
        }
        packet.hot_bar_slot, err = protocol.read_i32(&input)
        if err != nil {
            delete(packet.item_name, allocator)
            delete(packet.item_effects, allocator)
            packet.item_name = ""
            packet.item_effects = ""
            return
        }
        value = packet
    case IDCompletedUsingItem:
        packet := Completed_Using_Item{}
        packet.used_item_id = protocol.read_i16(&input) or_return
        packet.use_method = protocol.read_i32(&input) or_return
        value = packet
    case:
        value = Unknown_Packet{
            packet_id = header.packet_id,
            payload = clone_payload(&input) or_return,
        }
    }
    if modeled_packet_id(header.packet_id) {
        if protocol.remaining(&input) != 0 {
            destroy_packet(&value, allocator)
            value = nil
            err = packet_error(
                .Malformed,
                "gophertunnel.packet.decode",
                "unread bytes after packet payload",
            )
        }
    }
    return
}

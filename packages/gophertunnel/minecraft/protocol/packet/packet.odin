package gt_packet

import "core:mem"
import protocol "mcpe:gophertunnel/minecraft/protocol"
import mcpe_runtime "mcpe:runtime"

Header :: struct {
    packet_id:         u32,
    sender_sub_client: u8,
    target_sub_client: u8,
}

write_header :: proc(
    output: ^protocol.Writer,
    header: Header,
) -> mcpe_runtime.Error {
    if header.packet_id > 0x3ff ||
       header.sender_sub_client > 3 ||
       header.target_sub_client > 3 {
        return packet_error(
            .Invalid_Argument,
            "gophertunnel.packet.write_header",
            "packet header field exceeds wire width",
        )
    }
    protocol.write_varuint32(
        output,
        header.packet_id |
        u32(header.sender_sub_client) << 10 |
        u32(header.target_sub_client) << 12,
    )
    return nil
}

read_header :: proc(input: ^protocol.Reader) -> (
    header: Header,
    err: mcpe_runtime.Error,
) {
    value := protocol.read_varuint32(input) or_return
    header = {
        packet_id = value & 0x3ff,
        sender_sub_client = u8((value >> 10) & 0x3),
        target_sub_client = u8((value >> 12) & 0x3),
    }
    return
}

Unknown_Packet :: struct {
    packet_id: u32,
    payload:   []u8,
}

Packet :: union {
    Login,
    Play_Status,
    Server_To_Client_Handshake,
    Client_To_Server_Handshake,
    Disconnect,
    Resource_Packs_Info,
    Resource_Pack_Stack,
    Resource_Pack_Client_Response,
    Text,
    Set_Time,
    Remove_Actor,
    Take_Item_Actor,
    Block_Pick_Request,
    Actor_Pick_Request,
    Set_Actor_Motion,
    Set_Health,
    Set_Spawn_Position,
    Respawn,
    Player_Hot_Bar,
    Set_Commands_Enabled,
    Set_Difficulty,
    Change_Dimension,
    Set_Player_Game_Type,
    Simple_Event,
    Spawn_Experience_Orb,
    Request_Chunk_Radius,
    Chunk_Radius_Updated,
    Show_Credits,
    Resource_Pack_Data_Info,
    Resource_Pack_Chunk_Data,
    Resource_Pack_Chunk_Request,
    Transfer,
    Stop_Sound,
    Set_Title,
    Show_Store_Offer,
    Purchase_Receipt,
    Set_Last_Hurt_By,
    Modal_Form_Request,
    Modal_Form_Response,
    Server_Settings_Request,
    Server_Settings_Response,
    Show_Profile,
    Set_Default_Game_Type,
    Remove_Objective,
    Set_Local_Player_As_Initialised,
    Network_Stack_Latency,
    Settings_Command,
    Network_Settings,
    Update_Player_Game_Type,
    Filter_Text,
    Simulation_Type,
    Toast_Request,
    Request_Network_Settings,
    Award_Achievement,
    Client_Bound_Close_Form,
    Server_Bound_Loading_Screen,
    Client_Bound_Data_Driven_UI_Reload,
    Refresh_Entitlements,
    Resource_Packs_Ready_For_Validation,
    Ticking_Areas_Load_Status,
    Add_Behaviour_Tree,
    Client_Start_Item_Cooldown,
    Remove_Volume_Entity,
    On_Screen_Texture_Animation,
    Automation_Client_Connect,
    Photo_Info_Request,
    Map_Create_Locked_Copy,
    Script_Message,
    Open_Sign,
    Client_Bound_Data_Driven_UI_Close_Screen,
    Available_Actor_Identifiers,
    Current_Structure_Feature,
    Server_Stats,
    Anvil_Damage,
    Debug_Info,
    Create_Photo,
    Code_Builder,
    Education_Resource_URI,
    Player_Fog,
    Death_Info,
    Client_Cache_Status,
    Level_Event_Generic,
    Container_Close,
    Container_Set_Data,
    GUI_Data_Pick_Item,
    Completed_Using_Item,
    Agent_Animation,
    Camera,
    Clientbound_Update_Sound_Data,
    Game_Test_Results,
    Hurt_Armour,
    Lesson_Progress,
    Motion_Prediction_Hints,
    Multi_Player_Settings,
    Packet_Violation_Warning,
    Request_Permissions,
    Update_Adventure_Settings,
    Update_Client_Input_Locks,
    Update_Client_Options,
    Actor_Event,
    Agent_Action,
    Block_Event,
    Camera_Shake,
    Code_Builder_Source,
    Emote,
    Game_Test_Request,
    Lab_Table,
    Lectern_Update,
    NPC_Request,
    Player_Action,
    Spawn_Particle_Effect,
    Client_Cache_Blob_Status,
    Client_Bound_Data_Driven_UI_Show_Screen,
    Sub_Client_Login,
    Script_Custom_Event,
    Emote_List,
    Send_Party_Destination_Cookie,
    Player_Toggle_Crafter_Slot_Request,
    Client_Camera_Aim_Assist,
    Server_Bound_Data_Driven_Screen_Closed,
    Position_Tracking_DB_Client_Request,
    Party_Changed,
    Party_Destination_Cookie_Response,
    Client_Bound_Control_Scheme_Set,
    Movement_Effect,
    Player_Video_Capture,
    Player_Location,
    Client_Bound_Texture_Shift,
    Set_Hud,
    Set_Player_Inventory_Options,
    Player_Update_Entity_Overrides,
    Camera_Aim_Assist,
    Change_Mob_Property,
    Mob_Effect,
    Play_Sound,
    Interact,
    Move_Actor_Absolute,
    Move_Actor_Delta,
    Container_Open,
    Network_Chunk_Publisher_Update,
    Add_Painting,
    Animate,
    Set_Actor_Link,
    Map_Info_Request,
    Player_Armour_Damage,
    Level_Event,
    Photo_Transfer,
    Set_Display_Objective,
    Level_Sound_Event,
    Animate_Entity,
    Set_Score,
    Set_Scoreboard_Identity,
    Update_Block,
    Update_Block_Synced,
    Adventure_Settings,
    Book_Edit,
    Boss_Event,
    Update_Soft_Enum,
    Unlocked_Recipes,
    Trim_Data,
    Feature_Registry,
    Dimension_Data,
    Server_Store_Info,
    Server_Presence_Info,
    Camera_Aim_Assist_Actor_Priority,
    Correct_Player_Move_Prediction,
    Update_Abilities,
    Client_Cheat_Ability,
    Container_Registry_Cleanup,
    Unknown_Packet,
}

packet_error :: proc(
    kind: mcpe_runtime.Error_Kind,
    operation: string,
    message: string,
) -> mcpe_runtime.Error {
    return mcpe_runtime.make_error(kind, operation, message)
}

packet_id :: proc(value: Packet) -> (
    id: u32,
    err: mcpe_runtime.Error,
) {
    switch packet in value {
    case Login:                       id = IDLogin
    case Play_Status:                 id = IDPlayStatus
    case Server_To_Client_Handshake:  id = IDServerToClientHandshake
    case Client_To_Server_Handshake:  id = IDClientToServerHandshake
    case Disconnect:                  id = IDDisconnect
    case Resource_Packs_Info:         id = IDResourcePacksInfo
    case Resource_Pack_Stack:         id = IDResourcePackStack
    case Resource_Pack_Client_Response:
        id = IDResourcePackClientResponse
    case Text:                        id = IDText
    case Set_Time:                    id = IDSetTime
    case Remove_Actor:                id = IDRemoveActor
    case Take_Item_Actor:             id = IDTakeItemActor
    case Block_Pick_Request:          id = IDBlockPickRequest
    case Actor_Pick_Request:          id = IDActorPickRequest
    case Set_Actor_Motion:            id = IDSetActorMotion
    case Set_Health:                  id = IDSetHealth
    case Set_Spawn_Position:          id = IDSetSpawnPosition
    case Respawn:                     id = IDRespawn
    case Player_Hot_Bar:              id = IDPlayerHotBar
    case Set_Commands_Enabled:        id = IDSetCommandsEnabled
    case Set_Difficulty:              id = IDSetDifficulty
    case Change_Dimension:            id = IDChangeDimension
    case Set_Player_Game_Type:        id = IDSetPlayerGameType
    case Simple_Event:                id = IDSimpleEvent
    case Spawn_Experience_Orb:        id = IDSpawnExperienceOrb
    case Request_Chunk_Radius:        id = IDRequestChunkRadius
    case Chunk_Radius_Updated:        id = IDChunkRadiusUpdated
    case Show_Credits:                id = IDShowCredits
    case Resource_Pack_Data_Info:     id = IDResourcePackDataInfo
    case Resource_Pack_Chunk_Data:    id = IDResourcePackChunkData
    case Resource_Pack_Chunk_Request: id = IDResourcePackChunkRequest
    case Transfer:                    id = IDTransfer
    case Stop_Sound:                  id = IDStopSound
    case Set_Title:                   id = IDSetTitle
    case Show_Store_Offer:            id = IDShowStoreOffer
    case Purchase_Receipt:            id = IDPurchaseReceipt
    case Set_Last_Hurt_By:            id = IDSetLastHurtBy
    case Modal_Form_Request:          id = IDModalFormRequest
    case Modal_Form_Response:         id = IDModalFormResponse
    case Server_Settings_Request:     id = IDServerSettingsRequest
    case Server_Settings_Response:    id = IDServerSettingsResponse
    case Show_Profile:                id = IDShowProfile
    case Set_Default_Game_Type:       id = IDSetDefaultGameType
    case Remove_Objective:            id = IDRemoveObjective
    case Set_Local_Player_As_Initialised:
        id = IDSetLocalPlayerAsInitialised
    case Network_Stack_Latency:       id = IDNetworkStackLatency
    case Settings_Command:            id = IDSettingsCommand
    case Network_Settings:            id = IDNetworkSettings
    case Update_Player_Game_Type:     id = IDUpdatePlayerGameType
    case Filter_Text:                 id = IDFilterText
    case Simulation_Type:             id = IDSimulationType
    case Toast_Request:               id = IDToastRequest
    case Request_Network_Settings:    id = IDRequestNetworkSettings
    case Award_Achievement:           id = IDAwardAchievement
    case Client_Bound_Close_Form:     id = IDClientBoundCloseForm
    case Server_Bound_Loading_Screen: id = IDServerBoundLoadingScreen
    case Client_Bound_Data_Driven_UI_Reload:
        id = IDClientBoundDataDrivenUIReload
    case Refresh_Entitlements:        id = IDRefreshEntitlements
    case Resource_Packs_Ready_For_Validation:
        id = IDResourcePacksReadyForValidation
    case Ticking_Areas_Load_Status:   id = IDTickingAreasLoadStatus
    case Add_Behaviour_Tree:          id = IDAddBehaviourTree
    case Client_Start_Item_Cooldown:  id = IDClientStartItemCooldown
    case Remove_Volume_Entity:        id = IDRemoveVolumeEntity
    case On_Screen_Texture_Animation: id = IDOnScreenTextureAnimation
    case Automation_Client_Connect:   id = IDAutomationClientConnect
    case Photo_Info_Request:          id = IDPhotoInfoRequest
    case Map_Create_Locked_Copy:      id = IDMapCreateLockedCopy
    case Script_Message:              id = IDScriptMessage
    case Open_Sign:                   id = IDOpenSign
    case Client_Bound_Data_Driven_UI_Close_Screen:
        id = IDClientBoundDataDrivenUICloseScreen
    case Available_Actor_Identifiers: id = IDAvailableActorIdentifiers
    case Current_Structure_Feature:   id = IDCurrentStructureFeature
    case Server_Stats:                id = IDServerStats
    case Anvil_Damage:                id = IDAnvilDamage
    case Debug_Info:                  id = IDDebugInfo
    case Create_Photo:                id = IDCreatePhoto
    case Code_Builder:                id = IDCodeBuilder
    case Education_Resource_URI:      id = IDEducationResourceURI
    case Player_Fog:                  id = IDPlayerFog
    case Death_Info:                  id = IDDeathInfo
    case Client_Cache_Status:         id = IDClientCacheStatus
    case Level_Event_Generic:         id = IDLevelEventGeneric
    case Container_Close:             id = IDContainerClose
    case Container_Set_Data:          id = IDContainerSetData
    case GUI_Data_Pick_Item:          id = IDGUIDataPickItem
    case Completed_Using_Item:        id = IDCompletedUsingItem
    case Agent_Animation:             id = IDAgentAnimation
    case Camera:                      id = IDCamera
    case Clientbound_Update_Sound_Data:
        id = IDClientboundUpdateSoundData
    case Game_Test_Results:           id = IDGameTestResults
    case Hurt_Armour:                 id = IDHurtArmour
    case Lesson_Progress:             id = IDLessonProgress
    case Motion_Prediction_Hints:     id = IDMotionPredictionHints
    case Multi_Player_Settings:       id = IDMultiPlayerSettings
    case Packet_Violation_Warning:    id = IDPacketViolationWarning
    case Request_Permissions:         id = IDRequestPermissions
    case Update_Adventure_Settings:   id = IDUpdateAdventureSettings
    case Update_Client_Input_Locks:   id = IDUpdateClientInputLocks
    case Update_Client_Options:       id = IDUpdateClientOptions
    case Actor_Event:                 id = IDActorEvent
    case Agent_Action:                id = IDAgentAction
    case Block_Event:                 id = IDBlockEvent
    case Camera_Shake:                id = IDCameraShake
    case Code_Builder_Source:         id = IDCodeBuilderSource
    case Emote:                       id = IDEmote
    case Game_Test_Request:           id = IDGameTestRequest
    case Lab_Table:                   id = IDLabTable
    case Lectern_Update:              id = IDLecternUpdate
    case NPC_Request:                 id = IDNPCRequest
    case Player_Action:               id = IDPlayerAction
    case Spawn_Particle_Effect:       id = IDSpawnParticleEffect
    case Client_Cache_Blob_Status:    id = IDClientCacheBlobStatus
    case Client_Bound_Data_Driven_UI_Show_Screen:
        id = IDClientBoundDataDrivenUIShowScreen
    case Sub_Client_Login:            id = IDSubClientLogin
    case Script_Custom_Event:         id = IDScriptCustomEvent
    case Emote_List:                  id = IDEmoteList
    case Send_Party_Destination_Cookie:
        id = IDSendPartyDestinationCookie
    case Player_Toggle_Crafter_Slot_Request:
        id = IDPlayerToggleCrafterSlotRequest
    case Client_Camera_Aim_Assist:    id = IDClientCameraAimAssist
    case Server_Bound_Data_Driven_Screen_Closed:
        id = IDServerBoundDataDrivenScreenClosed
    case Position_Tracking_DB_Client_Request:
        id = IDPositionTrackingDBClientRequest
    case Party_Changed:               id = IDPartyChanged
    case Party_Destination_Cookie_Response:
        id = IDPartyDestinationCookieResponse
    case Client_Bound_Control_Scheme_Set:
        id = IDClientBoundControlSchemeSet
    case Movement_Effect:             id = IDMovementEffect
    case Player_Video_Capture:        id = IDPlayerVideoCapture
    case Player_Location:             id = IDPlayerLocation
    case Client_Bound_Texture_Shift:  id = IDClientBoundTextureShift
    case Set_Hud:                     id = IDSetHud
    case Set_Player_Inventory_Options:
        id = IDSetPlayerInventoryOptions
    case Player_Update_Entity_Overrides:
        id = IDPlayerUpdateEntityOverrides
    case Camera_Aim_Assist:           id = IDCameraAimAssist
    case Change_Mob_Property:         id = IDChangeMobProperty
    case Mob_Effect:                  id = IDMobEffect
    case Play_Sound:                  id = IDPlaySound
    case Interact:                    id = IDInteract
    case Move_Actor_Absolute:         id = IDMoveActorAbsolute
    case Move_Actor_Delta:            id = IDMoveActorDelta
    case Container_Open:              id = IDContainerOpen
    case Network_Chunk_Publisher_Update:
        id = IDNetworkChunkPublisherUpdate
    case Add_Painting:                id = IDAddPainting
    case Animate:                     id = IDAnimate
    case Set_Actor_Link:              id = IDSetActorLink
    case Map_Info_Request:            id = IDMapInfoRequest
    case Player_Armour_Damage:        id = IDPlayerArmourDamage
    case Level_Event:                 id = IDLevelEvent
    case Photo_Transfer:              id = IDPhotoTransfer
    case Set_Display_Objective:       id = IDSetDisplayObjective
    case Level_Sound_Event:           id = IDLevelSoundEvent
    case Animate_Entity:              id = IDAnimateEntity
    case Set_Score:                   id = IDSetScore
    case Set_Scoreboard_Identity:     id = IDSetScoreboardIdentity
    case Update_Block:                id = IDUpdateBlock
    case Update_Block_Synced:         id = IDUpdateBlockSynced
    case Adventure_Settings:          id = IDAdventureSettings
    case Book_Edit:                   id = IDBookEdit
    case Boss_Event:                  id = IDBossEvent
    case Update_Soft_Enum:            id = IDUpdateSoftEnum
    case Unlocked_Recipes:             id = IDUnlockedRecipes
    case Trim_Data:                    id = IDTrimData
    case Feature_Registry:             id = IDFeatureRegistry
    case Dimension_Data:               id = IDDimensionData
    case Server_Store_Info:            id = IDServerStoreInfo
    case Server_Presence_Info:         id = IDServerPresenceInfo
    case Camera_Aim_Assist_Actor_Priority:
        id = IDCameraAimAssistActorPriority
    case Correct_Player_Move_Prediction:
        id = IDCorrectPlayerMovePrediction
    case Update_Abilities:             id = IDUpdateAbilities
    case Client_Cheat_Ability:         id = IDClientCheatAbility
    case Container_Registry_Cleanup:   id = IDContainerRegistryCleanup
    case Unknown_Packet:              id = packet.packet_id
    case:
        err = packet_error(
            .Invalid_Argument,
            "gophertunnel.packet.id",
            "nil packet",
        )
    }
    if err == nil && id > 0x3ff {
        err = packet_error(
            .Invalid_Argument,
            "gophertunnel.packet.id",
            "packet ID exceeds 10-bit header field",
        )
    }
    return
}

destroy_packet :: proc(
    value: ^Packet,
    allocator: mem.Allocator = context.allocator,
) {
    if value == nil {
        return
    }
    #partial switch packet in value^ {
    case Login:
        delete(packet.connection_request, allocator)
    case Resource_Packs_Info:
        destroy_resource_packs_info_value(packet, allocator)
    case Resource_Pack_Stack:
        destroy_resource_pack_stack_value(packet, allocator)
    case Text:
        destroy_text_value(packet, allocator)
    case Server_To_Client_Handshake:
        delete(packet.jwt, allocator)
    case Disconnect:
        delete(packet.message, allocator)
        delete(packet.filtered_message, allocator)
    case Transfer:
        delete(packet.address, allocator)
    case Stop_Sound:
        delete(packet.sound_name, allocator)
    case Set_Title:
        destroy_set_title_value(packet, allocator)
    case Purchase_Receipt:
        destroy_purchase_receipt_value(packet, allocator)
    case Resource_Pack_Client_Response:
        for entry in packet.packs_to_download {
            delete(entry, allocator)
        }
        delete(packet.packs_to_download, allocator)
    case Resource_Pack_Data_Info:
        delete(packet.uuid, allocator)
        delete(packet.hash, allocator)
    case Resource_Pack_Chunk_Data:
        delete(packet.uuid, allocator)
        delete(packet.data, allocator)
    case Resource_Pack_Chunk_Request:
        delete(packet.uuid, allocator)
    case Modal_Form_Request:
        delete(packet.form_data, allocator)
    case Modal_Form_Response:
        if packet.response_data.set {
            delete(packet.response_data.value, allocator)
        }
    case Server_Settings_Response:
        delete(packet.form_data, allocator)
    case Show_Profile:
        delete(packet.xuid, allocator)
    case Remove_Objective:
        delete(packet.objective_name, allocator)
    case Filter_Text:
        delete(packet.text, allocator)
    case Settings_Command:
        delete(packet.command_line, allocator)
    case Toast_Request:
        delete(packet.title, allocator)
        delete(packet.message, allocator)
    case Add_Behaviour_Tree:
        delete(packet.behaviour_tree, allocator)
    case Client_Start_Item_Cooldown:
        delete(packet.category, allocator)
    case Automation_Client_Connect:
        delete(packet.server_uri, allocator)
    case Script_Message:
        delete(packet.identifier, allocator)
        delete(packet.data, allocator)
    case Available_Actor_Identifiers:
        delete(packet.serialised_entity_identifiers, allocator)
    case Current_Structure_Feature:
        delete(packet.current_feature, allocator)
    case Debug_Info:
        delete(packet.data, allocator)
    case Create_Photo:
        delete(packet.photo_name, allocator)
        delete(packet.item_name, allocator)
    case Code_Builder:
        delete(packet.url, allocator)
    case Education_Resource_URI:
        delete(packet.resource.button_name, allocator)
        delete(packet.resource.link_uri, allocator)
    case Player_Fog:
        destroy_string_slice(packet.stack, allocator)
    case Death_Info:
        delete(packet.cause, allocator)
        destroy_string_slice(packet.messages, allocator)
    case Level_Event_Generic:
        delete(packet.serialised_event_data, allocator)
    case GUI_Data_Pick_Item:
        delete(packet.item_name, allocator)
        delete(packet.item_effects, allocator)
    case Clientbound_Update_Sound_Data:
        delete(packet.sound_event, allocator)
    case Game_Test_Results:
        delete(packet.name, allocator)
        delete(packet.error, allocator)
    case Lesson_Progress:
        delete(packet.identifier, allocator)
    case Packet_Violation_Warning:
        delete(packet.violation_context, allocator)
    case Agent_Action:
        delete(packet.identifier, allocator)
        delete(packet.response, allocator)
    case Emote:
        delete(packet.emote_id, allocator)
        delete(packet.xuid, allocator)
        delete(packet.platform_id, allocator)
    case Game_Test_Request:
        delete(packet.name, allocator)
    case NPC_Request:
        delete(packet.command_string, allocator)
        delete(packet.scene_name, allocator)
    case Spawn_Particle_Effect:
        delete(packet.particle_name, allocator)
        if packet.molang_variables.set {
            delete(packet.molang_variables.value, allocator)
        }
    case Client_Cache_Blob_Status:
        delete(packet.miss_hashes, allocator)
        delete(packet.hit_hashes, allocator)
    case Client_Bound_Data_Driven_UI_Show_Screen:
        delete(packet.screen_id, allocator)
    case Sub_Client_Login:
        delete(packet.connection_request, allocator)
    case Script_Custom_Event:
        delete(packet.event_name, allocator)
        delete(packet.event_data, allocator)
    case Emote_List:
        delete(packet.emote_pieces, allocator)
    case Send_Party_Destination_Cookie:
        delete(packet.cookie, allocator)
        delete(packet.intent, allocator)
        delete(packet.destination_name, allocator)
    case Client_Camera_Aim_Assist:
        delete(packet.preset_id, allocator)
    case Server_Bound_Data_Driven_Screen_Closed:
        delete(packet.close_reason, allocator)
    case Party_Changed:
        if packet.party_info.set {
            delete(packet.party_info.value.party_id, allocator)
        }
    case Party_Destination_Cookie_Response:
        delete(packet.cookie, allocator)
    case Player_Video_Capture:
        delete(packet.file_prefix, allocator)
    case Client_Bound_Texture_Shift:
        destroy_client_bound_texture_shift(packet, allocator)
    case Set_Hud:
        delete(packet.elements, allocator)
    case Camera_Aim_Assist:
        delete(packet.preset, allocator)
    case Change_Mob_Property:
        delete(packet.property, allocator)
        delete(packet.string_value, allocator)
    case Play_Sound:
        delete(packet.sound_name, allocator)
    case Network_Chunk_Publisher_Update:
        delete(packet.saved_chunks, allocator)
    case Add_Painting:
        delete(packet.title, allocator)
    case Map_Info_Request:
        delete(packet.client_pixels, allocator)
    case Player_Armour_Damage:
        delete(packet.list, allocator)
    case Photo_Transfer:
        delete(packet.photo_name, allocator)
        delete(packet.photo_data, allocator)
        delete(packet.book_id, allocator)
        delete(packet.new_photo_name, allocator)
    case Set_Display_Objective:
        delete(packet.display_slot, allocator)
        delete(packet.objective_name, allocator)
        delete(packet.display_name, allocator)
        delete(packet.criteria_name, allocator)
    case Level_Sound_Event:
        delete(packet.sound_type, allocator)
        delete(packet.entity_type, allocator)
    case Animate_Entity:
        delete(packet.animation, allocator)
        delete(packet.next_state, allocator)
        delete(packet.stop_condition, allocator)
        delete(packet.controller, allocator)
        delete(packet.entity_runtime_ids, allocator)
    case Set_Score:
        destroy_scoreboard_entries(packet.entries, allocator)
    case Set_Scoreboard_Identity:
        delete(packet.entries, allocator)
    case Book_Edit:
        delete(packet.text, allocator)
        delete(packet.photo_name, allocator)
        delete(packet.title, allocator)
        delete(packet.author, allocator)
        delete(packet.xuid, allocator)
    case Boss_Event:
        delete(packet.boss_bar_title, allocator)
        delete(packet.filtered_boss_bar_title, allocator)
    case Update_Soft_Enum:
        delete(packet.enum_type, allocator)
        destroy_string_slice(packet.options, allocator)
    case Unlocked_Recipes:
        destroy_string_slice(packet.recipes, allocator)
    case Trim_Data:
        for pattern in packet.patterns {
            delete(pattern.item_name, allocator)
            delete(pattern.pattern_id, allocator)
        }
        delete(packet.patterns, allocator)
        for material in packet.materials {
            delete(material.material_id, allocator)
            delete(material.colour, allocator)
            delete(material.item_name, allocator)
        }
        delete(packet.materials, allocator)
    case Feature_Registry:
        for feature in packet.features {
            delete(feature.name, allocator)
            delete(feature.json, allocator)
        }
        delete(packet.features, allocator)
    case Dimension_Data:
        for definition in packet.definitions {
            delete(definition.name, allocator)
        }
        delete(packet.definitions, allocator)
    case Server_Store_Info:
        if packet.store_info.set {
            delete(packet.store_info.value.store_id, allocator)
            delete(packet.store_info.value.store_name, allocator)
        }
    case Server_Presence_Info:
        if packet.presence_info.set {
            info := packet.presence_info.value
            if info.experience_name.set {
                delete(info.experience_name.value, allocator)
            }
            if info.world_name.set {
                delete(info.world_name.value, allocator)
            }
            delete(info.rich_presence_id, allocator)
        }
    case Camera_Aim_Assist_Actor_Priority:
        delete(packet.priority_data, allocator)
    case Update_Abilities:
        delete(packet.ability_data.layers, allocator)
    case Client_Cheat_Ability:
        delete(packet.ability_data.layers, allocator)
    case Container_Registry_Cleanup:
        delete(packet.removed_containers, allocator)
    case Unknown_Packet:
        delete(packet.payload, allocator)
    case:
    }
    value^ = nil
}

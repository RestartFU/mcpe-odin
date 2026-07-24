package gt_packet

import protocol "mcpe:gophertunnel/minecraft/protocol"
import mcpe_runtime "mcpe:runtime"

MAX_RESOURCE_PACK_RESPONSE_ENTRIES :: 1024

Pack_Response_Refused              :: u8(1)
Pack_Response_Send_Packs           :: u8(2)
Pack_Response_All_Packs_Downloaded :: u8(3)
Pack_Response_Completed            :: u8(4)

Resource_Pack_Type_Addon          :: u8(1)
Resource_Pack_Type_Cached         :: u8(2)
Resource_Pack_Type_Copy_Protected :: u8(3)
Resource_Pack_Type_Behaviour      :: u8(4)
Resource_Pack_Type_Persona_Piece  :: u8(5)
Resource_Pack_Type_Resources      :: u8(6)
Resource_Pack_Type_Skins          :: u8(7)
Resource_Pack_Type_World_Template :: u8(8)

Login :: struct {
    client_protocol:    i32,
    connection_request: []u8,
}

Resource_Packs_Info :: struct {
    texture_pack_required:          bool,
    has_addons:                     bool,
    has_scripts:                    bool,
    force_disable_vibrant_visuals:  bool,
    world_template_uuid:            protocol.UUID,
    world_template_version:         string,
    texture_packs:                  []protocol.Texture_Pack_Info,
}

Resource_Pack_Stack :: struct {
    texture_pack_required:           bool,
    texture_packs:                   []protocol.Stack_Resource_Pack,
    base_game_version:               string,
    experiments:                     []protocol.Experiment_Data,
    experiments_previously_toggled:  bool,
    include_editor_packs:            bool,
}

Resource_Pack_Client_Response :: struct {
    response:          u8,
    packs_to_download: []string,
}

Resource_Pack_Data_Info :: struct {
    uuid:            string,
    data_chunk_size: u32,
    chunk_count:     u32,
    size:            u64,
    hash:            []u8,
    premium:         bool,
    pack_type:       u8,
}

Resource_Pack_Chunk_Data :: struct {
    uuid:        string,
    chunk_index: u32,
    data_offset: u64,
    data:        []u8,
}

Resource_Pack_Chunk_Request :: struct {
    uuid:        string,
    chunk_index: i32,
}

destroy_resource_packs_info_value :: proc(
    packet: Resource_Packs_Info,
    allocator := context.allocator,
) {
    delete(packet.world_template_version, allocator)
    for pack in packet.texture_packs {
        owned_pack := pack
        protocol.destroy_texture_pack_info(&owned_pack, allocator)
    }
    delete(packet.texture_packs, allocator)
}

destroy_resource_packs_info_fields :: proc(
    packet: ^Resource_Packs_Info,
    allocator := context.allocator,
) {
    destroy_resource_packs_info_value(packet^, allocator)
    packet^ = {}
}

destroy_resource_pack_stack_value :: proc(
    packet: Resource_Pack_Stack,
    allocator := context.allocator,
) {
    for pack in packet.texture_packs {
        owned_pack := pack
        protocol.destroy_stack_resource_pack(&owned_pack, allocator)
    }
    delete(packet.texture_packs, allocator)
    delete(packet.base_game_version, allocator)
    for experiment in packet.experiments {
        owned_experiment := experiment
        protocol.destroy_experiment_data(&owned_experiment, allocator)
    }
    delete(packet.experiments, allocator)
}

destroy_resource_pack_stack_fields :: proc(
    packet: ^Resource_Pack_Stack,
    allocator := context.allocator,
) {
    destroy_resource_pack_stack_value(packet^, allocator)
    packet^ = {}
}

read_resource_packs_info :: proc(
    input: ^protocol.Reader,
) -> (packet: Resource_Packs_Info, err: mcpe_runtime.Error) {
    defer if err != nil {
        destroy_resource_packs_info_fields(&packet, input.allocator)
    }
    packet.texture_pack_required = protocol.read_bool(input) or_return
    packet.has_addons = protocol.read_bool(input) or_return
    packet.has_scripts = protocol.read_bool(input) or_return
    packet.force_disable_vibrant_visuals =
        protocol.read_bool(input) or_return
    packet.world_template_uuid = protocol.read_uuid(input) or_return
    packet.world_template_version = protocol.read_string(input) or_return
    count := protocol.read_u16(input) or_return
    if count > protocol.MAX_COLLECTION_ELEMENTS {
        err = packet_error(
            .Limit_Exceeded,
            "gophertunnel.packet.read_resource_packs_info",
            "texture pack list exceeds entry limit",
        )
        return
    }
    packet.texture_packs = make(
        []protocol.Texture_Pack_Info,
        int(count),
        input.allocator,
    )
    for &pack in packet.texture_packs {
        pack = protocol.read_texture_pack_info(input) or_return
    }
    return
}

read_resource_pack_stack :: proc(
    input: ^protocol.Reader,
) -> (packet: Resource_Pack_Stack, err: mcpe_runtime.Error) {
    defer if err != nil {
        destroy_resource_pack_stack_fields(&packet, input.allocator)
    }
    packet.texture_pack_required = protocol.read_bool(input) or_return
    pack_count := protocol.read_varuint32(input) or_return
    if pack_count > protocol.MAX_COLLECTION_ELEMENTS {
        err = packet_error(
            .Limit_Exceeded,
            "gophertunnel.packet.read_resource_pack_stack",
            "resource pack stack exceeds entry limit",
        )
        return
    }
    packet.texture_packs = make(
        []protocol.Stack_Resource_Pack,
        int(pack_count),
        input.allocator,
    )
    for &pack in packet.texture_packs {
        pack = protocol.read_stack_resource_pack(input) or_return
    }
    packet.base_game_version = protocol.read_string(input) or_return
    experiment_count := protocol.read_u32(input) or_return
    if experiment_count > protocol.MAX_COLLECTION_ELEMENTS {
        err = packet_error(
            .Limit_Exceeded,
            "gophertunnel.packet.read_resource_pack_stack",
            "experiment list exceeds entry limit",
        )
        return
    }
    packet.experiments = make(
        []protocol.Experiment_Data,
        int(experiment_count),
        input.allocator,
    )
    for &experiment in packet.experiments {
        experiment = protocol.read_experiment_data(input) or_return
    }
    packet.experiments_previously_toggled =
        protocol.read_bool(input) or_return
    packet.include_editor_packs = protocol.read_bool(input) or_return
    return
}

read_resource_pack_client_response :: proc(
    input: ^protocol.Reader,
) -> (
    packet: Resource_Pack_Client_Response,
    err: mcpe_runtime.Error,
) {
    packet.response = protocol.read_u8(input) or_return
    count := protocol.read_u16(input) or_return
    if count > MAX_RESOURCE_PACK_RESPONSE_ENTRIES {
        err = packet_error(
            .Limit_Exceeded,
            "gophertunnel.packet.read_resource_pack_client_response",
            "resource pack response exceeds entry limit",
        )
        return
    }
    packet.packs_to_download = make(
        []string,
        int(count),
        input.allocator,
    )
    for &entry, index in packet.packs_to_download {
        entry, err = protocol.read_string(input)
        if err != nil {
            for previous in packet.packs_to_download[:index] {
                delete(previous, input.allocator)
            }
            delete(packet.packs_to_download, input.allocator)
            packet.packs_to_download = nil
            return
        }
    }
    return
}

read_resource_pack_data_info :: proc(
    input: ^protocol.Reader,
) -> (packet: Resource_Pack_Data_Info, err: mcpe_runtime.Error) {
    defer if err != nil {
        delete(packet.uuid, input.allocator)
        delete(packet.hash, input.allocator)
        packet = {}
    }
    packet.uuid = protocol.read_string(input) or_return
    packet.data_chunk_size = protocol.read_u32(input) or_return
    packet.chunk_count = protocol.read_u32(input) or_return
    packet.size = protocol.read_u64(input) or_return
    packet.hash = protocol.read_byte_slice(input) or_return
    packet.premium = protocol.read_bool(input) or_return
    packet.pack_type = protocol.read_u8(input) or_return
    return
}

read_resource_pack_chunk_data :: proc(
    input: ^protocol.Reader,
) -> (packet: Resource_Pack_Chunk_Data, err: mcpe_runtime.Error) {
    defer if err != nil {
        delete(packet.uuid, input.allocator)
        delete(packet.data, input.allocator)
        packet = {}
    }
    packet.uuid = protocol.read_string(input) or_return
    packet.chunk_index = protocol.read_u32(input) or_return
    packet.data_offset = protocol.read_u64(input) or_return
    packet.data = protocol.read_byte_slice(input) or_return
    return
}

read_resource_pack_chunk_request :: proc(
    input: ^protocol.Reader,
) -> (packet: Resource_Pack_Chunk_Request, err: mcpe_runtime.Error) {
    packet.uuid = protocol.read_string(input) or_return
    packet.chunk_index, err = protocol.read_i32(input)
    if err != nil {
        delete(packet.uuid, input.allocator)
        packet = {}
    }
    return
}

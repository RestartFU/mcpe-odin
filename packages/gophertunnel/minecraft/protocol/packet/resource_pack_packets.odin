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

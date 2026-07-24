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
    Play_Status,
    Server_To_Client_Handshake,
    Client_To_Server_Handshake,
    Disconnect,
    Set_Time,
    Set_Health,
    Set_Difficulty,
    Request_Chunk_Radius,
    Chunk_Radius_Updated,
    Network_Stack_Latency,
    Network_Settings,
    Request_Network_Settings,
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
    case Play_Status:                 id = IDPlayStatus
    case Server_To_Client_Handshake:  id = IDServerToClientHandshake
    case Client_To_Server_Handshake:  id = IDClientToServerHandshake
    case Disconnect:                  id = IDDisconnect
    case Set_Time:                    id = IDSetTime
    case Set_Health:                  id = IDSetHealth
    case Set_Difficulty:              id = IDSetDifficulty
    case Request_Chunk_Radius:        id = IDRequestChunkRadius
    case Chunk_Radius_Updated:        id = IDChunkRadiusUpdated
    case Network_Stack_Latency:       id = IDNetworkStackLatency
    case Network_Settings:            id = IDNetworkSettings
    case Request_Network_Settings:    id = IDRequestNetworkSettings
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
    case Server_To_Client_Handshake:
        delete(packet.jwt, allocator)
    case Disconnect:
        delete(packet.message, allocator)
        delete(packet.filtered_message, allocator)
    case Unknown_Packet:
        delete(packet.payload, allocator)
    case:
    }
    value^ = nil
}

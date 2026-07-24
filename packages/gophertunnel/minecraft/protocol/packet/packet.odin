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
    Set_Spawn_Position,
    Respawn,
    Player_Hot_Bar,
    Set_Commands_Enabled,
    Set_Difficulty,
    Set_Player_Game_Type,
    Simple_Event,
    Spawn_Experience_Orb,
    Request_Chunk_Radius,
    Chunk_Radius_Updated,
    Show_Credits,
    Transfer,
    Stop_Sound,
    Set_Last_Hurt_By,
    Set_Default_Game_Type,
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
    case Set_Spawn_Position:          id = IDSetSpawnPosition
    case Respawn:                     id = IDRespawn
    case Player_Hot_Bar:              id = IDPlayerHotBar
    case Set_Commands_Enabled:        id = IDSetCommandsEnabled
    case Set_Difficulty:              id = IDSetDifficulty
    case Set_Player_Game_Type:        id = IDSetPlayerGameType
    case Simple_Event:                id = IDSimpleEvent
    case Spawn_Experience_Orb:        id = IDSpawnExperienceOrb
    case Request_Chunk_Radius:        id = IDRequestChunkRadius
    case Chunk_Radius_Updated:        id = IDChunkRadiusUpdated
    case Show_Credits:                id = IDShowCredits
    case Transfer:                    id = IDTransfer
    case Stop_Sound:                  id = IDStopSound
    case Set_Last_Hurt_By:            id = IDSetLastHurtBy
    case Set_Default_Game_Type:       id = IDSetDefaultGameType
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
    case Transfer:
        delete(packet.address, allocator)
    case Stop_Sound:
        delete(packet.sound_name, allocator)
    case Unknown_Packet:
        delete(packet.payload, allocator)
    case:
    }
    value^ = nil
}

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

write_payload :: proc(
    output: ^protocol.Writer,
    value: Packet,
) -> mcpe_runtime.Error {
    switch packet in value {
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
    case Set_Time:
        protocol.write_varint32(output, packet.time)
    case Set_Health:
        protocol.write_varint32(output, packet.health)
    case Set_Difficulty:
        protocol.write_varuint32(output, packet.difficulty)
    case Request_Chunk_Radius:
        protocol.write_varint32(output, packet.chunk_radius)
        protocol.write_u8(output, packet.max_chunk_radius)
    case Chunk_Radius_Updated:
        protocol.write_varint32(output, packet.chunk_radius)
    case Network_Stack_Latency:
        protocol.write_i64(output, packet.timestamp)
        protocol.write_bool(output, packet.needs_response)
    case Network_Settings:
        protocol.write_u16(output, packet.compression_threshold)
        protocol.write_u16(output, packet.compression_algorithm)
        protocol.write_bool(output, packet.client_throttle)
        protocol.write_u8(output, packet.client_throttle_threshold)
        protocol.write_f32(output, packet.client_throttle_scalar)
    case Request_Network_Settings:
        protocol.write_be_i32(output, packet.client_protocol)
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
    case IDSetTime:
        packet := Set_Time{}
        packet.time = protocol.read_varint32(&input) or_return
        value = packet
    case IDSetHealth:
        packet := Set_Health{}
        packet.health = protocol.read_varint32(&input) or_return
        value = packet
    case IDSetDifficulty:
        packet := Set_Difficulty{}
        packet.difficulty = protocol.read_varuint32(&input) or_return
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
    case IDNetworkStackLatency:
        packet := Network_Stack_Latency{}
        packet.timestamp = protocol.read_i64(&input) or_return
        packet.needs_response = protocol.read_bool(&input) or_return
        value = packet
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
    case IDRequestNetworkSettings:
        packet := Request_Network_Settings{}
        packet.client_protocol = protocol.read_be_i32(&input) or_return
        value = packet
    case:
        value = Unknown_Packet{
            packet_id = header.packet_id,
            payload = clone_payload(&input) or_return,
        }
    }
    if header.packet_id == IDPlayStatus ||
       header.packet_id == IDServerToClientHandshake ||
       header.packet_id == IDClientToServerHandshake ||
       header.packet_id == IDDisconnect ||
       header.packet_id == IDSetTime ||
       header.packet_id == IDSetHealth ||
       header.packet_id == IDSetDifficulty ||
       header.packet_id == IDRequestChunkRadius ||
       header.packet_id == IDChunkRadiusUpdated ||
       header.packet_id == IDNetworkStackLatency ||
       header.packet_id == IDNetworkSettings ||
       header.packet_id == IDRequestNetworkSettings {
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

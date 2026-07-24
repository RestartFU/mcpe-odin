package gt_packet

import "core:slice"
import "core:testing"
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

package raknet_fixtures

import "core:encoding/hex"
import "core:fmt"
import "core:os"
import raknet "mcpe:raknet"
import message "mcpe:raknet/message"
import wire "mcpe:raknet/wire"
import mcpe_runtime "mcpe:runtime"

emit :: proc(name: string, data: []u8) {
    fmt.printf("%s ", name)
    for value in data {
        fmt.printf("%02x", value)
    }
    fmt.println()
}

fixtures :: proc() {
    address := message.address_v4(127, 0, 0, 1, 19132)

    connected_ping := message.marshal_connected_ping({
        ping_time = 0x0102_0304_0506_0708,
    })
    emit("connected_ping", connected_ping[:])

    connected_pong := message.marshal_connected_pong({
        ping_time = 0x0102_0304_0506_0708,
        pong_time = 0x1112_1314_1516_1718,
    })
    emit("connected_pong", connected_pong[:])

    connection_request := message.marshal_connection_request({
        client_guid = -0x0102_0304_0506_070,
        request_time = 0x2122_2324_2526_2728,
        secure = true,
    })
    emit("connection_request", connection_request[:])

    unconnected_ping := message.marshal_unconnected_ping({
        ping_time = 0x3132_3334_3536_3738,
        client_guid = -0x1112_1314_1516_171,
    })
    emit("unconnected_ping", unconnected_ping[:])

    unconnected_pong := message.marshal_unconnected_pong({
        ping_time = 0x4142_4344_4546_4748,
        server_guid = -0x2122_2324_2526_272,
        data = transmute([]u8)string("MCPE;fixture"),
    })
    emit("unconnected_pong", unconnected_pong.data[:])
    wire.writer_destroy(&unconnected_pong)

    incompatible := message.marshal_incompatible_protocol_version({
        server_protocol = 11,
        server_guid = -0x3132_3334_3536_373,
    })
    emit("incompatible_protocol", incompatible[:])

    reply_1 := message.marshal_open_connection_reply_1({
        server_guid = -0x4142_4344_4546_474,
        server_has_security = true,
        cookie = 0xa1b2_c3d4,
        mtu = 1492,
    })
    emit("open_connection_reply_1", reply_1.data[:])
    wire.writer_destroy(&reply_1)

    request_1, request_1_err := message.marshal_open_connection_request_1({
        client_protocol = 11,
        mtu = 1200,
    })
    assert(request_1_err == nil)
    emit("open_connection_request_1", request_1.data[:])
    wire.writer_destroy(&request_1)

    request_2 := message.marshal_open_connection_request_2({
        server_address = address,
        mtu = 1200,
        client_guid = -0x5152_5354_5556_575,
        server_has_security = true,
        cookie = 0xb1c2_d3e4,
    })
    emit("open_connection_request_2", request_2.data[:])
    wire.writer_destroy(&request_2)

    reply_2 := message.marshal_open_connection_reply_2({
        server_guid = -0x6162_6364_6566_676,
        client_address = address,
        mtu = 1200,
        do_security = false,
    })
    emit("open_connection_reply_2", reply_2.data[:])
    wire.writer_destroy(&reply_2)

    accepted := message.marshal_connection_request_accepted({
        client_address = address,
        system_index = 3,
        ping_time = 0x5152_5354_5556_5758,
        pong_time = 0x6162_6364_6566_6768,
    })
    emit("connection_request_accepted", accepted.data[:])
    wire.writer_destroy(&accepted)

    incoming := message.marshal_new_incoming_connection({
        server_address = address,
        ping_time = 0x7172_7374_7576_7778,
        pong_time = 0x0101_0202_0303_0404,
    })
    emit("new_incoming_connection", incoming.data[:])
    wire.writer_destroy(&incoming)
}

wire_fixtures :: proc() {
    packet := raknet.Packet{
        reliability = .Reliable_Ordered,
        message_index = 0x010203,
        order_index = 0x040506,
        content = []u8{0x11, 0x22, 0x33},
        split = true,
        split_count = 3,
        split_index = 1,
        split_id = 0x0708,
    }
    writer := raknet.writer()
    raknet.write_packet(&writer, &packet)
    emit("encapsulated_packet", writer.data[:])
    raknet.writer_destroy(&writer)

    reserved := raknet.Packet{
        reliability = raknet.Reliability(5),
        content = []u8{0x42},
    }
    writer = raknet.writer()
    raknet.write_packet(&writer, &reserved)
    emit("reserved_reliability_packet", writer.data[:])
    raknet.writer_destroy(&writer)

    acknowledgement := raknet.acknowledgement_init()
    defer raknet.acknowledgement_destroy(&acknowledgement)
    values := []raknet.UInt24{1, 1, 2, 8}
    for value in values {
        raknet.acknowledgement_add(&acknowledgement, value)
    }
    writer = raknet.writer()
    raknet.write_u8(
        &writer,
        raknet.BIT_FLAG_ACK | raknet.BIT_FLAG_DATAGRAM,
    )
    _ = raknet.acknowledgement_write(&acknowledgement, &writer, 1400)
    emit("acknowledgement", writer.data[:])
    raknet.writer_destroy(&writer)
}

round_trip :: proc(name: string, data: []u8) -> mcpe_runtime.Error {
    if len(data) == 0 {
        return mcpe_runtime.make_error(
            .Unexpected_EOF,
            "raknet-fixtures.round_trip",
        )
    }
    payload := data[1:]
    switch name {
    case "connected_ping":
        packet := message.unmarshal_connected_ping(payload) or_return
        encoded := message.marshal_connected_ping(packet)
        emit(name, encoded[:])
    case "connected_pong":
        packet := message.unmarshal_connected_pong(payload) or_return
        encoded := message.marshal_connected_pong(packet)
        emit(name, encoded[:])
    case "connection_request":
        packet := message.unmarshal_connection_request(payload) or_return
        encoded := message.marshal_connection_request(packet)
        emit(name, encoded[:])
    case "unconnected_ping":
        packet := message.unmarshal_unconnected_ping(payload) or_return
        encoded := message.marshal_unconnected_ping(packet)
        emit(name, encoded[:])
    case "unconnected_pong":
        packet := message.unmarshal_unconnected_pong(payload) or_return
        encoded := message.marshal_unconnected_pong(packet)
        defer wire.writer_destroy(&encoded)
        emit(name, encoded.data[:])
    case "incompatible_protocol":
        packet := message.unmarshal_incompatible_protocol_version(payload) or_return
        encoded := message.marshal_incompatible_protocol_version(packet)
        emit(name, encoded[:])
    case "open_connection_reply_1":
        packet := message.unmarshal_open_connection_reply_1(payload) or_return
        encoded := message.marshal_open_connection_reply_1(packet)
        defer wire.writer_destroy(&encoded)
        emit(name, encoded.data[:])
    case "open_connection_request_1":
        packet := message.unmarshal_open_connection_request_1(payload) or_return
        encoded := message.marshal_open_connection_request_1(packet) or_return
        defer wire.writer_destroy(&encoded)
        emit(name, encoded.data[:])
    case "open_connection_request_2":
        packet := message.unmarshal_open_connection_request_2(
            payload,
            true,
        ) or_return
        encoded := message.marshal_open_connection_request_2(packet)
        defer wire.writer_destroy(&encoded)
        emit(name, encoded.data[:])
    case "open_connection_reply_2":
        packet := message.unmarshal_open_connection_reply_2(payload) or_return
        encoded := message.marshal_open_connection_reply_2(packet)
        defer wire.writer_destroy(&encoded)
        emit(name, encoded.data[:])
    case "connection_request_accepted":
        packet := message.unmarshal_connection_request_accepted(payload) or_return
        encoded := message.marshal_connection_request_accepted(packet)
        defer wire.writer_destroy(&encoded)
        emit(name, encoded.data[:])
    case "new_incoming_connection":
        packet := message.unmarshal_new_incoming_connection(payload) or_return
        encoded := message.marshal_new_incoming_connection(packet)
        defer wire.writer_destroy(&encoded)
        emit(name, encoded.data[:])
    case:
        return mcpe_runtime.make_error(
            .Invalid_Argument,
            "raknet-fixtures.round_trip",
            "unknown fixture",
        )
    }
    return nil
}

main :: proc() {
    if len(os.args) == 1 {
        fixtures()
        return
    }
    if len(os.args) == 2 && os.args[1] == "wire" {
        wire_fixtures()
        return
    }
    if len(os.args) != 4 || os.args[1] != "round-trip" {
        fmt.eprintln("usage: raknet-fixtures [round-trip <name> <hex>]")
        os.exit(2)
    }
    data, ok := hex.decode(transmute([]u8)os.args[3])
    if !ok {
        fmt.eprintln("invalid hex")
        os.exit(2)
    }
    defer delete(data)
    if err := round_trip(os.args[2], data); err != nil {
        fmt.eprintf("%s: %s\n", err.operation, err.message)
        mcpe_runtime.destroy_error(err)
        os.exit(1)
    }
}

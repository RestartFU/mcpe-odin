package raknet_fixtures

import "core:fmt"
import message "mcpe:raknet/message"
import wire "mcpe:raknet/wire"

emit :: proc(name: string, data: []u8) {
    fmt.printf("%s ", name)
    for value in data {
        fmt.printf("%02x", value)
    }
    fmt.println()
}

main :: proc() {
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

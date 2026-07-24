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
}

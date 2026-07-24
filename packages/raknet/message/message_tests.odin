package raknet_message

import "core:testing"
import "core:slice"
import wire "mcpe:raknet/wire"
import mcpe_runtime "mcpe:runtime"

@(test)
address_v4_round_trip :: proc(t: ^testing.T) {
    expected := address_v4(127, 0, 0, 1, 19132)
    w := wire.writer()
    defer wire.writer_destroy(&w)
    write_address(&w, expected)
    r := wire.reader(w.data[:])
    actual, err := read_address(&r)
    testing.expect(t, err == nil)
    testing.expect_value(t, actual, expected)
}

@(test)
address_v6_round_trip_ignores_scope_like_upstream :: proc(t: ^testing.T) {
    bytes := [16]u8{
        0x20, 0x01, 0x0d, 0xb8,
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 1,
    }
    expected := address_v6(bytes, 19132, 99)
    w := wire.writer()
    defer wire.writer_destroy(&w)
    write_address(&w, expected)
    testing.expect_value(t, wire.load_u32_be(w.data[len(w.data) - 4:]), u32(0))

    r := wire.reader(w.data[:])
    actual, err := read_address(&r)
    testing.expect(t, err == nil)
    expected.scope_id = 0
    testing.expect_value(t, actual, expected)
}

@(test)
address_unknown_family_decodes_as_ipv6_like_upstream :: proc(t: ^testing.T) {
    data: [ADDRESS_V6_SIZE]u8
    data[0] = 5
    data[3] = 0x4a
    data[4] = 0xbc
    data[9] = 0x20
    data[10] = 0x01
    data[len(data) - 1] = 7

    r := wire.reader(data[:])
    actual, err := read_address(&r)
    testing.expect(t, err == nil)
    testing.expect_value(t, actual.family, Address_Family.IPv6)
    testing.expect_value(t, actual.port, u16(19132))
    testing.expect_value(t, actual.address[0], u8(0x20))
    testing.expect_value(t, actual.address[1], u8(0x01))
    testing.expect_value(t, actual.scope_id, u32(0))
}

@(test)
reply_one_sizes_security_preflight_from_raw_byte :: proc(t: ^testing.T) {
    data: [35]u8
    data[24] = 2
    wire.store_u32_be(data[25:29], 0xa1b2c3d4)
    wire.store_u16_be(data[29:31], 1492)

    _, err := unmarshal_open_connection_reply_1(data[:31])
    testing.expect(t, err != nil)
    if err != nil {
        testing.expect_value(
            t,
            err.kind,
            mcpe_runtime.Error_Kind.Unexpected_EOF,
        )
        mcpe_runtime.destroy_error(err)
    }

    actual, full_err := unmarshal_open_connection_reply_1(data[:])
    testing.expect(t, full_err == nil)
    testing.expect(t, actual.server_has_security)
    testing.expect_value(t, actual.cookie, u32(0xa1b2c3d4))
    testing.expect_value(t, actual.mtu, u16(1492))
}

@(test)
unconnected_ping_round_trip :: proc(t: ^testing.T) {
    expected := Unconnected_Ping{ping_time = 1234567, client_guid = -42}
    data := marshal_unconnected_ping(expected)
    actual, err := unmarshal_unconnected_ping(data[1:])
    testing.expect(t, err == nil)
    testing.expect_value(t, actual, expected)
}

@(test)
unconnected_pong_round_trip :: proc(t: ^testing.T) {
    payload := []u8{1, 2, 3, 4}
    expected := Unconnected_Pong{ping_time = 99, server_guid = 123, data = payload}
    w := marshal_unconnected_pong(expected)
    defer wire.writer_destroy(&w)
    actual, err := unmarshal_unconnected_pong(w.data[1:])
    testing.expect(t, err == nil)
    testing.expect_value(t, actual.ping_time, expected.ping_time)
    testing.expect_value(t, actual.server_guid, expected.server_guid)
    testing.expect(t, slice.equal(actual.data, expected.data))
}

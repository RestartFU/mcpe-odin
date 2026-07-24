package gophertunnel_fixtures

import "core:fmt"
import nbt "mcpe:gophertunnel/minecraft/nbt"
import protocol "mcpe:gophertunnel/minecraft/protocol"
import packet "mcpe:gophertunnel/minecraft/protocol/packet"

emit :: proc(name: string, data: []u8) {
    fmt.printf("%s ", name)
    for value in data {
        fmt.printf("%02x", value)
    }
    fmt.println()
}

emit_dump :: proc(name: string, root: ^nbt.Value) {
    data, encode_err := nbt.marshal(root, .Little_Endian)
    assert(encode_err == nil)
    defer delete(data)
    text, dump_err := nbt.dump(data, .Little_Endian)
    assert(dump_err == nil)
    defer delete(text)
    emit(name, transmute([]u8)text)
}

emit_packet :: proc(
    name: string,
    value: packet.Packet,
    sender_sub_client: u8 = 0,
    target_sub_client: u8 = 0,
) {
    data, err := packet.encode_packet(
        value,
        sender_sub_client,
        target_sub_client,
    )
    assert(err == nil)
    defer delete(data)
    emit(name, data)
}

nbt_fixture :: proc() -> nbt.Value {
    list_one := nbt.new_value(nbt.value_int(1))
    list_two := nbt.new_value(nbt.value_int(-2))
    list_three := nbt.new_value(nbt.value_int(3))
    list := make([]^nbt.Value, 3)
    list[0] = list_one
    list[1] = list_two
    list[2] = list_three
    nested_value := nbt.new_value(nbt.value_string("inside"))
    nested_entries := make([]nbt.Named_Value, 1)
    nested_entries[0] = {name = "Name", value = nested_value}
    nested := nbt.new_value({
        tag = .Compound,
        compound = nested_entries,
    })
    entries := make([]nbt.Named_Value, 12)
    entries[0] = {
        name = "Byte",
        value = nbt.new_value(nbt.value_byte(0x7f)),
    }
    entries[1] = {
        name = "Short",
        value = nbt.new_value(nbt.value_short(-1234)),
    }
    entries[2] = {
        name = "Int",
        value = nbt.new_value(nbt.value_int(-123_456)),
    }
    entries[3] = {
        name = "Long",
        value = nbt.new_value(nbt.value_long(-1_234_567_890_123)),
    }
    entries[4] = {
        name = "Float",
        value = nbt.new_value(nbt.value_float(123.5)),
    }
    entries[5] = {
        name = "Double",
        value = nbt.new_value(nbt.value_double(-987.25)),
    }
    entries[6] = {
        name = "Bytes",
        value = nbt.new_value(nbt.value_byte_array([]u8{1, 2, 3, 4})),
    }
    entries[7] = {
        name = "String",
        value = nbt.new_value(nbt.value_string("Minecraft")),
    }
    entries[8] = {
        name = "List",
        value = nbt.new_value({
            tag = .List,
            list_type = .Int,
            list = list,
        }),
    }
    entries[9] = {name = "Nested", value = nested}
    entries[10] = {
        name = "Ints",
        value = nbt.new_value(nbt.value_int_array([]i32{-1, 0, 1})),
    }
    entries[11] = {
        name = "Longs",
        value = nbt.new_value(
            nbt.value_long_array([]i64{min(i64), max(i64)}),
        ),
    }
    return {tag = .Compound, compound = entries}
}

main :: proc() {
    output := protocol.writer()
    defer protocol.writer_destroy(&output)

    protocol.write_u16(&output, 0x1234)
    protocol.write_i16(&output, -1234)
    protocol.write_u32(&output, 0x1234_5678)
    protocol.write_i32(&output, -123_456)
    protocol.write_be_i32(&output, 0x1234_5678)
    protocol.write_u64(&output, 0x0123_4567_89ab_cdef)
    protocol.write_i64(&output, -123_456_789)
    protocol.write_f32(&output, 123.5)
    protocol.write_f64(&output, -987.25)
    protocol.write_bool(&output, true)
    protocol.write_bool(&output, false)

    varuint32_values := [?]u32{0, 1, 127, 128, 255, 300, max(u32)}
    for value in varuint32_values {
        protocol.write_varuint32(&output, value)
    }
    varint32_values := [?]i32{
        min(i32),
        -1_000_000,
        -1,
        0,
        1,
        1_000_000,
        max(i32),
    }
    for value in varint32_values {
        protocol.write_varint32(&output, value)
    }
    varuint64_values := [?]u64{0, 1, 127, 128, 300, max(u64)}
    for value in varuint64_values {
        protocol.write_varuint64(&output, value)
    }
    varint64_values := [?]i64{
        min(i64),
        -1_000_000_000_000,
        -1,
        0,
        1,
        max(i64),
    }
    for value in varint64_values {
        protocol.write_varint64(&output, value)
    }

    protocol.write_string(&output, "Minecraft")
    protocol.write_string_utf(&output, "Bedrock")
    protocol.write_byte_slice(&output, []u8{1, 2, 3, 4})
    protocol.write_vec2(&output, {1.25, -2.5})
    protocol.write_vec3(&output, {1.25, -2.5, 9.75})
    protocol.write_block_pos(&output, {-12, 64, 3456})
    protocol.write_chunk_pos(&output, {-100, 200})
    protocol.write_sub_chunk_pos(&output, {-2, 10, 44})
    protocol.write_sound_pos(&output, {1.25, -2.5, 9.75})
    protocol.write_byte_float(&output, 180)
    protocol.write_uuid(
        &output,
        {
            0x00,
            0x11,
            0x22,
            0x33,
            0x44,
            0x55,
            0x66,
            0x77,
            0x88,
            0x99,
            0xaa,
            0xbb,
            0xcc,
            0xdd,
            0xee,
            0xff,
        },
    )
    colour := protocol.RGBA{r = 1, g = 2, b = 3, a = 4}
    protocol.write_rgba(&output, colour)
    protocol.write_var_rgba(&output, colour)
    emit("protocol_codec", protocol.writer_bytes(&output))

    root := nbt_fixture()
    encodings := [?]nbt.Encoding{
        .Network_Little_Endian,
        .Little_Endian,
        .Network_Big_Endian,
        .Big_Endian,
    }
    names := [?]string{
        "nbt_network_little",
        "nbt_little",
        "nbt_network_big",
        "nbt_big",
    }
    for encoding, index in encodings {
        data, encode_err := nbt.marshal(&root, encoding)
        assert(encode_err == nil)
        emit(names[index], data)
        delete(data)
    }

    dump_list := nbt.value_list(
        .Int,
        []nbt.Value{
            nbt.value_int(1),
            nbt.value_int(-2),
            nbt.value_int(3),
        },
    )
    dump_root := nbt.value_compound(
        []nbt.Named_Value{nbt.named_value("Values", dump_list)},
    )
    defer nbt.destroy_value(&dump_root)
    emit_dump("nbt_dump", &dump_root)

    inner := nbt.new_value(
        nbt.value_list(.Int, []nbt.Value{nbt.value_int(1)}),
    )
    nested_children := make([]^nbt.Value, 1)
    nested_children[0] = inner
    nested_root := nbt.value_compound(
        []nbt.Named_Value{
            nbt.named_value(
                "Values",
                {
                    tag = .List,
                    list_type = .List,
                    list = nested_children,
                },
            ),
        },
    )
    defer nbt.destroy_value(&nested_root)
    emit_dump("nbt_dump_nested", &nested_root)

    empty_string_root := nbt.value_compound(
        []nbt.Named_Value{
            nbt.named_value(
                "Values",
                {tag = .List, list_type = .String},
            ),
        },
    )
    defer nbt.destroy_value(&empty_string_root)
    emit_dump("nbt_dump_empty_string", &empty_string_root)

    empty_int_root := nbt.value_compound(
        []nbt.Named_Value{
            nbt.named_value(
                "Values",
                {tag = .List, list_type = .Int},
            ),
        },
    )
    defer nbt.destroy_value(&empty_int_root)
    emit_dump("nbt_dump_empty_int", &empty_int_root)

    emit_packet(
        "packet_request_network_settings",
        packet.Request_Network_Settings{client_protocol = 1001},
        2,
        3,
    )
    emit_packet(
        "packet_network_settings",
        packet.Network_Settings{
            compression_threshold = 256,
            compression_algorithm = packet.Compression_Algorithm_Snappy,
            client_throttle = true,
            client_throttle_threshold = 12,
            client_throttle_scalar = 0.75,
        },
    )
    emit_packet(
        "packet_disconnect",
        packet.Disconnect{
            reason = 57,
            message = "Disconnected",
            filtered_message = "Filtered",
        },
    )
    emit_packet(
        "packet_disconnect_hidden",
        packet.Disconnect{
            reason = 57,
            hide_disconnection_screen = true,
        },
    )
    emit_packet(
        "packet_set_time",
        packet.Set_Time{time = -12_345},
    )
    emit_packet(
        "packet_network_stack_latency",
        packet.Network_Stack_Latency{
            timestamp = -1_234_567_890,
            needs_response = true,
        },
    )

    batch_time, batch_time_err := packet.encode_packet(
        packet.Set_Time{time = 42},
    )
    assert(batch_time_err == nil)
    defer delete(batch_time)
    batch_settings, batch_settings_err := packet.encode_packet(
        packet.Request_Network_Settings{client_protocol = 1001},
    )
    assert(batch_settings_err == nil)
    defer delete(batch_settings)
    batch, batch_err := packet.encode_batch(
        [][]u8{batch_time, batch_settings},
    )
    assert(batch_err == nil)
    defer delete(batch)
    emit("packet_batch", batch)
}

package gt_nbt

import "core:slice"
import "core:testing"
import mcpe_runtime "mcpe:runtime"

test_compound :: proc() -> Value {
    entries := [8]Named_Value{
        named_value("Byte", value_byte(0x7f)),
        named_value("Short", value_short(-1234)),
        named_value("Int", value_int(-123_456)),
        named_value("Long", value_long(-1_234_567_890_123)),
        named_value("String", value_string("Minecraft")),
        named_value(
            "List",
            value_list(
                .Int,
                []Value{value_int(1), value_int(-2), value_int(3)},
            ),
        ),
        named_value(
            "Bytes",
            value_byte_array([]u8{1, 2, 3, 4}),
        ),
        named_value(
            "Longs",
            value_long_array([]i64{min(i64), max(i64)}),
        ),
    }
    return value_compound(entries[:])
}

@(test)
empty_compound_matches_encoding_headers :: proc(t: ^testing.T) {
    root := Value{tag = .Compound}
    encodings := [?]Encoding{
        .Network_Little_Endian,
        .Little_Endian,
        .Network_Big_Endian,
        .Big_Endian,
    }
    expected := [?][]u8{
        {0x0a, 0x00, 0x00},
        {0x0a, 0x00, 0x00, 0x00},
        {0x0a, 0x00},
        {0x0a, 0x00, 0x00, 0x00},
    }
    for encoding, index in encodings {
        data, err := marshal(&root, encoding)
        testing.expect(t, err == nil)
        if err != nil {
            mcpe_runtime.destroy_error(err)
            continue
        }
        testing.expect(t, slice.equal(data, expected[index]))
        delete(data)
    }
}

@(test)
all_binary_encodings_round_trip_tagged_values :: proc(t: ^testing.T) {
    root := test_compound()
    defer destroy_value(&root)
    encodings := [?]Encoding{
        .Network_Little_Endian,
        .Little_Endian,
        .Network_Big_Endian,
        .Big_Endian,
    }
    for encoding in encodings {
        data, marshal_err := marshal(&root, encoding)
        testing.expect(t, marshal_err == nil)
        if marshal_err != nil {
            mcpe_runtime.destroy_error(marshal_err)
            continue
        }
        decoded, root_name, decode_err := unmarshal(data, encoding)
        testing.expect(t, decode_err == nil)
        if decode_err != nil {
            mcpe_runtime.destroy_error(decode_err)
            delete(data)
            continue
        }
        testing.expect_value(t, root_name, "")
        delete(root_name)

        int_value, found := compound_find(decoded, "Int")
        testing.expect(t, found)
        if found {
            testing.expect_value(t, int_value.tag, Tag.Int)
            testing.expect_value(t, int_value.int, i32(-123_456))
        }
        list_value, list_found := compound_find(decoded, "List")
        testing.expect(t, list_found)
        if list_found {
            testing.expect_value(t, list_value.list_type, Tag.Int)
            testing.expect_value(t, len(list_value.list), 3)
            testing.expect_value(t, list_value.list[1].int, i32(-2))
        }
        bytes_value, bytes_found := compound_find(decoded, "Bytes")
        testing.expect(t, bytes_found)
        if bytes_found {
            testing.expect(
                t,
                slice.equal(bytes_value.byte_array, []u8{1, 2, 3, 4}),
            )
        }

        encoded_again, second_err := marshal(decoded, encoding)
        testing.expect(t, second_err == nil)
        if second_err == nil {
            testing.expect(t, slice.equal(encoded_again, data))
            delete(encoded_again)
        } else {
            mcpe_runtime.destroy_error(second_err)
        }
        destroy_value(decoded)
        free(decoded)
        delete(data)
    }
}

@(test)
negative_array_lengths_are_rejected :: proc(t: ^testing.T) {
    // TAG_ByteArray, empty root name, then -1 as little-endian int32.
    data := []u8{0x07, 0x00, 0x00, 0xff, 0xff, 0xff, 0xff}
    value, name, err := unmarshal(data, .Little_Endian)
    testing.expect(t, value == nil)
    testing.expect_value(t, name, "")
    testing.expect(t, err != nil)
    if err != nil {
        testing.expect_value(t, err.kind, mcpe_runtime.Error_Kind.Malformed)
        mcpe_runtime.destroy_error(err)
    }
}

@(test)
allow_zero_decodes_empty_compound :: proc(t: ^testing.T) {
    value, name, err := unmarshal(
        []u8{0x00},
        .Network_Little_Endian,
        true,
    )
    testing.expect(t, err == nil)
    testing.expect_value(t, name, "")
    testing.expect(t, value != nil)
    if value != nil {
        testing.expect_value(t, value.tag, Tag.Compound)
        testing.expect_value(t, len(value.compound), 0)
        destroy_value(value)
        free(value)
    }
}

@(test)
heterogeneous_lists_are_rejected :: proc(t: ^testing.T) {
    first := new_value(value_int(1))
    second := new_value(value_long(2))
    root := Value{
        tag = .List,
        list_type = .Int,
        list = []^Value{first, second},
    }
    _, err := marshal(&root)
    testing.expect(t, err != nil)
    if err != nil {
        testing.expect_value(
            t,
            err.kind,
            mcpe_runtime.Error_Kind.Invalid_Argument,
        )
        mcpe_runtime.destroy_error(err)
    }
    free(first)
    free(second)
}

@(test)
tag_end_root_is_rejected :: proc(t: ^testing.T) {
    root := Value{tag = .End}
    _, err := marshal(&root)
    testing.expect(t, err != nil)
    if err != nil {
        testing.expect_value(
            t,
            err.kind,
            mcpe_runtime.Error_Kind.Invalid_Argument,
        )
        mcpe_runtime.destroy_error(err)
    }
}

@(test)
non_empty_tag_end_lists_are_rejected :: proc(t: ^testing.T) {
    child := new_value(Value{tag = .End})
    root := Value{
        tag = .List,
        list_type = .End,
        list = []^Value{child},
    }
    _, err := marshal(&root)
    testing.expect(t, err != nil)
    if err != nil {
        testing.expect_value(
            t,
            err.kind,
            mcpe_runtime.Error_Kind.Invalid_Argument,
        )
        mcpe_runtime.destroy_error(err)
    }
    free(child)
}

@(test)
marshal_rejects_excessive_list_nesting :: proc(t: ^testing.T) {
    nodes := make([]^Value, MAX_NESTING_DEPTH + 1)
    for index in 0..<len(nodes) {
        nodes[index] = new(Value)
        nodes[index].tag = .List
    }
    nodes[len(nodes) - 1].list_type = .End
    for reverse_index in 1..<len(nodes) {
        index := len(nodes) - reverse_index - 1
        nodes[index].list_type = .List
        nodes[index].list = make([]^Value, 1)
        nodes[index].list[0] = nodes[index + 1]
    }
    _, err := marshal(nodes[0])
    testing.expect(t, err != nil)
    if err != nil {
        testing.expect_value(
            t,
            err.kind,
            mcpe_runtime.Error_Kind.Limit_Exceeded,
        )
        mcpe_runtime.destroy_error(err)
    }
    destroy_value(nodes[0])
    free(nodes[0])
    delete(nodes)
}

@(test)
network_byte_limit_is_checked_before_bulk_read :: proc(t: ^testing.T) {
    // TAG_ByteArray, empty root name, then ZigZag(4 MiB + 1).
    data := []u8{0x07, 0x00, 0x82, 0x80, 0x80, 0x04}
    value, name, err := unmarshal(data, .Network_Little_Endian)
    testing.expect(t, value == nil)
    testing.expect_value(t, name, "")
    testing.expect(t, err != nil)
    if err != nil {
        testing.expect_value(
            t,
            err.kind,
            mcpe_runtime.Error_Kind.Limit_Exceeded,
        )
        mcpe_runtime.destroy_error(err)
    }
}

@(test)
large_byte_arrays_round_trip :: proc(t: ^testing.T) {
    bytes := make([]u8, 1_048_577)
    defer delete(bytes)
    bytes[len(bytes) - 1] = 0x7f
    root := Value{tag = .Byte_Array, byte_array = bytes}

    data, marshal_err := marshal(&root, .Little_Endian)
    testing.expect(t, marshal_err == nil)
    if marshal_err != nil {
        mcpe_runtime.destroy_error(marshal_err)
        return
    }
    defer delete(data)
    decoded, name, unmarshal_err := unmarshal(data, .Little_Endian)
    testing.expect(t, unmarshal_err == nil)
    if unmarshal_err != nil {
        mcpe_runtime.destroy_error(unmarshal_err)
        return
    }
    delete(name)
    testing.expect_value(t, len(decoded.byte_array), len(bytes))
    testing.expect_value(t, decoded.byte_array[len(bytes) - 1], u8(0x7f))
    destroy_value(decoded)
    free(decoded)
}

@(test)
network_lists_have_node_allocation_limit :: proc(t: ^testing.T) {
    // TAG_List, empty name, TAG_Byte, ZigZag(65,536).
    data := []u8{0x09, 0x00, 0x01, 0x80, 0x80, 0x08}
    value, name, err := unmarshal(data, .Network_Little_Endian)
    testing.expect(t, value == nil)
    testing.expect_value(t, name, "")
    testing.expect(t, err != nil)
    if err != nil {
        testing.expect_value(
            t,
            err.kind,
            mcpe_runtime.Error_Kind.Limit_Exceeded,
        )
        mcpe_runtime.destroy_error(err)
    }
}

@(test)
network_short_lists_require_two_bytes_per_item :: proc(t: ^testing.T) {
    // TAG_List, empty name, TAG_Short, count two, one payload byte.
    data := []u8{0x09, 0x00, 0x02, 0x04, 0x00}
    value, name, err := unmarshal(data, .Network_Little_Endian)
    testing.expect(t, value == nil)
    testing.expect_value(t, name, "")
    testing.expect(t, err != nil)
    if err != nil {
        testing.expect_value(
            t,
            err.kind,
            mcpe_runtime.Error_Kind.Unexpected_EOF,
        )
        mcpe_runtime.destroy_error(err)
    }
}

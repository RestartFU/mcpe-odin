package gt_protocol

import "core:mem"
import "core:strings"
import mcpe_runtime "mcpe:runtime"

MAX_FIELD_BYTES :: 64 * 1024 * 1024

Reader :: struct {
    data:           []u8,
    offset:         int,
    shield_id:      i32,
    limits_enabled: bool,
    allocator:      mem.Allocator,
}

Writer :: struct {
    data:      [dynamic]u8,
    shield_id: i32,
    allocator: mem.Allocator,
}

reader :: proc(
    data: []u8,
    shield_id: i32 = 0,
    enable_limits: bool = true,
    allocator: mem.Allocator = context.allocator,
) -> Reader {
    return {
        data = data,
        shield_id = shield_id,
        limits_enabled = enable_limits,
        allocator = allocator,
    }
}

writer :: proc(
    shield_id: i32 = 0,
    capacity: int = 256,
    allocator: mem.Allocator = context.allocator,
) -> Writer {
    return {
        data = make([dynamic]u8, 0, max(0, capacity), allocator),
        shield_id = shield_id,
        allocator = allocator,
    }
}

writer_reset :: proc(value: ^Writer, shield_id: i32 = 0) {
    clear(&value.data)
    value.shield_id = shield_id
}

writer_destroy :: proc(value: ^Writer) {
    delete(value.data)
    value^ = {}
}

writer_bytes :: proc(value: ^Writer) -> []u8 {
    return value.data[:]
}

remaining :: proc(value: ^Reader) -> int {
    return len(value.data) - value.offset
}

codec_error :: proc(
    kind: mcpe_runtime.Error_Kind,
    operation: string,
    message: string,
) -> mcpe_runtime.Error {
    return mcpe_runtime.make_error(kind, operation, message)
}

reader_take :: proc(
    value: ^Reader,
    count: int,
    operation: string,
) -> (data: []u8, err: mcpe_runtime.Error) {
    if count < 0 {
        err = codec_error(.Malformed, operation, "negative field length")
        return
    }
    if count > remaining(value) {
        err = codec_error(.Unexpected_EOF, operation, "truncated field")
        return
    }
    data = value.data[value.offset:value.offset + count]
    value.offset += count
    return
}

read_u8 :: proc(value: ^Reader) -> (result: u8, err: mcpe_runtime.Error) {
    data := reader_take(value, 1, "gophertunnel.protocol.read_u8") or_return
    return data[0], nil
}

read_i8 :: proc(value: ^Reader) -> (result: i8, err: mcpe_runtime.Error) {
    result = transmute(i8)(read_u8(value) or_return)
    return
}

read_bool :: proc(value: ^Reader) -> (result: bool, err: mcpe_runtime.Error) {
    result = (read_u8(value) or_return) != 0
    return
}

read_u16 :: proc(value: ^Reader) -> (result: u16, err: mcpe_runtime.Error) {
    data := reader_take(value, 2, "gophertunnel.protocol.read_u16") or_return
    result = u16(data[0]) | u16(data[1]) << 8
    return
}

read_i16 :: proc(value: ^Reader) -> (result: i16, err: mcpe_runtime.Error) {
    result = transmute(i16)(read_u16(value) or_return)
    return
}

read_u32 :: proc(value: ^Reader) -> (result: u32, err: mcpe_runtime.Error) {
    data := reader_take(value, 4, "gophertunnel.protocol.read_u32") or_return
    result = u32(data[0]) |
             u32(data[1]) << 8 |
             u32(data[2]) << 16 |
             u32(data[3]) << 24
    return
}

read_i32 :: proc(value: ^Reader) -> (result: i32, err: mcpe_runtime.Error) {
    result = transmute(i32)(read_u32(value) or_return)
    return
}

read_be_i32 :: proc(value: ^Reader) -> (result: i32, err: mcpe_runtime.Error) {
    data := reader_take(value, 4, "gophertunnel.protocol.read_be_i32") or_return
    raw := u32(data[0]) << 24 |
           u32(data[1]) << 16 |
           u32(data[2]) << 8 |
           u32(data[3])
    result = transmute(i32)raw
    return
}

read_u64 :: proc(value: ^Reader) -> (result: u64, err: mcpe_runtime.Error) {
    data := reader_take(value, 8, "gophertunnel.protocol.read_u64") or_return
    for byte, shift in data {
        result |= u64(byte) << (u64(shift) * 8)
    }
    return
}

read_i64 :: proc(value: ^Reader) -> (result: i64, err: mcpe_runtime.Error) {
    result = transmute(i64)(read_u64(value) or_return)
    return
}

read_f32 :: proc(value: ^Reader) -> (result: f32, err: mcpe_runtime.Error) {
    result = transmute(f32)(read_u32(value) or_return)
    return
}

read_f64 :: proc(value: ^Reader) -> (result: f64, err: mcpe_runtime.Error) {
    result = transmute(f64)(read_u64(value) or_return)
    return
}

read_varuint32 :: proc(value: ^Reader) -> (result: u32, err: mcpe_runtime.Error) {
    for shift := 0; shift < 35; shift += 7 {
        byte := read_u8(value) or_return
        result |= u32(byte & 0x7f) << u32(shift)
        if byte & 0x80 == 0 {
            return
        }
    }
    err = codec_error(
        .Malformed,
        "gophertunnel.protocol.read_varuint32",
        "varuint32 did not terminate after 5 bytes",
    )
    return
}

read_varint32 :: proc(value: ^Reader) -> (result: i32, err: mcpe_runtime.Error) {
    encoded := read_varuint32(value) or_return
    result = i32(encoded >> 1)
    if encoded & 1 != 0 {
        result = ~result
    }
    return
}

read_varuint64 :: proc(value: ^Reader) -> (result: u64, err: mcpe_runtime.Error) {
    for shift := 0; shift < 70; shift += 7 {
        byte := read_u8(value) or_return
        result |= u64(byte & 0x7f) << u64(shift)
        if byte & 0x80 == 0 {
            return
        }
    }
    err = codec_error(
        .Malformed,
        "gophertunnel.protocol.read_varuint64",
        "varuint64 did not terminate after 10 bytes",
    )
    return
}

read_varint64 :: proc(value: ^Reader) -> (result: i64, err: mcpe_runtime.Error) {
    encoded := read_varuint64(value) or_return
    result = i64(encoded >> 1)
    if encoded & 1 != 0 {
        result = ~result
    }
    return
}

read_byte_slice :: proc(value: ^Reader) -> (
    result: []u8,
    err: mcpe_runtime.Error,
) {
    length := read_varuint32(value) or_return
    if value.limits_enabled && u64(length) > u64(MAX_FIELD_BYTES) {
        err = codec_error(
            .Limit_Exceeded,
            "gophertunnel.protocol.read_byte_slice",
            "byte slice exceeds allocation limit",
        )
        return
    }
    source := reader_take(
        value,
        int(length),
        "gophertunnel.protocol.read_byte_slice",
    ) or_return
    result = make([]u8, len(source), value.allocator)
    copy(result, source)
    return
}

read_string :: proc(value: ^Reader) -> (
    result: string,
    err: mcpe_runtime.Error,
) {
    bytes := read_byte_slice(value) or_return
    defer delete(bytes, value.allocator)
    cloned, clone_err := strings.clone_from_bytes(bytes, value.allocator)
    result = cloned
    if clone_err != .None {
        err = codec_error(
            .Internal,
            "gophertunnel.protocol.read_string",
            "allocate string",
        )
    }
    return
}

read_string_utf :: proc(value: ^Reader) -> (
    result: string,
    err: mcpe_runtime.Error,
) {
    signed_length := read_i16(value) or_return
    if signed_length < 0 {
        err = codec_error(
            .Malformed,
            "gophertunnel.protocol.read_string_utf",
            "negative UTF string length",
        )
        return
    }
    bytes := reader_take(
        value,
        int(signed_length),
        "gophertunnel.protocol.read_string_utf",
    ) or_return
    cloned, clone_err := strings.clone_from_bytes(bytes, value.allocator)
    result = cloned
    if clone_err != .None {
        err = codec_error(
            .Internal,
            "gophertunnel.protocol.read_string_utf",
            "allocate string",
        )
    }
    return
}

read_remaining_bytes :: proc(value: ^Reader) -> []u8 {
    result := value.data[value.offset:]
    value.offset = len(value.data)
    return result
}

peek_remaining_bytes :: proc(value: ^Reader) -> []u8 {
    return value.data[value.offset:]
}

read_bytes :: proc(value: ^Reader, count: int) -> (
    result: []u8,
    err: mcpe_runtime.Error,
) {
    return reader_take(
        value,
        count,
        "gophertunnel.protocol.read_bytes",
    )
}

write_u8 :: proc(value: ^Writer, input: u8) {
    append(&value.data, input)
}

write_i8 :: proc(value: ^Writer, input: i8) {
    write_u8(value, transmute(u8)input)
}

write_bool :: proc(value: ^Writer, input: bool) {
    write_u8(value, u8(input))
}

write_u16 :: proc(value: ^Writer, input: u16) {
    write_u8(value, u8(input))
    write_u8(value, u8(input >> 8))
}

write_i16 :: proc(value: ^Writer, input: i16) {
    write_u16(value, transmute(u16)input)
}

write_u32 :: proc(value: ^Writer, input: u32) {
    for shift in 0..<4 {
        write_u8(value, u8(input >> (u32(shift) * 8)))
    }
}

write_i32 :: proc(value: ^Writer, input: i32) {
    write_u32(value, transmute(u32)input)
}

write_be_i32 :: proc(value: ^Writer, input: i32) {
    raw := transmute(u32)input
    for shift in 0..<4 {
        write_u8(value, u8(raw >> (u32(3 - shift) * 8)))
    }
}

write_u64 :: proc(value: ^Writer, input: u64) {
    for shift in 0..<8 {
        write_u8(value, u8(input >> (u64(shift) * 8)))
    }
}

write_i64 :: proc(value: ^Writer, input: i64) {
    write_u64(value, transmute(u64)input)
}

write_f32 :: proc(value: ^Writer, input: f32) {
    write_u32(value, transmute(u32)input)
}

write_f64 :: proc(value: ^Writer, input: f64) {
    write_u64(value, transmute(u64)input)
}

write_varuint32 :: proc(value: ^Writer, input: u32) {
    remaining_value := input
    for remaining_value >= 0x80 {
        write_u8(value, u8(remaining_value) | 0x80)
        remaining_value >>= 7
    }
    write_u8(value, u8(remaining_value))
}

write_varint32 :: proc(value: ^Writer, input: i32) {
    encoded := transmute(u32)input << 1
    if input < 0 {
        encoded = ~encoded
    }
    write_varuint32(value, encoded)
}

write_varuint64 :: proc(value: ^Writer, input: u64) {
    remaining_value := input
    for remaining_value >= 0x80 {
        write_u8(value, u8(remaining_value) | 0x80)
        remaining_value >>= 7
    }
    write_u8(value, u8(remaining_value))
}

write_varint64 :: proc(value: ^Writer, input: i64) {
    encoded := transmute(u64)input << 1
    if input < 0 {
        encoded = ~encoded
    }
    write_varuint64(value, encoded)
}

write_bytes :: proc(value: ^Writer, input: []u8) {
    append(&value.data, ..input)
}

write_byte_slice :: proc(value: ^Writer, input: []u8) {
    write_varuint32(value, u32(len(input)))
    write_bytes(value, input)
}

write_string :: proc(value: ^Writer, input: string) {
    write_varuint32(value, u32(len(input)))
    write_bytes(value, transmute([]u8)input)
}

write_string_utf :: proc(value: ^Writer, input: string) {
    write_i16(value, i16(len(input)))
    write_bytes(value, transmute([]u8)input)
}

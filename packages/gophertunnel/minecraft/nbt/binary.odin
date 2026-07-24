package gt_nbt

import "core:mem"
import "core:strings"
import protocol "mcpe:gophertunnel/minecraft/protocol"
import mcpe_runtime "mcpe:runtime"

MAX_STRING_SIZE      :: 32_767
MAX_NESTING_DEPTH    :: 512
MAX_NETWORK_BYTES    :: 4 * 1024 * 1024
MAX_NETWORK_NODES    :: 65_536

Traversal_State :: struct {
    nodes: int,
}

nbt_error :: proc(
    kind: mcpe_runtime.Error_Kind,
    operation: string,
    message: string,
) -> mcpe_runtime.Error {
    return mcpe_runtime.make_error(kind, operation, message)
}

encoding_big_endian :: proc(encoding: Encoding) -> bool {
    return encoding == .Big_Endian || encoding == .Network_Big_Endian
}

encoding_network_little :: proc(encoding: Encoding) -> bool {
    return encoding == .Network_Little_Endian
}

write_i16 :: proc(output: ^protocol.Writer, encoding: Encoding, input: i16) {
    if encoding_big_endian(encoding) {
        raw := transmute(u16)input
        protocol.write_u8(output, u8(raw >> 8))
        protocol.write_u8(output, u8(raw))
    } else {
        protocol.write_i16(output, input)
    }
}

write_i32 :: proc(output: ^protocol.Writer, encoding: Encoding, input: i32) {
    if encoding_network_little(encoding) {
        protocol.write_varint32(output, input)
    } else if encoding_big_endian(encoding) {
        protocol.write_be_i32(output, input)
    } else {
        protocol.write_i32(output, input)
    }
}

write_i64 :: proc(output: ^protocol.Writer, encoding: Encoding, input: i64) {
    if encoding_network_little(encoding) {
        protocol.write_varint64(output, input)
    } else if encoding_big_endian(encoding) {
        raw := transmute(u64)input
        for index in 0..<8 {
            protocol.write_u8(
                output,
                u8(raw >> (u64(7 - index) * 8)),
            )
        }
    } else {
        protocol.write_i64(output, input)
    }
}

write_f32 :: proc(output: ^protocol.Writer, encoding: Encoding, input: f32) {
    raw := transmute(u32)input
    if encoding_big_endian(encoding) {
        protocol.write_be_i32(output, transmute(i32)raw)
    } else {
        protocol.write_u32(output, raw)
    }
}

write_f64 :: proc(output: ^protocol.Writer, encoding: Encoding, input: f64) {
    raw := transmute(u64)input
    if encoding_big_endian(encoding) {
        for index in 0..<8 {
            protocol.write_u8(
                output,
                u8(raw >> (u64(7 - index) * 8)),
            )
        }
    } else {
        protocol.write_u64(output, raw)
    }
}

write_nbt_string :: proc(
    output: ^protocol.Writer,
    encoding: Encoding,
    input: string,
) -> mcpe_runtime.Error {
    if len(input) > MAX_STRING_SIZE {
        return nbt_error(
            .Limit_Exceeded,
            "gophertunnel.nbt.write_string",
            "string length exceeds 32767 bytes",
        )
    }
    if encoding_network_little(encoding) {
        protocol.write_varuint32(output, u32(len(input)))
    } else {
        length := u16(len(input))
        if encoding_big_endian(encoding) {
            protocol.write_u8(output, u8(length >> 8))
            protocol.write_u8(output, u8(length))
        } else {
            protocol.write_u16(output, length)
        }
    }
    protocol.write_bytes(output, transmute([]u8)input)
    return nil
}

write_tag_header :: proc(
    output: ^protocol.Writer,
    encoding: Encoding,
    tag: Tag,
    name: string,
    depth: int,
) -> mcpe_runtime.Error {
    if depth >= MAX_NESTING_DEPTH {
        return nbt_error(
            .Limit_Exceeded,
            "gophertunnel.nbt.write_tag",
            "maximum nesting depth reached",
        )
    }
    if !tag_valid(tag) {
        return nbt_error(
            .Invalid_Argument,
            "gophertunnel.nbt.write_tag",
            "unknown NBT tag",
        )
    }
    if tag == .End {
        return nbt_error(
            .Invalid_Argument,
            "gophertunnel.nbt.write_tag",
            "TAG_End cannot have a header",
        )
    }
    protocol.write_u8(output, u8(tag))
    if encoding == .Network_Big_Endian &&
       tag == .Compound &&
       depth == 0 {
        return nil
    }
    return write_nbt_string(output, encoding, name)
}

write_payload :: proc(
    output: ^protocol.Writer,
    encoding: Encoding,
    value: ^Value,
    depth: int,
    state: ^Traversal_State,
) -> mcpe_runtime.Error {
    if depth >= MAX_NESTING_DEPTH {
        return nbt_error(
            .Limit_Exceeded,
            "gophertunnel.nbt.write_payload",
            "maximum nesting depth reached",
        )
    }
    state.nodes += 1
    if encoding_network_little(encoding) &&
       state.nodes > MAX_NETWORK_NODES {
        return nbt_error(
            .Limit_Exceeded,
            "gophertunnel.nbt.write_payload",
            "network NBT node limit exhausted",
        )
    }
    switch value.tag {
    case .End:
        return nil
    case .Byte:
        protocol.write_u8(output, value.byte)
    case .Short:
        write_i16(output, encoding, value.short)
    case .Int:
        write_i32(output, encoding, value.int)
    case .Long:
        write_i64(output, encoding, value.long)
    case .Float:
        write_f32(output, encoding, value.float)
    case .Double:
        write_f64(output, encoding, value.double)
    case .Byte_Array:
        if i64(len(value.byte_array)) > i64(max(i32)) {
            return nbt_error(
                .Limit_Exceeded,
                "gophertunnel.nbt.write_byte_array",
                "byte array exceeds int32 length",
            )
        }
        write_i32(output, encoding, i32(len(value.byte_array)))
        protocol.write_bytes(output, value.byte_array)
    case .String:
        return write_nbt_string(output, encoding, value.string)
    case .List:
        if !tag_valid(value.list_type) {
            return nbt_error(
                .Invalid_Argument,
                "gophertunnel.nbt.write_list",
                "unknown list element tag",
            )
        }
        if value.list_type == .End && len(value.list) != 0 {
            return nbt_error(
                .Invalid_Argument,
                "gophertunnel.nbt.write_list",
                "non-empty TAG_End list",
            )
        }
        if i64(len(value.list)) > i64(max(i32)) {
            return nbt_error(
                .Limit_Exceeded,
                "gophertunnel.nbt.write_list",
                "list exceeds int32 length",
            )
        }
        if encoding_network_little(encoding) &&
           len(value.list) > MAX_NETWORK_NODES - state.nodes {
            return nbt_error(
                .Limit_Exceeded,
                "gophertunnel.nbt.write_list",
                "network NBT node limit exhausted",
            )
        }
        protocol.write_u8(output, u8(value.list_type))
        write_i32(output, encoding, i32(len(value.list)))
        for child in value.list {
            if child == nil || child.tag != value.list_type {
                return nbt_error(
                    .Invalid_Argument,
                    "gophertunnel.nbt.write_list",
                    "heterogeneous NBT list",
                )
            }
            write_payload(
                output,
                encoding,
                child,
                depth + 1,
                state,
            ) or_return
        }
    case .Compound:
        for entry in value.compound {
            if entry.value == nil {
                return nbt_error(
                    .Invalid_Argument,
                    "gophertunnel.nbt.write_compound",
                    "nil compound value",
                )
            }
            write_tag_header(
                output,
                encoding,
                entry.value.tag,
                entry.name,
                depth + 1,
            ) or_return
            write_payload(
                output,
                encoding,
                entry.value,
                depth + 1,
                state,
            ) or_return
        }
        protocol.write_u8(output, u8(Tag.End))
    case .Int_Array:
        if i64(len(value.int_array)) > i64(max(i32)) {
            return nbt_error(
                .Limit_Exceeded,
                "gophertunnel.nbt.write_int_array",
                "int array exceeds int32 length",
            )
        }
        write_i32(output, encoding, i32(len(value.int_array)))
        for item in value.int_array {
            write_i32(output, encoding, item)
        }
    case .Long_Array:
        if i64(len(value.long_array)) > i64(max(i32)) {
            return nbt_error(
                .Limit_Exceeded,
                "gophertunnel.nbt.write_long_array",
                "long array exceeds int32 length",
            )
        }
        write_i32(output, encoding, i32(len(value.long_array)))
        for item in value.long_array {
            write_i64(output, encoding, item)
        }
    }
    return nil
}

marshal :: proc(
    value: ^Value,
    encoding: Encoding = .Network_Little_Endian,
    root_name: string = "",
    allocator: mem.Allocator = context.allocator,
) -> (data: []u8, err: mcpe_runtime.Error) {
    if value == nil {
        err = nbt_error(
            .Invalid_Argument,
            "gophertunnel.nbt.marshal",
            "nil root value",
        )
        return
    }
    output := protocol.writer(0, 256, allocator)
    defer protocol.writer_destroy(&output)
    state := Traversal_State{}
    write_tag_header(
        &output,
        encoding,
        value.tag,
        root_name,
        0,
    ) or_return
    write_payload(&output, encoding, value, 0, &state) or_return
    encoded := protocol.writer_bytes(&output)
    data = make([]u8, len(encoded), allocator)
    copy(data, encoded)
    return
}

read_i16 :: proc(
    input: ^protocol.Reader,
    encoding: Encoding,
) -> (result: i16, err: mcpe_runtime.Error) {
    if !encoding_big_endian(encoding) {
        return protocol.read_i16(input)
    }
    high := protocol.read_u8(input) or_return
    low := protocol.read_u8(input) or_return
    result = transmute(i16)(u16(high) << 8 | u16(low))
    return
}

read_i32 :: proc(
    input: ^protocol.Reader,
    encoding: Encoding,
) -> (result: i32, err: mcpe_runtime.Error) {
    if encoding_network_little(encoding) {
        return protocol.read_varint32(input)
    }
    if encoding_big_endian(encoding) {
        return protocol.read_be_i32(input)
    }
    return protocol.read_i32(input)
}

read_i64 :: proc(
    input: ^protocol.Reader,
    encoding: Encoding,
) -> (result: i64, err: mcpe_runtime.Error) {
    if encoding_network_little(encoding) {
        return protocol.read_varint64(input)
    }
    if !encoding_big_endian(encoding) {
        return protocol.read_i64(input)
    }
    raw: u64
    for _ in 0..<8 {
        raw = raw << 8 | u64(protocol.read_u8(input) or_return)
    }
    result = transmute(i64)raw
    return
}

read_f32 :: proc(
    input: ^protocol.Reader,
    encoding: Encoding,
) -> (result: f32, err: mcpe_runtime.Error) {
    raw: u32
    if encoding_big_endian(encoding) {
        raw = transmute(u32)(protocol.read_be_i32(input) or_return)
    } else {
        raw = protocol.read_u32(input) or_return
    }
    result = transmute(f32)raw
    return
}

read_f64 :: proc(
    input: ^protocol.Reader,
    encoding: Encoding,
) -> (result: f64, err: mcpe_runtime.Error) {
    raw: u64
    if encoding_big_endian(encoding) {
        for _ in 0..<8 {
            raw = raw << 8 | u64(protocol.read_u8(input) or_return)
        }
    } else {
        raw = protocol.read_u64(input) or_return
    }
    result = transmute(f64)raw
    return
}

read_nbt_string :: proc(
    input: ^protocol.Reader,
    encoding: Encoding,
) -> (result: string, err: mcpe_runtime.Error) {
    length: u32
    if encoding_network_little(encoding) {
        length = protocol.read_varuint32(input) or_return
    } else {
        if encoding_big_endian(encoding) {
            high := protocol.read_u8(input) or_return
            low := protocol.read_u8(input) or_return
            length = u32(u16(high) << 8 | u16(low))
        } else {
            length = u32(protocol.read_u16(input) or_return)
        }
    }
    if length > MAX_STRING_SIZE {
        err = nbt_error(
            .Limit_Exceeded,
            "gophertunnel.nbt.read_string",
            "string length exceeds 32767 bytes",
        )
        return
    }
    if encoding_network_little(encoding) &&
       i64(input.offset) + i64(length) > MAX_NETWORK_BYTES {
        err = nbt_error(
            .Limit_Exceeded,
            "gophertunnel.nbt.read_string",
            "network NBT byte limit exhausted",
        )
        return
    }
    bytes := protocol.reader_take(
        input,
        int(length),
        "gophertunnel.nbt.read_string",
    ) or_return
    cloned, clone_err := strings.clone_from_bytes(bytes, input.allocator)
    if clone_err != .None {
        err = nbt_error(
            .Internal,
            "gophertunnel.nbt.read_string",
            "allocate string",
        )
        return
    }
    result = cloned
    return
}

read_count :: proc(
    input: ^protocol.Reader,
    encoding: Encoding,
    operation: string,
) -> (result: int, err: mcpe_runtime.Error) {
    count := read_i32(input, encoding) or_return
    if count < 0 {
        err = nbt_error(.Malformed, operation, "negative collection length")
        return
    }
    result = int(count)
    return
}

check_collection_read :: proc(
    input: ^protocol.Reader,
    encoding: Encoding,
    count: int,
    minimum_item_bytes: int,
    operation: string,
) -> mcpe_runtime.Error {
    required := i64(count) * i64(minimum_item_bytes)
    if encoding_network_little(encoding) &&
       i64(input.offset) + required > MAX_NETWORK_BYTES {
        return nbt_error(
            .Limit_Exceeded,
            operation,
            "network NBT byte limit exhausted",
        )
    }
    if required > i64(protocol.remaining(input)) {
        return nbt_error(
            .Unexpected_EOF,
            operation,
            "collection exceeds remaining input",
        )
    }
    return nil
}

minimum_payload_bytes :: proc(
    tag: Tag,
    encoding: Encoding,
) -> int {
    if encoding_network_little(encoding) {
        switch tag {
        case .Byte, .Int, .Long, .String, .Compound,
             .Int_Array, .Long_Array:
            return 1
        case .Short:
            return 2
        case .List:
            return 2
        case .Float:
            return 4
        case .Double:
            return 8
        case .Byte_Array:
            return 1
        case .End:
            return 0
        }
    }
    switch tag {
    case .Byte, .Compound:
        return 1
    case .Short, .String:
        return 2
    case .Int, .Float, .Byte_Array, .Int_Array, .Long_Array:
        return 4
    case .Long, .Double:
        return 8
    case .List:
        return 5
    case .End:
        return 0
    }
    return 0
}

destroy_entries :: proc(
    entries: []Named_Value,
    allocator: mem.Allocator,
) {
    for entry in entries {
        delete(entry.name, allocator)
        destroy_value(entry.value, allocator)
        free(entry.value, allocator)
    }
}

discard_read_value :: proc(
    value: ^^Value,
    allocator: mem.Allocator,
) {
    destroy_value(value^, allocator)
    free(value^, allocator)
    value^ = nil
}

check_network_read :: proc(
    input: ^protocol.Reader,
    encoding: Encoding,
    additional: int = 0,
) -> mcpe_runtime.Error {
    if encoding_network_little(encoding) &&
       i64(input.offset) + i64(additional) > MAX_NETWORK_BYTES {
        return nbt_error(
            .Limit_Exceeded,
            "gophertunnel.nbt.read_payload",
            "network NBT byte limit exhausted",
        )
    }
    return nil
}

read_payload :: proc(
    input: ^protocol.Reader,
    encoding: Encoding,
    tag: Tag,
    depth: int,
    state: ^Traversal_State,
) -> (value: ^Value, err: mcpe_runtime.Error) {
    if depth >= MAX_NESTING_DEPTH {
        err = nbt_error(
            .Limit_Exceeded,
            "gophertunnel.nbt.read_payload",
            "maximum nesting depth reached",
        )
        return
    }
    state.nodes += 1
    if encoding_network_little(encoding) &&
       state.nodes > MAX_NETWORK_NODES {
        err = nbt_error(
            .Limit_Exceeded,
            "gophertunnel.nbt.read_payload",
            "network NBT node limit exhausted",
        )
        return
    }
    if encoding_network_little(encoding) &&
       input.offset >= MAX_NETWORK_BYTES {
        err = nbt_error(
            .Limit_Exceeded,
            "gophertunnel.nbt.read_payload",
            "network NBT byte limit exhausted",
        )
        return
    }
    if !tag_valid(tag) || tag == .End {
        err = nbt_error(
            .Malformed,
            "gophertunnel.nbt.read_payload",
            "unexpected NBT tag",
        )
        return
    }
    value = new(Value, input.allocator)
    value.tag = tag
    switch tag {
    case .Byte:
        value.byte, err = protocol.read_u8(input)
    case .Short:
        value.short, err = read_i16(input, encoding)
    case .Int:
        value.int, err = read_i32(input, encoding)
    case .Long:
        value.long, err = read_i64(input, encoding)
    case .Float:
        value.float, err = read_f32(input, encoding)
    case .Double:
        value.double, err = read_f64(input, encoding)
    case .Byte_Array:
        count: int
        count, err = read_count(
            input,
            encoding,
            "gophertunnel.nbt.read_byte_array",
        )
        if err == nil {
            err = check_collection_read(
                input,
                encoding,
                count,
                1,
                "gophertunnel.nbt.read_byte_array",
            )
        }
        if err == nil {
            bytes: []u8
            bytes, err = protocol.reader_take(
                input,
                count,
                "gophertunnel.nbt.read_byte_array",
            )
            if err == nil {
                value.byte_array = make([]u8, count, input.allocator)
                copy(value.byte_array, bytes)
            }
        }
    case .String:
        value.string, err = read_nbt_string(input, encoding)
    case .List:
        raw_tag: u8
        raw_tag, err = protocol.read_u8(input)
        if err != nil {
            break
        }
        list_tag := Tag(raw_tag)
        if !tag_valid(list_tag) {
            err = nbt_error(
                .Malformed,
                "gophertunnel.nbt.read_list",
                "unknown list element tag",
            )
            break
        }
        count: int
        count, err = read_count(
            input,
            encoding,
            "gophertunnel.nbt.read_list",
        )
        if err != nil {
            break
        }
        if list_tag == .End && count != 0 {
            err = nbt_error(
                .Malformed,
                "gophertunnel.nbt.read_list",
                "non-empty TAG_End list",
            )
            break
        }
        if encoding_network_little(encoding) &&
           count > MAX_NETWORK_NODES - state.nodes {
            err = nbt_error(
                .Limit_Exceeded,
                "gophertunnel.nbt.read_list",
                "network NBT node limit exhausted",
            )
            break
        }
        err = check_collection_read(
            input,
            encoding,
            count,
            minimum_payload_bytes(list_tag, encoding),
            "gophertunnel.nbt.read_list",
        )
        if err != nil {
            break
        }
        value.list_type = list_tag
        value.list = make([]^Value, count, input.allocator)
        for &child in value.list {
            child, err = read_payload(
                input,
                encoding,
                list_tag,
                depth + 1,
                state,
            )
            if err != nil {
                break
            }
            err = check_network_read(input, encoding)
            if err != nil {
                break
            }
        }
    case .Compound:
        entries := make([dynamic]Named_Value, 0, 8, input.allocator)
        for {
            err = check_network_read(input, encoding, 1)
            if err != nil {
                break
            }
            raw_tag, tag_err := protocol.read_u8(input)
            if tag_err != nil {
                err = tag_err
                break
            }
            nested_tag := Tag(raw_tag)
            if nested_tag == .End {
                break
            }
            if !tag_valid(nested_tag) {
                err = nbt_error(
                    .Malformed,
                    "gophertunnel.nbt.read_compound",
                    "unknown compound tag",
                )
                break
            }
            name, name_err := read_nbt_string(input, encoding)
            if name_err != nil {
                err = name_err
                break
            }
            child, child_err := read_payload(
                input,
                encoding,
                nested_tag,
                depth + 1,
                state,
            )
            if child_err != nil {
                delete(name, input.allocator)
                err = child_err
                break
            }
            append(
                &entries,
                Named_Value{name = name, value = child},
            )
            err = check_network_read(input, encoding)
            if err != nil {
                break
            }
        }
        if err == nil {
            value.compound = make(
                []Named_Value,
                len(entries),
                input.allocator,
            )
            copy(value.compound, entries[:])
        } else {
            destroy_entries(entries[:], input.allocator)
        }
        delete(entries)
    case .Int_Array:
        count: int
        count, err = read_count(
            input,
            encoding,
            "gophertunnel.nbt.read_int_array",
        )
        if err == nil {
            minimum_bytes := 4
            if encoding_network_little(encoding) {
                minimum_bytes = 1
            }
            err = check_collection_read(
                input,
                encoding,
                count,
                minimum_bytes,
                "gophertunnel.nbt.read_int_array",
            )
        }
        if err == nil {
            value.int_array = make([]i32, count, input.allocator)
            for &item in value.int_array {
                item, err = read_i32(input, encoding)
                if err != nil {
                    break
                }
                err = check_network_read(input, encoding)
                if err != nil {
                    break
                }
            }
        }
    case .Long_Array:
        count: int
        count, err = read_count(
            input,
            encoding,
            "gophertunnel.nbt.read_long_array",
        )
        if err == nil {
            minimum_bytes := 8
            if encoding_network_little(encoding) {
                minimum_bytes = 1
            }
            err = check_collection_read(
                input,
                encoding,
                count,
                minimum_bytes,
                "gophertunnel.nbt.read_long_array",
            )
        }
        if err == nil {
            value.long_array = make([]i64, count, input.allocator)
            for &item in value.long_array {
                item, err = read_i64(input, encoding)
                if err != nil {
                    break
                }
                err = check_network_read(input, encoding)
                if err != nil {
                    break
                }
            }
        }
    case .End:
    }
    if err == nil {
        err = check_network_read(input, encoding)
    }
    if err != nil {
        discard_read_value(&value, input.allocator)
    }
    return
}

unmarshal :: proc(
    data: []u8,
    encoding: Encoding = .Network_Little_Endian,
    allow_zero: bool = false,
    allocator: mem.Allocator = context.allocator,
) -> (
    value: ^Value,
    root_name: string,
    err: mcpe_runtime.Error,
) {
    input := protocol.reader(data, 0, true, allocator)
    state := Traversal_State{}
    root_tag := Tag(protocol.read_u8(&input) or_return)
    if root_tag == .End && allow_zero {
        value = new(Value, allocator)
        value.tag = .Compound
        return
    }
    if !tag_valid(root_tag) || root_tag == .End {
        err = nbt_error(
            .Malformed,
            "gophertunnel.nbt.unmarshal",
            "invalid root tag",
        )
        return
    }
    if !(encoding == .Network_Big_Endian && root_tag == .Compound) {
        root_name = read_nbt_string(&input, encoding) or_return
    }
    value, err = read_payload(&input, encoding, root_tag, 0, &state)
    if err != nil {
        delete(root_name, allocator)
        root_name = ""
        return
    }
    return
}

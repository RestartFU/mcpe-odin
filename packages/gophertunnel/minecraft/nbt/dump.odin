package gt_nbt

import "core:mem"
import "core:strconv"
import "core:strings"
import mcpe_runtime "mcpe:runtime"

Dump_Output :: struct {
    builder: strings.Builder,
    failed:  bool,
}

dump_write_string :: proc(output: ^Dump_Output, value: string) {
    if strings.write_string(&output.builder, value) != len(value) {
        output.failed = true
    }
}

dump_write_byte :: proc(output: ^Dump_Output, value: u8) {
    if strings.write_byte(&output.builder, value) != 1 {
        output.failed = true
    }
}

dump_write_i64 :: proc(output: ^Dump_Output, value: i64) {
    buffer: [32]u8
    dump_write_string(
        output,
        strconv.write_int(buffer[:], value, 10),
    )
}

tag_name :: proc(tag: Tag) -> string {
    switch tag {
    case .End:        return "TAG_End"
    case .Byte:       return "TAG_Byte"
    case .Short:      return "TAG_Short"
    case .Int:        return "TAG_Int"
    case .Long:       return "TAG_Long"
    case .Float:      return "TAG_Float"
    case .Double:     return "TAG_Double"
    case .Byte_Array: return "TAG_ByteArray"
    case .String:     return "TAG_String"
    case .List:       return "TAG_List"
    case .Compound:   return "TAG_Compound"
    case .Int_Array:  return "TAG_IntArray"
    case .Long_Array: return "TAG_LongArray"
    }
    return "TAG_Unknown"
}

write_indent :: proc(output: ^Dump_Output, depth: int) {
    for _ in 0..<depth {
        dump_write_byte(output, '\t')
    }
}

write_float32 :: proc(output: ^Dump_Output, value: f32) {
    buffer: [64]u8
    encoded := strconv.write_float(buffer[:], f64(value), 'g', -1, 32)
    if len(encoded) > 1 && encoded[0] == '+' && encoded[1] != 'I' {
        encoded = encoded[1:]
    }
    dump_write_string(output, encoded)
}

write_float64 :: proc(output: ^Dump_Output, value: f64) {
    buffer: [64]u8
    encoded := strconv.write_float(buffer[:], value, 'g', -1, 64)
    if len(encoded) > 1 && encoded[0] == '+' && encoded[1] != 'I' {
        encoded = encoded[1:]
    }
    dump_write_string(output, encoded)
}

write_dump_type :: proc(
    output: ^Dump_Output,
    value: ^Value,
) -> mcpe_runtime.Error {
    if value == nil || !tag_valid(value.tag) || value.tag == .End {
        return nbt_error(
            .Malformed,
            "gophertunnel.nbt.dump",
            "invalid NBT value",
        )
    }
    if value.tag == .List {
        if !tag_valid(value.list_type) ||
           (value.list_type == .End && len(value.list) != 0) {
            return nbt_error(
                .Malformed,
                "gophertunnel.nbt.dump",
                "invalid NBT list type",
            )
        }
        dump_write_string(output, "TAG_List<")
        if len(value.list) == 0 {
            if value.list_type == .Int || value.list_type == .Long {
                dump_write_string(output, tag_name(value.list_type))
            } else {
                dump_write_string(output, "nil")
            }
        } else {
            write_dump_type(output, value.list[0]) or_return
        }
        dump_write_byte(output, '>')
        return nil
    }
    dump_write_string(output, tag_name(value.tag))
    return nil
}

write_dump_payload :: proc(
    output: ^Dump_Output,
    value: ^Value,
    depth: int,
) -> mcpe_runtime.Error {
    if value == nil {
        return nbt_error(
            .Malformed,
            "gophertunnel.nbt.dump",
            "nil NBT value",
        )
    }
    switch value.tag {
    case .Byte:
        hex := "0123456789abcdef"
        dump_write_string(output, "0x")
        dump_write_byte(output, hex[value.byte >> 4])
        dump_write_byte(output, hex[value.byte & 0x0f])
    case .Short:
        dump_write_i64(output, i64(value.short))
    case .Int:
        dump_write_i64(output, i64(value.int))
    case .Long:
        dump_write_i64(output, value.long)
    case .Float:
        write_float32(output, value.float)
    case .Double:
        write_float64(output, value.double)
    case .String:
        dump_write_string(output, value.string)
    case .Byte_Array:
        hex := "0123456789abcdef"
        for item, index in value.byte_array {
            dump_write_string(output, "0x")
            dump_write_byte(output, hex[item >> 4])
            dump_write_byte(output, hex[item & 0x0f])
            if index != len(value.byte_array) - 1 {
                dump_write_byte(output, ' ')
            }
        }
    case .Int_Array:
        for item, index in value.int_array {
            dump_write_i64(output, i64(item))
            if index != len(value.int_array) - 1 {
                dump_write_byte(output, ' ')
            }
        }
    case .Long_Array:
        for item, index in value.long_array {
            dump_write_i64(output, item)
            if index != len(value.long_array) - 1 {
                dump_write_byte(output, ' ')
            }
        }
    case .List:
        dump_write_string(output, "{\n")
        for child in value.list {
            write_indent(output, depth + 1)
            write_dump_payload(output, child, depth + 1) or_return
            dump_write_string(output, ",\n")
        }
        write_indent(output, depth)
        dump_write_byte(output, '}')
    case .Compound:
        dump_write_string(output, "{\n")
        for entry in value.compound {
            write_indent(output, depth + 1)
            dump_write_byte(output, '\'')
            dump_write_string(output, entry.name)
            dump_write_string(output, "': ")
            write_dump_type(output, entry.value) or_return
            dump_write_byte(output, '(')
            write_dump_payload(output, entry.value, depth + 1) or_return
            dump_write_string(output, "),\n")
        }
        write_indent(output, depth)
        dump_write_byte(output, '}')
    case .End:
        return nbt_error(
            .Malformed,
            "gophertunnel.nbt.dump",
            "unexpected TAG_End",
        )
    }
    return nil
}

// dump returns upstream's human-readable NBT representation. The returned
// string is allocator-owned.
dump :: proc(
    data: []u8,
    encoding: Encoding,
    allocator: mem.Allocator = context.allocator,
) -> (result: string, err: mcpe_runtime.Error) {
    root, root_name, decode_err := unmarshal(
        data,
        encoding,
        false,
        allocator,
    )
    if decode_err != nil {
        err = decode_err
        return
    }
    defer {
        delete(root_name, allocator)
        destroy_value(root, allocator)
        free(root, allocator)
    }
    if root.tag != .Compound {
        err = nbt_error(
            .Invalid_Argument,
            "gophertunnel.nbt.dump",
            "Dump requires a root TAG_Compound",
        )
        return
    }

    output := Dump_Output{}
    _, builder_err := strings.builder_init(&output.builder, allocator)
    if builder_err != .None {
        err = nbt_error(
            .Internal,
            "gophertunnel.nbt.dump",
            "allocate dump buffer",
        )
        return
    }
    defer strings.builder_destroy(&output.builder)
    write_dump_type(&output, root) or_return
    dump_write_byte(&output, '(')
    write_dump_payload(&output, root, 0) or_return
    dump_write_byte(&output, ')')
    if output.failed {
        err = nbt_error(
            .Internal,
            "gophertunnel.nbt.dump",
            "write dump buffer",
        )
        return
    }
    cloned, clone_err := strings.clone(
        strings.to_string(output.builder),
        allocator,
    )
    if clone_err != .None {
        err = nbt_error(
            .Internal,
            "gophertunnel.nbt.dump",
            "allocate dump result",
        )
        return
    }
    result = cloned
    return
}

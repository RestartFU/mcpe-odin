package gt_nbt

import "core:mem"
import "core:strings"

Encoding :: enum u8 {
    Network_Little_Endian,
    Little_Endian,
    Network_Big_Endian,
    Big_Endian,
}

Tag :: enum u8 {
    End         = 0,
    Byte        = 1,
    Short       = 2,
    Int         = 3,
    Long        = 4,
    Float       = 5,
    Double      = 6,
    Byte_Array  = 7,
    String      = 8,
    List        = 9,
    Compound    = 10,
    Int_Array   = 11,
    Long_Array  = 12,
}

Named_Value :: struct {
    name:  string,
    value: ^Value,
}

Value :: struct {
    tag:         Tag,
    byte:        u8,
    short:       i16,
    int:         i32,
    long:        i64,
    float:       f32,
    double:      f64,
    byte_array:  []u8,
    string:      string,
    list_type:   Tag,
    list:        []^Value,
    compound:    []Named_Value,
    int_array:   []i32,
    long_array:  []i64,
}

value_byte :: proc(input: u8) -> Value {
    return {tag = .Byte, byte = input}
}

value_short :: proc(input: i16) -> Value {
    return {tag = .Short, short = input}
}

value_int :: proc(input: i32) -> Value {
    return {tag = .Int, int = input}
}

value_long :: proc(input: i64) -> Value {
    return {tag = .Long, long = input}
}

value_float :: proc(input: f32) -> Value {
    return {tag = .Float, float = input}
}

value_double :: proc(input: f64) -> Value {
    return {tag = .Double, double = input}
}

value_string :: proc(
    input: string,
    allocator: mem.Allocator = context.allocator,
) -> Value {
    return {
        tag = .String,
        string = strings.clone(input, allocator),
    }
}

value_byte_array :: proc(
    input: []u8,
    allocator: mem.Allocator = context.allocator,
) -> Value {
    owned := make([]u8, len(input), allocator)
    copy(owned, input)
    return {tag = .Byte_Array, byte_array = owned}
}

value_int_array :: proc(
    input: []i32,
    allocator: mem.Allocator = context.allocator,
) -> Value {
    owned := make([]i32, len(input), allocator)
    copy(owned, input)
    return {tag = .Int_Array, int_array = owned}
}

value_long_array :: proc(
    input: []i64,
    allocator: mem.Allocator = context.allocator,
) -> Value {
    owned := make([]i64, len(input), allocator)
    copy(owned, input)
    return {tag = .Long_Array, long_array = owned}
}

new_value :: proc(
    input: Value,
    allocator: mem.Allocator = context.allocator,
) -> ^Value {
    result := new(Value, allocator)
    result^ = input
    return result
}

named_value :: proc(
    name: string,
    input: Value,
    allocator: mem.Allocator = context.allocator,
) -> Named_Value {
    return {
        name = strings.clone(name, allocator),
        value = new_value(input, allocator),
    }
}

value_list :: proc(
    list_type: Tag,
    input: []Value,
    allocator: mem.Allocator = context.allocator,
) -> Value {
    children := make([]^Value, len(input), allocator)
    for &child, index in children {
        child = new_value(input[index], allocator)
    }
    return {
        tag = .List,
        list_type = list_type,
        list = children,
    }
}

// value_compound takes ownership of the names and value pointers in entries.
value_compound :: proc(
    entries: []Named_Value,
    allocator: mem.Allocator = context.allocator,
) -> Value {
    owned := make([]Named_Value, len(entries), allocator)
    copy(owned, entries)
    return {tag = .Compound, compound = owned}
}

destroy_value :: proc(
    value: ^Value,
    allocator: mem.Allocator = context.allocator,
) {
    if value == nil {
        return
    }
    #partial switch value.tag {
    case .Byte_Array:
        delete(value.byte_array, allocator)
    case .String:
        delete(value.string, allocator)
    case .List:
        for child in value.list {
            destroy_value(child, allocator)
            free(child, allocator)
        }
        delete(value.list, allocator)
    case .Compound:
        for entry in value.compound {
            delete(entry.name, allocator)
            destroy_value(entry.value, allocator)
            free(entry.value, allocator)
        }
        delete(value.compound, allocator)
    case .Int_Array:
        delete(value.int_array, allocator)
    case .Long_Array:
        delete(value.long_array, allocator)
    case:
    }
    value^ = {}
}

compound_find :: proc(value: ^Value, name: string) -> (^Value, bool) {
    if value == nil || value.tag != .Compound {
        return nil, false
    }
    for entry in value.compound {
        if entry.name == name {
            return entry.value, true
        }
    }
    return nil, false
}

tag_valid :: proc(tag: Tag) -> bool {
    return u8(tag) <= u8(Tag.Long_Array)
}

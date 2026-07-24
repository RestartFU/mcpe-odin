package gt_protocol

import mcpe_runtime "mcpe:runtime"

MAX_COLLECTION_ELEMENTS :: 1024

Texture_Pack_Info :: struct {
    uuid:             UUID,
    version:          string,
    size:             u64,
    content_key:      string,
    sub_pack_name:    string,
    content_identity: string,
    has_scripts:      bool,
    addon_pack:       bool,
    rtx_enabled:      bool,
    download_url:     string,
}

Stack_Resource_Pack :: struct {
    uuid:          string,
    version:       string,
    sub_pack_name: string,
}

Experiment_Data :: struct {
    name:    string,
    enabled: bool,
}

destroy_texture_pack_info :: proc(
    value: ^Texture_Pack_Info,
    allocator := context.allocator,
) {
    if value == nil {
        return
    }
    delete(value.version, allocator)
    delete(value.content_key, allocator)
    delete(value.sub_pack_name, allocator)
    delete(value.content_identity, allocator)
    delete(value.download_url, allocator)
    value^ = {}
}

write_texture_pack_info :: proc(
    output: ^Writer,
    value: Texture_Pack_Info,
) {
    write_uuid(output, value.uuid)
    write_string(output, value.version)
    write_u64(output, value.size)
    write_string(output, value.content_key)
    write_string(output, value.sub_pack_name)
    write_string(output, value.content_identity)
    write_bool(output, value.has_scripts)
    write_bool(output, value.addon_pack)
    write_bool(output, value.rtx_enabled)
    write_string(output, value.download_url)
}

read_texture_pack_info :: proc(
    input: ^Reader,
) -> (value: Texture_Pack_Info, err: mcpe_runtime.Error) {
    defer if err != nil {
        destroy_texture_pack_info(&value, input.allocator)
    }
    value.uuid = read_uuid(input) or_return
    value.version = read_string(input) or_return
    value.size = read_u64(input) or_return
    value.content_key = read_string(input) or_return
    value.sub_pack_name = read_string(input) or_return
    value.content_identity = read_string(input) or_return
    value.has_scripts = read_bool(input) or_return
    value.addon_pack = read_bool(input) or_return
    value.rtx_enabled = read_bool(input) or_return
    value.download_url = read_string(input) or_return
    return
}

destroy_stack_resource_pack :: proc(
    value: ^Stack_Resource_Pack,
    allocator := context.allocator,
) {
    if value == nil {
        return
    }
    delete(value.uuid, allocator)
    delete(value.version, allocator)
    delete(value.sub_pack_name, allocator)
    value^ = {}
}

write_stack_resource_pack :: proc(
    output: ^Writer,
    value: Stack_Resource_Pack,
) {
    write_string(output, value.uuid)
    write_string(output, value.version)
    write_string(output, value.sub_pack_name)
}

read_stack_resource_pack :: proc(
    input: ^Reader,
) -> (value: Stack_Resource_Pack, err: mcpe_runtime.Error) {
    defer if err != nil {
        destroy_stack_resource_pack(&value, input.allocator)
    }
    value.uuid = read_string(input) or_return
    value.version = read_string(input) or_return
    value.sub_pack_name = read_string(input) or_return
    return
}

destroy_experiment_data :: proc(
    value: ^Experiment_Data,
    allocator := context.allocator,
) {
    if value == nil {
        return
    }
    delete(value.name, allocator)
    value^ = {}
}

write_experiment_data :: proc(
    output: ^Writer,
    value: Experiment_Data,
) {
    write_string(output, value.name)
    write_bool(output, value.enabled)
}

read_experiment_data :: proc(
    input: ^Reader,
) -> (value: Experiment_Data, err: mcpe_runtime.Error) {
    value.name = read_string(input) or_return
    value.enabled, err = read_bool(input)
    if err != nil {
        destroy_experiment_data(&value, input.allocator)
    }
    return
}

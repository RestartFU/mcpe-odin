package gt_protocol

import "core:mem"
import mcpe_runtime "mcpe:runtime"

Education_Shared_Resource_URI :: struct {
    button_name: string,
    link_uri:    string,
}

Education_External_Link_Settings :: struct {
    url:          string,
    display_name: string,
}

write_education_shared_resource_uri :: proc(
    output: ^Writer,
    value: Education_Shared_Resource_URI,
) {
    write_string(output, value.button_name)
    write_string(output, value.link_uri)
}

read_education_shared_resource_uri :: proc(
    input: ^Reader,
) -> (
    value: Education_Shared_Resource_URI,
    err: mcpe_runtime.Error,
) {
    value.button_name = read_string(input) or_return
    value.link_uri, err = read_string(input)
    if err != nil {
        delete(value.button_name, input.allocator)
        value.button_name = ""
    }
    return
}

destroy_education_shared_resource_uri :: proc(
    value: ^Education_Shared_Resource_URI,
    allocator: mem.Allocator = context.allocator,
) {
    if value == nil {
        return
    }
    delete(value.button_name, allocator)
    delete(value.link_uri, allocator)
    value^ = {}
}

write_education_external_link_settings :: proc(
    output: ^Writer,
    value: Education_External_Link_Settings,
) {
    write_string(output, value.url)
    write_string(output, value.display_name)
}

read_education_external_link_settings :: proc(
    input: ^Reader,
) -> (
    value: Education_External_Link_Settings,
    err: mcpe_runtime.Error,
) {
    value.url = read_string(input) or_return
    value.display_name, err = read_string(input)
    if err != nil {
        delete(value.url, input.allocator)
        value.url = ""
    }
    return
}

destroy_education_external_link_settings :: proc(
    value: ^Education_External_Link_Settings,
    allocator: mem.Allocator = context.allocator,
) {
    if value == nil {
        return
    }
    delete(value.url, allocator)
    delete(value.display_name, allocator)
    value^ = {}
}

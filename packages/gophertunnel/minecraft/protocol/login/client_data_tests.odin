package gt_login

import "core:testing"
import protocol "mcpe:gophertunnel/minecraft/protocol"
import mcpe_runtime "mcpe:runtime"

@(test)
device_id_format_matches_upstream :: proc(t: ^testing.T) {
    cases := [?]struct {
        value:    Device_ID,
        expected: Device_ID_Format,
    }{
        {"ada3dfa4622f4e2fb2c14a496d52db96", .Lower_Hex_String},
        {"ADA3DFA4622F4E2FB2C14A496D52DB96", .Upper_Hex_String},
        {"Ada3DFA4622F4E2FB2C14A496D52DB96", .Upper_Hex_String},
        {"00112233-4455-6677-8899-aabbccddeeff", .UUID},
        {"00112233445566778899aabbccddeeff", .Lower_Hex_String},
        {"VlhnpI7TuWyfHiUx3WYwFvQQHbDkv505h6VVo40Cngw=", .Base64},
        {"VlhnpI7TuWyfHiUx3WYwFvQQHbDkv505h6VVo40Cngw", .Invalid},
        {"not-a-device-id", .Invalid},
    }
    for test_case in cases {
        testing.expect_value(
            t,
            device_id_format(test_case.value),
            test_case.expected,
        )
    }
}

@(test)
expected_device_id_format_matches_platform :: proc(t: ^testing.T) {
    cases := [?]struct {
        os:       protocol.Device_OS,
        expected: Device_ID_Format,
    }{
        {.Android, .Lower_Hex_String},
        {.IOS, .Upper_Hex_String},
        {.Win_32, .Lower_Hex_String},
        {.Orbis, .UUID},
        {.XBOX, .Base64},
        {.Linux, .Invalid},
    }
    for test_case in cases {
        testing.expect_value(
            t,
            expected_device_id_format({device_os = test_case.os}),
            test_case.expected,
        )
    }
}

@(test)
generated_device_ids_have_requested_format :: proc(t: ^testing.T) {
    formats := [?]Device_ID_Format{
        .Upper_Hex_String,
        .Lower_Hex_String,
        .Base64,
        .UUID,
        .Invalid,
    }
    for format in formats {
        generated, err := generate_device_id(format)
        testing.expect(t, err == nil)
        if err != nil {
            mcpe_runtime.destroy_error(err)
            continue
        }
        expected := format
        if format == .Invalid {
            expected = .Lower_Hex_String
        }
        testing.expect_value(t, device_id_format(generated), expected)
        delete(string(generated))
    }
}

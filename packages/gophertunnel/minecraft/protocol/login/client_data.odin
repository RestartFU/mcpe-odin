package gt_login

import "core:crypto"
import "core:encoding/base64"
import "core:encoding/uuid"
import "core:math/rand"
import protocol "mcpe:gophertunnel/minecraft/protocol"
import mcpe_runtime "mcpe:runtime"

Device_ID :: distinct string

Device_ID_Format :: enum u8 {
    Upper_Hex_String,
    Lower_Hex_String,
    Base64,
    UUID,
    Invalid,
}

Persona_Piece :: struct {
    default:    bool,
    pack_id:    string,
    piece_id:   string,
    piece_type: string,
    product_id: string,
}

Persona_Piece_Tint_Colour :: struct {
    colours:    [4]string,
    piece_type: string,
}

Skin_Animation :: struct {
    frames:               f64,
    image:                string,
    image_height:         int,
    image_width:          int,
    type:                 int,
    animation_expression: int,
}

Client_Data :: struct {
    animated_image_data:                  []Skin_Animation,
    cape_data:                            string,
    cape_id:                              string,
    cape_image_height:                    int,
    cape_image_width:                     int,
    cape_on_classic_skin:                 bool,
    client_random_id:                     i64,
    current_input_mode:                   int,
    default_input_mode:                   int,
    device_model:                         string,
    device_os:                            protocol.Device_OS,
    device_id:                            Device_ID,
    game_version:                         string,
    gui_scale:                            int,
    filter_profanity:                     bool,
    client_editor_connection_intent:      int,
    client_is_editor_capable:             bool,
    language_code:                        string,
    persona_skin:                         bool,
    platform_offline_id:                  string,
    platform_online_id:                   string,
    platform_user_id:                     string,
    premium_skin:                         bool,
    self_signed_id:                       string,
    server_address:                       string,
    skin_animation_data:                  string,
    skin_data:                            string,
    skin_geometry:                        string,
    skin_geometry_version:                string,
    skin_id:                              string,
    playfab_id:                           string,
    skin_image_height:                    int,
    skin_image_width:                     int,
    skin_resource_patch:                  string,
    skin_colour:                          string,
    arm_size:                             string,
    persona_pieces:                       []Persona_Piece,
    piece_tint_colours:                   []Persona_Piece_Tint_Colour,
    third_party_name:                     string,
    third_party_name_only:                ^bool,
    ui_profile:                           int,
    trusted_skin:                         bool,
    override_skin:                        bool,
    compatible_with_client_side_chunk_gen: bool,
    max_view_distance:                    int,
    memory_tier:                          int,
    platform_type:                        int,
    graphics_mode:                        int,
    party_id:                             string,
    party_leader:                         bool,
}

hex_nibble :: proc(byte: u8) -> (u8, bool) {
    switch byte {
    case '0'..='9':
        return byte - '0', true
    case 'a'..='f':
        return byte - 'a' + 10, true
    case 'A'..='F':
        return byte - 'A' + 10, true
    }
    return 0, false
}

device_id_format :: proc(device_id: Device_ID) -> Device_ID_Format {
    value := string(device_id)
    if len(value) == 32 {
        lower := true
        valid := true
        for byte in transmute([]u8)value {
            _, ok := hex_nibble(byte)
            if !ok {
                valid = false
                break
            }
            if byte >= 'A' && byte <= 'F' {
                lower = false
            }
        }
        if valid {
            return .Lower_Hex_String if lower else .Upper_Hex_String
        }
    }

    _, uuid_ok := parse_identity_uuid(value)
    if uuid_ok {
        return .UUID
    }

    if len(value) == 44 && value[43] == '=' {
        decoded: [32]u8
        data, decode_err := base64.decode_into_buf(decoded[:], value)
        if decode_err == nil && len(data) == len(decoded) {
            return .Base64
        }
    }
    return .Invalid
}

expected_device_id_format :: proc(
    data: Client_Data,
) -> Device_ID_Format {
    switch data.device_os {
    case .Android, .Win_32:
        return .Lower_Hex_String
    case .IOS:
        return .Upper_Hex_String
    case .Orbis:
        return .UUID
    case .XBOX:
        return .Base64
    case .OSX, .Fire_OS, .Gear_VR, .Hololens, .Win_10,
         .Dedicated, .TV_OS, .NX, .WP, .Linux:
        return .Invalid
    }
    return .Invalid
}

device_id_allocation_error :: proc() -> mcpe_runtime.Error {
    return mcpe_runtime.make_error(
        .Internal,
        "gophertunnel.login.generate_device_id",
        "failed to allocate device ID",
    )
}

generate_hex_device_id :: proc(
    upper: bool,
    allocator := context.allocator,
) -> (Device_ID, mcpe_runtime.Error) {
    context.random_generator = crypto.random_generator()
    id := uuid.generate_v4()
    output, allocation_err := make([]u8, 32, allocator)
    if allocation_err != nil {
        return "", device_id_allocation_error()
    }
    lower_digits := "0123456789abcdef"
    upper_digits := "0123456789ABCDEF"
    digits := lower_digits
    if upper {
        digits = upper_digits
    }
    for byte, index in id {
        output[index * 2] = digits[byte >> 4]
        output[index * 2 + 1] = digits[byte & 0x0f]
    }
    return Device_ID(transmute(string)output), nil
}

generate_device_id :: proc(
    format: Device_ID_Format,
    allocator := context.allocator,
) -> (Device_ID, mcpe_runtime.Error) {
    switch format {
    case .Upper_Hex_String:
        return generate_hex_device_id(true, allocator)
    case .UUID:
        context.random_generator = crypto.random_generator()
        value, allocation_err := uuid.to_string_allocated(
            uuid.generate_v4(),
            allocator,
        )
        if allocation_err != nil {
            return "", device_id_allocation_error()
        }
        return Device_ID(value), nil
    case .Base64:
        context.random_generator = crypto.random_generator()
        random: [32]u8
        if rand.read(random[:]) != len(random) {
            return "", mcpe_runtime.make_error(
                .Internal,
                "gophertunnel.login.generate_device_id",
                "failed to generate random device ID",
            )
        }
        value, allocation_err := base64.encode(
            random[:],
            allocator = allocator,
        )
        if allocation_err != nil {
            return "", device_id_allocation_error()
        }
        return Device_ID(value), nil
    case .Lower_Hex_String, .Invalid:
        return generate_hex_device_id(false, allocator)
    }
    return generate_hex_device_id(false, allocator)
}

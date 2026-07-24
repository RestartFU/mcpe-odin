package gt_login

import "core:encoding/uuid"
import "core:strconv"
import "core:unicode"
import mcpe_runtime "mcpe:runtime"

Identity_Data :: struct {
    xuid:              string,
    identity:          string,
    display_name:      string,
    title_id:          string,
    playfab_title_id:  string,
    playfab_id:        string,
}

identity_error :: proc(message: string) -> mcpe_runtime.Error {
    return mcpe_runtime.make_error(
        .Invalid_Argument,
        "gophertunnel.login.validate_identity_data",
        message,
    )
}

contains_online_username_character :: proc(value: string) -> bool {
    for byte in transmute([]u8)value {
        if byte == ' ' ||
           byte >= 'A' && byte <= 'Z' ||
           byte >= 'a' && byte <= 'z' ||
           byte >= '0' && byte <= '9' {
            return true
        }
    }
    return false
}

contains_offline_username_character :: proc(value: string) -> bool {
    for character in value {
        if character == ' ' || unicode.is_letter(character) {
            return true
        }
    }
    return false
}

ascii_equal_fold :: proc(left, right: string) -> bool {
    if len(left) != len(right) {
        return false
    }
    for byte, index in transmute([]u8)left {
        left_byte := byte
        other := right[index]
        if left_byte >= 'A' && left_byte <= 'Z' {
            left_byte += 'a' - 'A'
        }
        if other >= 'A' && other <= 'Z' {
            other += 'a' - 'A'
        }
        if left_byte != other {
            return false
        }
    }
    return true
}

parse_identity_uuid :: proc(value: string) -> (
    identity: uuid.Identifier,
    ok: bool,
) {
    candidate := value
    switch len(value) {
    case 36:
    case 45:
        if !ascii_equal_fold(value[:9], "urn:uuid:") {
            return {}, false
        }
        candidate = value[9:]
    case 38:
        // google/uuid.Parse deliberately ignores the wrapping bytes.
        candidate = value[1:37]
    case 32:
        canonical: [36]u8
        source_index := 0
        for index in 0..<len(canonical) {
            if index == 8 || index == 13 ||
               index == 18 || index == 23 {
                canonical[index] = '-'
            } else {
                canonical[index] = value[source_index]
                source_index += 1
            }
        }
        parsed, parse_err := uuid.read(string(canonical[:]))
        return parsed, parse_err == .None
    case:
        return {}, false
    }
    parsed, parse_err := uuid.read(candidate)
    return parsed, parse_err == .None
}

contains_double_space :: proc(value: string) -> bool {
    if len(value) < 2 {
        return false
    }
    bytes := transmute([]u8)value
    for index in 0..<len(bytes) - 1 {
        if bytes[index] == ' ' && bytes[index + 1] == ' ' {
            return true
        }
    }
    return false
}

parse_go_i64_decimal :: proc(value: string) -> (i64, bool) {
    if len(value) == 0 {
        return 0, false
    }
    index := 0
    if value[0] == '+' || value[0] == '-' {
        index = 1
    }
    if index == len(value) {
        return 0, false
    }
    for byte in value[index:] {
        if byte < '0' || byte > '9' {
            return 0, false
        }
    }
    return strconv.parse_i64_of_base(value, 10)
}

validate_identity_data :: proc(
    data: Identity_Data,
) -> mcpe_runtime.Error {
    if len(data.xuid) != 0 {
        _, xuid_ok := parse_go_i64_decimal(data.xuid)
        if !xuid_ok {
            return identity_error("XUID must be parseable as int64")
        }
    }

    identity, identity_ok := parse_identity_uuid(data.identity)
    if !identity_ok || identity == {} {
        return identity_error("identity must be a non-zero UUID")
    }

    name_limit := 15 if len(data.xuid) != 0 else 16
    if len(data.display_name) == 0 ||
       len(data.display_name) > name_limit {
        return identity_error("display name length is invalid")
    }
    if data.display_name[0] == ' ' ||
       data.display_name[len(data.display_name) - 1] == ' ' {
        return identity_error("display name starts or ends with space")
    }
    if data.display_name[0] >= '0' &&
       data.display_name[0] <= '9' {
        return identity_error("display name starts with a number")
    }
    if len(data.xuid) != 0 {
        // Upstream's unanchored regular expression checks that at least one
        // ASCII username character exists, rather than checking every byte.
        if !contains_online_username_character(data.display_name) {
            return identity_error("online display name has no valid character")
        }
    } else if !contains_offline_username_character(data.display_name) {
        // Same upstream quirk: one Unicode letter or space is sufficient.
        return identity_error("offline display name has no valid character")
    }
    if contains_double_space(data.display_name) {
        return identity_error("display name contains consecutive spaces")
    }
    return nil
}

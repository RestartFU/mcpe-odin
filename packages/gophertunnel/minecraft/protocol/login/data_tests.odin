package gt_login

import "core:testing"
import mcpe_runtime "mcpe:runtime"

valid_identity :: proc() -> Identity_Data {
    return {
        xuid = "2533274790395904",
        identity = "00112233-4455-6677-8899-aabbccddeeff",
        display_name = "Steve",
    }
}

@(test)
identity_validation_accepts_online_and_offline_data :: proc(
    t: ^testing.T,
) {
    online := valid_identity()
    testing.expect(t, validate_identity_data(online) == nil)

    offline := online
    offline.xuid = ""
    offline.display_name = "Alex"
    testing.expect(t, validate_identity_data(offline) == nil)

    signed := online
    signed.xuid = "+1"
    testing.expect(t, validate_identity_data(signed) == nil)
    signed.xuid = "-1"
    testing.expect(t, validate_identity_data(signed) == nil)
}

@(test)
identity_validation_preserves_upstream_regex_quirks :: proc(
    t: ^testing.T,
) {
    online := valid_identity()
    online.display_name = "A#"
    testing.expect(t, validate_identity_data(online) == nil)

    offline := online
    offline.xuid = ""
    offline.display_name = "É#"
    testing.expect(t, validate_identity_data(offline) == nil)
}

@(test)
identity_validation_accepts_upstream_uuid_forms :: proc(
    t: ^testing.T,
) {
    forms := [?]string{
        "00112233445566778899aabbccddeeff",
        "urn:uuid:00112233-4455-6677-8899-aabbccddeeff",
        "URN:UUID:00112233-4455-6677-8899-aabbccddeeff",
        "{00112233-4455-6677-8899-aabbccddeeff}",
        "!00112233-4455-6677-8899-aabbccddeeff?",
    }
    for form in forms {
        value := valid_identity()
        value.identity = form
        testing.expect(t, validate_identity_data(value) == nil)
    }
}

@(test)
identity_validation_rejects_invalid_fields :: proc(t: ^testing.T) {
    cases := [?]Identity_Data{
        {
            xuid = "not-a-number",
            identity = "00112233-4455-6677-8899-aabbccddeeff",
            display_name = "Steve",
        },
        {
            xuid = "1_2",
            identity = "00112233-4455-6677-8899-aabbccddeeff",
            display_name = "Steve",
        },
        {
            identity = "00000000-0000-0000-0000-000000000000",
            display_name = "Steve",
        },
        {
            identity = "not-a-uuid",
            display_name = "Steve",
        },
        {
            identity = "00112233-4455-6677-8899-aabbccddeeff",
            display_name = "",
        },
        {
            identity = "00112233-4455-6677-8899-aabbccddeeff",
            display_name = "1Steve",
        },
        {
            identity = "00112233-4455-6677-8899-aabbccddeeff",
            display_name = " Steve",
        },
        {
            identity = "00112233-4455-6677-8899-aabbccddeeff",
            display_name = "Steve  Alex",
        },
        {
            identity = "00112233-4455-6677-8899-aabbccddeeff",
            display_name = "###",
        },
    }
    for value in cases {
        err := validate_identity_data(value)
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
}

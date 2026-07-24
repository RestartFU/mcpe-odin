package gt_packet

import protocol "mcpe:gophertunnel/minecraft/protocol"
import mcpe_runtime "mcpe:runtime"

Dimension_Overworld :: i32(0)
Dimension_Nether    :: i32(1)
Dimension_End       :: i32(2)

Loading_Screen_Type_Unknown :: i32(0)
Loading_Screen_Type_Start   :: i32(1)
Loading_Screen_Type_End     :: i32(2)

Change_Dimension :: struct {
    dimension:         i32,
    position:          protocol.Vec3,
    respawn:           bool,
    loading_screen_id: protocol.Optional(u32),
}

Server_Bound_Loading_Screen :: struct {
    type:              i32,
    loading_screen_id: protocol.Optional(u32),
}

write_optional_u32 :: proc(
    output: ^protocol.Writer,
    value: protocol.Optional(u32),
) {
    protocol.write_bool(output, value.set)
    if value.set {
        protocol.write_u32(output, value.value)
    }
}

read_optional_u32 :: proc(
    input: ^protocol.Reader,
) -> (
    value: protocol.Optional(u32),
    err: mcpe_runtime.Error,
) {
    value.set = protocol.read_bool(input) or_return
    if value.set {
        value.value = protocol.read_u32(input) or_return
    }
    return
}

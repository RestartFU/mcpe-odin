package gt_packet

import protocol "mcpe:gophertunnel/minecraft/protocol"
import mcpe_runtime "mcpe:runtime"

Title_Action_Clear                 :: i32(0)
Title_Action_Reset                 :: i32(1)
Title_Action_Set_Title             :: i32(2)
Title_Action_Set_Subtitle          :: i32(3)
Title_Action_Set_Action_Bar        :: i32(4)
Title_Action_Set_Durations         :: i32(5)
Title_Action_Title_Text_Object     :: i32(6)
Title_Action_Subtitle_Text_Object  :: i32(7)
Title_Action_Actionbar_Text_Object :: i32(8)

Store_Offer_Type_Marketplace :: u8(0)
Store_Offer_Type_Dressing_Room :: u8(1)
Store_Offer_Type_Server_Page :: u8(2)

Modal_Form_Cancel_Reason_User_Closed :: u8(0)
Modal_Form_Cancel_Reason_User_Busy   :: u8(1)

Set_Title :: struct {
    action_type:        i32,
    text:               string,
    fade_in_duration:   i32,
    remain_duration:    i32,
    fade_out_duration:  i32,
    xuid:               string,
    platform_online_id: string,
    filtered_message:   string,
}

Show_Store_Offer :: struct {
    offer_id: protocol.UUID,
    type:     u8,
}

Purchase_Receipt :: struct {
    receipts: []string,
}

Modal_Form_Response :: struct {
    form_id:       u32,
    response_data: protocol.Optional([]u8),
    cancel_reason: protocol.Optional(u8),
}

Server_Settings_Request :: struct {}

Server_Settings_Response :: struct {
    form_id:   u32,
    form_data: []u8,
}

Settings_Command :: struct {
    command_line:    string,
    suppress_output: bool,
}

destroy_set_title_value :: proc(
    packet: Set_Title,
    allocator := context.allocator,
) {
    delete(packet.text, allocator)
    delete(packet.xuid, allocator)
    delete(packet.platform_online_id, allocator)
    delete(packet.filtered_message, allocator)
}

read_set_title :: proc(
    input: ^protocol.Reader,
) -> (packet: Set_Title, err: mcpe_runtime.Error) {
    defer if err != nil {
        destroy_set_title_value(packet, input.allocator)
        packet = {}
    }
    packet.action_type = protocol.read_varint32(input) or_return
    packet.text = protocol.read_string(input) or_return
    packet.fade_in_duration = protocol.read_varint32(input) or_return
    packet.remain_duration = protocol.read_varint32(input) or_return
    packet.fade_out_duration = protocol.read_varint32(input) or_return
    packet.xuid = protocol.read_string(input) or_return
    packet.platform_online_id = protocol.read_string(input) or_return
    packet.filtered_message = protocol.read_string(input) or_return
    return
}

destroy_purchase_receipt_value :: proc(
    packet: Purchase_Receipt,
    allocator := context.allocator,
) {
    for receipt in packet.receipts {
        delete(receipt, allocator)
    }
    delete(packet.receipts, allocator)
}

read_purchase_receipt :: proc(
    input: ^protocol.Reader,
) -> (packet: Purchase_Receipt, err: mcpe_runtime.Error) {
    defer if err != nil {
        destroy_purchase_receipt_value(packet, input.allocator)
        packet = {}
    }
    count := protocol.read_varuint32(input) or_return
    if count > protocol.MAX_COLLECTION_ELEMENTS {
        err = packet_error(
            .Limit_Exceeded,
            "gophertunnel.packet.read_purchase_receipt",
            "receipt list exceeds entry limit",
        )
        return
    }
    packet.receipts = make([]string, int(count), input.allocator)
    for &receipt in packet.receipts {
        receipt = protocol.read_string(input) or_return
    }
    return
}

read_modal_form_response :: proc(
    input: ^protocol.Reader,
) -> (packet: Modal_Form_Response, err: mcpe_runtime.Error) {
    defer if err != nil {
        if packet.response_data.set {
            delete(packet.response_data.value, input.allocator)
        }
        packet = {}
    }
    packet.form_id = protocol.read_varuint32(input) or_return
    packet.response_data.set = protocol.read_bool(input) or_return
    if packet.response_data.set {
        packet.response_data.value =
            protocol.read_byte_slice(input) or_return
    }
    packet.cancel_reason.set = protocol.read_bool(input) or_return
    if packet.cancel_reason.set {
        packet.cancel_reason.value = protocol.read_u8(input) or_return
    }
    return
}

read_server_settings_response :: proc(
    input: ^protocol.Reader,
) -> (packet: Server_Settings_Response, err: mcpe_runtime.Error) {
    packet.form_id = protocol.read_varuint32(input) or_return
    packet.form_data = protocol.read_byte_slice(input) or_return
    return
}

read_settings_command :: proc(
    input: ^protocol.Reader,
) -> (packet: Settings_Command, err: mcpe_runtime.Error) {
    packet.command_line = protocol.read_string(input) or_return
    packet.suppress_output, err = protocol.read_bool(input)
    if err != nil {
        delete(packet.command_line, input.allocator)
        packet = {}
    }
    return
}

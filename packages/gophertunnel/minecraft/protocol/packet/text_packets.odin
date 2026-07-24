package gt_packet

import protocol "mcpe:gophertunnel/minecraft/protocol"
import mcpe_runtime "mcpe:runtime"

Text_Type_Raw                 :: u8(0)
Text_Type_Chat                :: u8(1)
Text_Type_Translation         :: u8(2)
Text_Type_Popup               :: u8(3)
Text_Type_Jukebox_Popup       :: u8(4)
Text_Type_Tip                 :: u8(5)
Text_Type_System              :: u8(6)
Text_Type_Whisper             :: u8(7)
Text_Type_Announcement        :: u8(8)
Text_Type_Object_Whisper      :: u8(9)
Text_Type_Object              :: u8(10)
Text_Type_Object_Announcement :: u8(11)

Text_Category_Message_Only            :: u8(0)
Text_Category_Authored_Message         :: u8(1)
Text_Category_Message_With_Parameters  :: u8(2)

Text :: struct {
    text_type:         u8,
    needs_translation: bool,
    source_name:       string,
    message:           string,
    parameters:        []string,
    xuid:              string,
    platform_chat_id:  string,
    filtered_message:  protocol.Optional(string),
}

text_category :: proc(text_type: u8) -> u8 {
    switch text_type {
    case Text_Type_Raw,
         Text_Type_Tip,
         Text_Type_System,
         Text_Type_Object_Whisper,
         Text_Type_Object_Announcement,
         Text_Type_Object:
        return Text_Category_Message_Only
    case Text_Type_Chat, Text_Type_Whisper, Text_Type_Announcement:
        return Text_Category_Authored_Message
    }
    return Text_Category_Message_With_Parameters
}

valid_text_type :: proc(text_type: u8) -> bool {
    return text_type <= Text_Type_Object_Announcement
}

text_type_has_parameters :: proc(text_type: u8) -> bool {
    return text_type == Text_Type_Translation ||
           text_type == Text_Type_Popup ||
           text_type == Text_Type_Jukebox_Popup
}

destroy_text_value :: proc(
    packet: Text,
    allocator := context.allocator,
) {
    delete(packet.source_name, allocator)
    delete(packet.message, allocator)
    for parameter in packet.parameters {
        delete(parameter, allocator)
    }
    delete(packet.parameters, allocator)
    delete(packet.xuid, allocator)
    delete(packet.platform_chat_id, allocator)
    if packet.filtered_message.set {
        delete(packet.filtered_message.value, allocator)
    }
}

read_text :: proc(
    input: ^protocol.Reader,
) -> (packet: Text, err: mcpe_runtime.Error) {
    defer if err != nil {
        destroy_text_value(packet, input.allocator)
        packet = {}
    }
    packet.needs_translation = protocol.read_bool(input) or_return
    _ = protocol.read_u8(input) or_return
    packet.text_type = protocol.read_u8(input) or_return
    switch packet.text_type {
    case Text_Type_Chat, Text_Type_Whisper, Text_Type_Announcement:
        packet.source_name = protocol.read_string(input) or_return
        packet.message = protocol.read_string(input) or_return
    case Text_Type_Raw,
         Text_Type_Tip,
         Text_Type_System,
         Text_Type_Object,
         Text_Type_Object_Whisper,
         Text_Type_Object_Announcement:
        packet.message = protocol.read_string(input) or_return
    case Text_Type_Translation, Text_Type_Popup, Text_Type_Jukebox_Popup:
        packet.message = protocol.read_string(input) or_return
        count := protocol.read_varuint32(input) or_return
        if count > protocol.MAX_COLLECTION_ELEMENTS {
            err = packet_error(
                .Limit_Exceeded,
                "gophertunnel.packet.read_text",
                "text parameter list exceeds entry limit",
            )
            return
        }
        packet.parameters = make(
            []string,
            int(count),
            input.allocator,
        )
        for &parameter in packet.parameters {
            parameter = protocol.read_string(input) or_return
        }
    }
    if len(packet.message) == 0 {
        err = packet_error(
            .Malformed,
            "gophertunnel.packet.read_text",
            "message cannot be empty",
        )
        return
    }
    packet.xuid = protocol.read_string(input) or_return
    packet.platform_chat_id = protocol.read_string(input) or_return
    packet.filtered_message.set = protocol.read_bool(input) or_return
    if packet.filtered_message.set {
        packet.filtered_message.value =
            protocol.read_string(input) or_return
    }
    return
}

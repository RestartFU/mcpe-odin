package raknet

import "core:mem"
import mcpe_runtime "mcpe:runtime"

MAX_SPLIT_COUNT      :: 512
MAX_CONCURRENT_SPLITS :: 16

Split_Record :: struct {
    fragments: [dynamic][]u8,
    received:  int,
}

Split_Assembler :: struct {
    allocator: mem.Allocator,
    records: map[u16]Split_Record,
}

split_assembler_init :: proc(allocator: mem.Allocator = context.allocator) -> Split_Assembler {
    return Split_Assembler{
        allocator = allocator,
        records = make(map[u16]Split_Record, allocator),
    }
}

split_record_destroy :: proc(record: ^Split_Record, allocator: mem.Allocator = context.allocator) {
    for fragment in record.fragments {
        delete(fragment, allocator)
    }
    // Odin dynamic arrays retain their construction allocator internally.
    delete(record.fragments)
    record^ = {}
}

split_assembler_destroy :: proc(assembler: ^Split_Assembler) {
    for _, record in assembler.records {
        owned := record
        split_record_destroy(&owned, assembler.allocator)
    }
    // Odin maps likewise retain the allocator passed to make.
    delete(assembler.records)
    assembler^ = {}
}

split_assembler_add :: proc(
    assembler: ^Split_Assembler,
    packet: ^Packet,
    limits_enabled: bool,
) -> (content: []u8, complete: bool, err: mcpe_runtime.Error) {
    if packet.split_count == 0 {
        err = mcpe_runtime.make_error(.Malformed, "raknet.split_assembler_add", "split count is zero")
        return
    }
    if limits_enabled && packet.split_count > MAX_SPLIT_COUNT {
        err = mcpe_runtime.make_error(.Limit_Exceeded, "raknet.split_assembler_add", "split count exceeds maximum")
        return
    }
    if limits_enabled && len(assembler.records) >= MAX_CONCURRENT_SPLITS {
        if _, exists := assembler.records[packet.split_id]; !exists {
            err = mcpe_runtime.make_error(.Limit_Exceeded, "raknet.split_assembler_add", "maximum concurrent splits reached")
            return
        }
    }
    if packet.split_index >= packet.split_count {
        err = mcpe_runtime.make_error(.Malformed, "raknet.split_assembler_add", "split index out of range")
        return
    }

    record, exists := assembler.records[packet.split_id]
    if !exists {
        record.fragments = make([dynamic][]u8, int(packet.split_count), assembler.allocator)
    } else if len(record.fragments) != int(packet.split_count) {
        err = mcpe_runtime.make_error(.Malformed, "raknet.split_assembler_add", "split count changed")
        return
    }

    index := int(packet.split_index)
    if len(record.fragments[index]) == 0 {
        fragment := make([]u8, len(packet.content), assembler.allocator)
        copy(fragment, packet.content)
        record.fragments[index] = fragment
        record.received += 1
    }
    assembler.records[packet.split_id] = record
    if record.received != len(record.fragments) {
        return nil, false, nil
    }

    total := 0
    for fragment in record.fragments {
        total += len(fragment)
    }
    content = make([]u8, total, assembler.allocator)
    offset := 0
    for fragment in record.fragments {
        copy(content[offset:], fragment)
        offset += len(fragment)
    }
    delete_key(&assembler.records, packet.split_id)
    split_record_destroy(&record, assembler.allocator)
    return content, true, nil
}

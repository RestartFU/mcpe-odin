package mcpe_benchmarks

import "base:runtime"
import "core:fmt"
import "core:testing"
import "core:time"
import raknet "mcpe:raknet"
import mcpe_runtime "mcpe:runtime"

packet_decode_benchmark :: proc(
    options: ^time.Benchmark_Options,
    allocator: runtime.Allocator,
) -> time.Benchmark_Error {
    hash: u128
    for _ in 0..<options.rounds {
        packet, consumed, err := raknet.decode_packet(options.input)
        if err != nil {
            mcpe_runtime.destroy_error(err)
            return .Allocation_Error
        }
        hash += u128(packet.message_index) + u128(consumed)
    }
    options.count = options.rounds
    options.processed = options.rounds * len(options.input)
    options.hash = hash
    return .Okay
}

fragment_benchmark :: proc(
    options: ^time.Benchmark_Options,
    allocator: runtime.Allocator,
) -> time.Benchmark_Error {
    fragment_count := 0
    for _ in 0..<options.rounds {
        fragments, err := raknet.split_content(options.input, 1400)
        if err != nil {
            mcpe_runtime.destroy_error(err)
            return .Allocation_Error
        }
        fragment_count += len(fragments)
        delete(fragments)
    }
    options.count = options.rounds
    options.processed = options.rounds * len(options.input)
    options.hash = u128(fragment_count)
    return .Okay
}

@(test)
packet_decode_1_kib :: proc(t: ^testing.T) {
    content: [1024]u8
    packet := raknet.Packet{
        reliability = .Reliable_Ordered,
        message_index = 7,
        order_index = 11,
        content = content[:],
    }
    writer := raknet.writer()
    defer raknet.writer_destroy(&writer)
    raknet.write_packet(&writer, &packet)

    options := time.Benchmark_Options{
        bench = packet_decode_benchmark,
        rounds = 200_000,
        input = writer.data[:],
    }
    err := time.benchmark(&options)
    testing.expect_value(t, err, time.Benchmark_Error.Okay)
    testing.expect(t, options.hash != 0)
    fmt.printf(
        "raknet packet decode 1 KiB: %.2f MiB/s, %.0f packets/s\n",
        options.megabytes_per_second,
        options.rounds_per_second,
    )
}

@(test)
fragment_64_kib :: proc(t: ^testing.T) {
    payload: [65536]u8
    options := time.Benchmark_Options{
        bench = fragment_benchmark,
        rounds = 20_000,
        input = payload[:],
    }
    err := time.benchmark(&options)
    testing.expect_value(t, err, time.Benchmark_Error.Okay)
    testing.expect(t, options.hash != 0)
    fmt.printf(
        "raknet fragment 64 KiB: %.2f MiB/s, %.0f messages/s\n",
        options.megabytes_per_second,
        options.rounds_per_second,
    )
}

package raknet

import "core:net"
import mcpe_runtime "mcpe:runtime"

Packet_Transport_Read_Proc :: proc "odin" (
    user_data: rawptr,
    buffer: []u8,
) -> (
    count: int,
    remote: net.Endpoint,
    err: mcpe_runtime.Error,
)

Packet_Transport_Write_Proc :: proc "odin" (
    user_data: rawptr,
    data: []u8,
    remote: net.Endpoint,
) -> (written: int, err: mcpe_runtime.Error)

Packet_Transport_Close_Proc :: proc "odin" (
    user_data: rawptr,
) -> mcpe_runtime.Error

Packet_Transport_Local_Endpoint_Proc :: proc "odin" (
    user_data: rawptr,
) -> (endpoint: net.Endpoint, err: mcpe_runtime.Error)

Packet_Transport_Set_Deadline_Proc :: proc "odin" (
    user_data: rawptr,
    deadline_ns: i64,
) -> mcpe_runtime.Error

Packet_Transport_VTable :: struct {
    read:           Packet_Transport_Read_Proc,
    write:          Packet_Transport_Write_Proc,
    close:          Packet_Transport_Close_Proc,
    local_endpoint: Packet_Transport_Local_Endpoint_Proc,
    set_deadline:   Packet_Transport_Set_Deadline_Proc,
}

// Packet_Transport represents the packet-oriented operations used by RakNet.
// Procedures must be safe for concurrent reads and writes.
//
// Connected transports may return a zero remote endpoint from read. Dialer
// substitutes the connected_remote supplied by Upstream_Dial_Proc.
//
// close must interrupt an in-progress read, matching net.Conn and
// net.PacketConn.
//
// set_deadline receives absolute runtime.system_now_ns deadlines. Handshake
// reads use deadlines no more than 100 ms away so packet retransmission,
// cancellation and listener maintenance remain responsive. Zero clears the
// deadline after a successful RakNet handshake. RakNet closes an accepted
// transport exactly once.
//
// Write errors with kind Closed are terminal. All other write errors are
// logged and treated as recoverable, matching pinned go-raknet's writeTo
// policy. The written count is informational: Like upstream, RakNet trusts a
// nil write error even when a custom transport reports a short count.
Packet_Transport :: struct {
    user_data: rawptr,
    vtable:    ^Packet_Transport_VTable,
}

packet_transport_validate :: proc(
    transport: Packet_Transport,
    operation: string,
) -> mcpe_runtime.Error {
    if transport.vtable == nil {
        return nil
    }
    if transport.vtable.read == nil ||
       transport.vtable.write == nil ||
       transport.vtable.close == nil ||
       transport.vtable.local_endpoint == nil {
        return mcpe_runtime.make_error(
            .Invalid_Argument,
            operation,
            "packet transport vtable is incomplete",
        )
    }
    return nil
}

packet_transport_set_deadline :: proc(
    transport: Packet_Transport,
    deadline_ns: i64,
) -> mcpe_runtime.Error {
    if transport.vtable != nil && transport.vtable.set_deadline != nil {
        return transport.vtable.set_deadline(
            transport.user_data,
            deadline_ns,
        )
    }
    return nil
}

packet_transport_read :: proc(
    transport: Packet_Transport,
    socket: net.UDP_Socket,
    buffer: []u8,
) -> (
    count: int,
    remote: net.Endpoint,
    err: mcpe_runtime.Error,
) {
    if transport.vtable != nil {
        return transport.vtable.read(transport.user_data, buffer)
    }
    receive_err: net.UDP_Recv_Error
    count, remote, receive_err = net.recv_udp(socket, buffer)
    if receive_err != nil {
        kind := mcpe_runtime.Error_Kind.Network
        if receive_err == .Timeout || receive_err == .Would_Block {
            kind = .Timeout
        }
        err = network_error("raknet.transport.read", kind)
    }
    return
}

packet_transport_write :: proc(
    transport: Packet_Transport,
    socket: net.UDP_Socket,
    data: []u8,
    remote: net.Endpoint,
) -> (
    written: int,
    terminal: bool,
    err: mcpe_runtime.Error,
) {
    if transport.vtable != nil {
        written, err = transport.vtable.write(
            transport.user_data,
            data,
            remote,
        )
        // Pinned go-raknet only propagates net.ErrClosed here. Every other
        // custom net.PacketConn error is logged and left to ACK/NACK recovery.
        terminal = err != nil && err.kind == .Closed
        return
    }
    send_err: net.UDP_Send_Error
    written, send_err = net.send_udp(socket, data, remote)
    if send_err != nil {
        terminal = conn_send_error_is_terminal(send_err)
        err = network_error("raknet.transport.write")
    }
    return
}

packet_transport_close :: proc(
    transport: Packet_Transport,
    socket: net.UDP_Socket,
) -> mcpe_runtime.Error {
    if transport.vtable != nil {
        return transport.vtable.close(transport.user_data)
    }
    net.close(socket)
    return nil
}

packet_transport_local_endpoint :: proc(
    transport: Packet_Transport,
    socket: net.UDP_Socket,
) -> (endpoint: net.Endpoint, err: mcpe_runtime.Error) {
    if transport.vtable != nil {
        return transport.vtable.local_endpoint(transport.user_data)
    }
    native_endpoint, endpoint_err := net.bound_endpoint(socket)
    if endpoint_err != nil {
        err = network_error("raknet.transport.local_endpoint")
        return
    }
    endpoint = native_endpoint
    return
}

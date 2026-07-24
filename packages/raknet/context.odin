package raknet

import "core:mem"
import "core:sync"
import mcpe_runtime "mcpe:runtime"

Conn_Context_State :: struct {
    allocator:       mem.Allocator,
    reference_count: i64,
    token:           mcpe_runtime.Cancel_Token,
}

Conn_Context :: struct {
    state: ^Conn_Context_State,
}

conn_context_create :: proc(allocator: mem.Allocator) -> Conn_Context {
    state := new(Conn_Context_State, allocator)
    state.allocator = allocator
    state.reference_count = 1
    return Conn_Context{state = state}
}

clone_context :: proc(value: Conn_Context) -> Conn_Context {
    if value.state != nil {
        previous := sync.atomic_add(&value.state.reference_count, 1)
        assert(previous > 0)
    }
    return value
}

destroy_context :: proc(value: ^Conn_Context) {
    if value == nil || value.state == nil {
        return
    }
    state := value.state
    value^ = {}
    previous := sync.atomic_add(&state.reference_count, -1)
    assert(previous > 0)
    if previous == 1 {
        free(state, state.allocator)
    }
}

context_token :: proc(value: Conn_Context) -> ^mcpe_runtime.Cancel_Token {
    if value.state == nil {
        return nil
    }
    return &value.state.token
}

context_cancelled :: proc(value: Conn_Context) -> bool {
    return mcpe_runtime.is_cancelled(context_token(value))
}

connection_context :: proc(conn: ^Conn) -> Conn_Context {
    if conn == nil {
        return {}
    }
    return clone_context(conn.lifecycle_context)
}

package raknet

Reliable_Window_Result :: enum {
    Added,
    Duplicate,
    Out_Of_Window,
}

Reliable_Window :: struct {
    initialized: bool,
    newest:      UInt24,
    entries:     map[UInt24]bool,
}

reliable_window_init :: proc() -> Reliable_Window {
    return Reliable_Window{entries = make(map[UInt24]bool)}
}

reliable_window_destroy :: proc(window: ^Reliable_Window) {
    delete(window.entries)
    window^ = {}
}

reliable_window_add :: proc(
    window: ^Reliable_Window,
    index: UInt24,
) -> Reliable_Window_Result {
    if _, exists := window.entries[index]; exists {
        return .Duplicate
    }
    if !window.initialized {
        window.initialized = true
        window.newest = index
        window.entries[index] = true
        return .Added
    }

    if uint24_before(window.newest, index) {
        if uint24_forward_distance(window.newest, index) >
           u32(MAX_WINDOW_SIZE) {
            return .Out_Of_Window
        }
        window.newest = index
        for previous in window.entries {
            if uint24_forward_distance(previous, window.newest) >
               u32(MAX_WINDOW_SIZE) {
                delete_key(&window.entries, previous)
            }
        }
        window.entries[index] = true
        return .Added
    }
    if uint24_before(index, window.newest) {
        if uint24_forward_distance(index, window.newest) >
           u32(MAX_WINDOW_SIZE) {
            return .Duplicate
        }
        window.entries[index] = true
        return .Added
    }
    return .Out_Of_Window
}

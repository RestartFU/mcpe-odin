package mcpe_runtime

Error_Log_Proc :: proc "odin" (user_data: rawptr, err: Error)

Error_Logger :: struct {
    user_data: rawptr,
    report:    Error_Log_Proc,
}

report_error :: proc(logger: Error_Logger, err: Error) {
    if logger.report != nil && err != nil {
        logger.report(logger.user_data, err)
    }
}

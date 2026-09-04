// Declares the PTY-backed UART DPI ABI and model observations.
#pragma once

extern "C" char rhodium_uart_pty_tick(
    int model_id,
    unsigned char reset,
    unsigned char uart_to_pty_valid,
    char uart_to_pty_byte,
    unsigned char uart_to_pty_framing_error,
    unsigned char pty_to_uart_ready,
    unsigned char* pty_to_uart_valid,
    char* pty_to_uart_byte);

// Creates the model on first use and returns its stable slave-device path.
extern "C" const char* rhodium_uart_pty_path(int model_id);
extern "C" int rhodium_uart_pty_framing_errors(int model_id);

// Declares the stable C ABI between generated simulation RTL and Verilator.
#pragma once

extern "C" int rhdl_htif_tick(unsigned char reset,
                              unsigned char target_xlen,
                              unsigned char request_ready,
                              unsigned char response_valid,
                              int response_data,
                              unsigned char start_ready,
                              unsigned char* request_valid,
                              unsigned char* request_write,
                              long long* request_address,
                              int* request_data,
                              unsigned char* response_ready,
                              unsigned char* start_valid,
                              long long* start_entry);

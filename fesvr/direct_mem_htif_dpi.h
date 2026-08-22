// Declares the stable C ABI between generated simulation RTL and the direct-memory HTIF.
#pragma once

extern "C" int rhdl_htif_tick(unsigned char reset,
                              unsigned char request_ready,
                              unsigned char response_valid,
                              int response_data,
                              unsigned char start_ready,
                              unsigned char* request_valid,
                              unsigned char* request_write,
                              int* request_address,
                              int* request_data,
                              unsigned char* response_ready,
                              unsigned char* start_valid,
                              int* start_entry);

// Wraps the generated RHDL inverter with explicit supplies for focused LVS testing.

`default_nettype none

module rhdl_lvs_smoke (
`ifdef USE_POWER_PINS
    inout vccd1,
    inout vssd1,
`endif
    input  in_bit,
    output out_bit
);

    RhdlTop rhdl_top (.in_bit(in_bit), .out_bit(out_bit));

endmodule

`default_nettype wire

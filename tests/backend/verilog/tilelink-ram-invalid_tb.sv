// Verifies that the TileLink interface monitor rejects an invalid full-write mask without gating ready.
module tilelink_ram_invalid_tb;
  typedef struct packed {
    logic [2:0]  opcode;
    logic [2:0]  param;
    logic [2:0]  size;
    logic [2:0]  source;
    logic [31:0] address;
    logic [3:0]  mask;
    logic [31:0] data;
    logic        corrupt;
  } a_bits_t;
  typedef struct packed { logic valid; a_bits_t bits; } a_forward_t;
  typedef struct packed { logic ready; } a_reverse_t;
  typedef struct packed {
    logic [2:0]  opcode;
    logic [1:0]  param;
    logic [2:0]  size;
    logic [2:0]  source;
    logic        sink;
    logic        denied;
    logic [31:0] data;
    logic        corrupt;
  } d_bits_t;
  typedef struct packed { logic ready; } d_reverse_t;
  typedef struct packed { logic valid; d_bits_t bits; } d_forward_t;
  typedef struct packed { a_forward_t a; d_reverse_t d; } port_in_t;
  typedef struct packed { a_reverse_t a; d_forward_t d; } port_out_t;

  logic clock = 1'b0;
  logic reset = 1'b1;
  port_in_t port_in;
  port_out_t port_out;

  TLRam dut (.*);
  always #5 clock = ~clock;

  initial begin
    port_in = '0;
    @(posedge clock);
    #1;
    reset = 1'b0;
    port_in.a = '{valid: 1'b1,
                  bits: '{opcode: 3'd0,
                          param: 3'b000,
                          size: 3'd2,
                          source: 3'd0,
                          address: 32'h80000000,
                          mask: 4'b0011,
                          data: 32'h12345678,
                          corrupt: 1'b0}};
    #1;
    assert (port_out.a.ready)
      else $fatal(1, "protocol monitoring unexpectedly gated A ready");
    @(posedge clock);
    #1;
    $fatal(1, "invalid full-write mask escaped the TileLink monitor");
  end
endmodule

// Simulates TileLink RAM writes, masks, response metadata, ordering, and D backpressure.
module tilelink_ram_tb;
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

  localparam logic [2:0] PUT_FULL = 3'd0;
  localparam logic [2:0] PUT_PARTIAL = 3'd1;
  localparam logic [2:0] GET = 3'd4;
  localparam logic [2:0] ACCESS_ACK = 3'd0;
  localparam logic [2:0] ACCESS_ACK_DATA = 3'd1;

  logic clock = 1'b0;
  logic reset = 1'b1;
  port_in_t port_in;
  port_out_t port_out;

  TLRam dut (.*);
  always #5 clock = ~clock;

  task automatic tick;
    @(posedge clock);
    #1;
  endtask

  task automatic issue_request(
    input logic [2:0] opcode,
    input logic [2:0] size,
    input logic [2:0] source,
    input logic [31:0] address,
    input logic [3:0] mask,
    input logic [31:0] data,
    input logic corrupt
  );
    port_in.a = '{valid: 1'b1,
                  bits: '{opcode: opcode,
                          param: 3'b000,
                          size: size,
                          source: source,
                          address: address,
                          mask: mask,
                          data: data,
                          corrupt: corrupt}};
    #1;
    assert (port_out.a.ready)
      else $fatal(1, "legal TileLink request was not accepted");
    tick();
    port_in.a.valid = 1'b0;
  endtask

  task automatic check_response(
    input logic [2:0] opcode,
    input logic [2:0] size,
    input logic [2:0] source,
    input logic [31:0] data
  );
    assert (port_out.d.valid)
      else $fatal(1, "expected TileLink response was not valid");
    assert (port_out.d.bits.opcode == opcode)
      else $fatal(1, "response opcode %0d, expected %0d",
                  port_out.d.bits.opcode, opcode);
    assert (port_out.d.bits.size == size)
      else $fatal(1, "response size %0d, expected %0d",
                  port_out.d.bits.size, size);
    assert (port_out.d.bits.source == source)
      else $fatal(1, "response source %0d, expected %0d",
                  port_out.d.bits.source, source);
    assert (port_out.d.bits.param == 2'b00 &&
            port_out.d.bits.sink == 1'b0 &&
            !port_out.d.bits.denied &&
            !port_out.d.bits.corrupt)
      else $fatal(1, "response carried unexpected status metadata");
    assert (port_out.d.bits.data == data)
      else $fatal(1, "response data %h, expected %h",
                  port_out.d.bits.data, data);
  endtask

  initial begin
    port_in = '0;
    tick();
    assert (!port_out.d.valid)
      else $fatal(1, "reset did not clear the TileLink response path");
    reset = 1'b0;

    // Fill both reserved response slots with consecutive full and partial
    // writes while D remains blocked.
    issue_request(PUT_FULL, 3'd2, 3'd1,
                  32'h80000004, 4'b1111, 32'hAABBCCDD, 1'b0);
    // Corruption metadata is intentionally ignored by this initial manager.
    issue_request(PUT_PARTIAL, 3'd2, 3'd2,
                  32'h80000004, 4'b0101, 32'h11223344, 1'b1);

    // A read waits while both response reservations are occupied, then reuses
    // the slot released by the first write acknowledgement in the same cycle.
    port_in.a = '{valid: 1'b1,
                  bits: '{opcode: GET,
                          param: 3'b000,
                          size: 3'd2,
                          source: 3'd3,
                          address: 32'h80000004,
                          mask: 4'b1111,
                          data: 32'b0,
                          corrupt: 1'b0}};
    #1;
    assert (!port_out.a.ready)
      else $fatal(1, "request exceeded the outstanding response window");
    check_response(ACCESS_ACK, 3'd2, 3'd1, 32'b0);
    port_in.d.ready = 1'b1;
    #1;
    assert (port_out.a.ready)
      else $fatal(1, "request did not reuse a consumed response slot");
    tick();
    port_in.a.valid = 1'b0;
    port_in.d.ready = 1'b0;

    check_response(ACCESS_ACK, 3'd2, 3'd2, 32'b0);
    port_in.d.ready = 1'b1;
    tick();
    port_in.d.ready = 1'b0;

    while (!port_out.d.valid)
      tick();
    check_response(ACCESS_ACK_DATA, 3'd2, 3'd3, 32'hAA22CC44);
    repeat (2) begin
      tick();
      check_response(ACCESS_ACK_DATA, 3'd2, 3'd3, 32'hAA22CC44);
    end
    port_in.d.ready = 1'b1;
    tick();
    port_in.d.ready = 1'b0;
    assert (!port_out.d.valid)
      else $fatal(1, "accepted read response remained pending");

    $display("TileLink RAM simulation passed");
    $finish;
  end
endmodule

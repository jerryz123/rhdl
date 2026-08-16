// Simulates TileLink opcode response mappings and data-dependent beat counts.
module tilelink_protocol_tb;
  localparam logic [2:0] A_PUT_FULL = 3'd0;
  localparam logic [2:0] A_GET = 3'd4;
  localparam logic [2:0] B_PUT_FULL = 3'd0;
  localparam logic [2:0] B_PROBE_BLOCK = 3'd6;
  localparam logic [2:0] C_ACCESS_ACK = 3'd0;
  localparam logic [2:0] C_PROBE_ACK_DATA = 3'd5;
  localparam logic [2:0] C_RELEASE_DATA = 3'd7;
  localparam logic [2:0] D_ACCESS_ACK = 3'd0;
  localparam logic [2:0] D_ACCESS_ACK_DATA = 3'd1;
  localparam logic [2:0] D_GRANT_DATA = 3'd5;
  localparam logic [2:0] D_RELEASE_ACK = 3'd6;

  logic [2:0] a_opcode;
  logic [2:0] b_opcode;
  logic [2:0] c_opcode;
  logic [2:0] d_opcode;
  logic [2:0] size;
  logic [2:0] response_d_opcode;
  logic [2:0] response_c_opcode;
  logic a_has_data;
  logic b_has_data;
  logic c_has_data;
  logic d_has_data;
  logic a_response_matches;
  logic b_response_matches;
  logic c_response_matches;
  logic d_requires_ack;
  logic [7:0] a_beats_minus_one;
  logic [7:0] b_beats_minus_one;
  logic [7:0] c_beats_minus_one;
  logic [7:0] d_beats_minus_one;

  TLProtocolFixture dut (.*);

  initial begin
    a_opcode = A_PUT_FULL;
    b_opcode = B_PUT_FULL;
    c_opcode = C_RELEASE_DATA;
    d_opcode = D_GRANT_DATA;
    size = 3'd3;
    response_d_opcode = D_ACCESS_ACK;
    response_c_opcode = C_ACCESS_ACK;
    #1;
    assert (a_has_data && b_has_data && c_has_data && d_has_data);
    assert (a_response_matches && b_response_matches);
    assert (!c_response_matches);
    assert (d_requires_ack);
    assert (a_beats_minus_one == 8'd1);
    assert (b_beats_minus_one == 8'd1);
    assert (c_beats_minus_one == 8'd1);
    assert (d_beats_minus_one == 8'd1);

    a_opcode = A_GET;
    b_opcode = B_PROBE_BLOCK;
    c_opcode = C_RELEASE_DATA;
    d_opcode = D_ACCESS_ACK_DATA;
    size = 3'd4;
    response_d_opcode = D_RELEASE_ACK;
    response_c_opcode = C_PROBE_ACK_DATA;
    #1;
    assert (!a_has_data && !b_has_data && c_has_data && d_has_data);
    assert (!a_response_matches && b_response_matches && c_response_matches);
    assert (!d_requires_ack);
    assert (a_beats_minus_one == 8'd0);
    assert (b_beats_minus_one == 8'd0);
    assert (c_beats_minus_one == 8'd3);
    assert (d_beats_minus_one == 8'd3);

    response_d_opcode = D_ACCESS_ACK_DATA;
    #1;
    assert (a_response_matches);

    $display("TileLink protocol helper simulation passed");
    $finish;
  end
endmodule

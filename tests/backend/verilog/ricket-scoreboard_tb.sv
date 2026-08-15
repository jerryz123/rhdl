// Verifies set, clear, simultaneous update, and x0 behavior in Ricket's scoreboard.
module ricket_scoreboard_tb;
  logic clock = 1'b0;
  logic reset = 1'b1;
  logic set_valid;
  logic [4:0] set_address;
  logic clear_valid;
  logic [4:0] clear_address;
  logic [4:0] query_rs1;
  logic [4:0] query_rs2;
  logic [4:0] query_rd;
  logic rs1_busy;
  logic rs2_busy;
  logic rd_busy;

  RicketScoreboard dut (.*);
  always #5 clock = ~clock;

  initial begin
    set_valid = 1'b0;
    set_address = '0;
    clear_valid = 1'b0;
    clear_address = '0;
    query_rs1 = 5'd5;
    query_rs2 = 5'd0;
    query_rd = 5'd7;
    repeat (2) @(posedge clock);
    #1;
    reset = 1'b0;

    set_valid = 1'b1;
    set_address = 5'd5;
    #1;
    assert (rs1_busy) else $fatal(1, "commit set was not visible in its cycle");
    assert (!rs2_busy) else $fatal(1, "x0 became busy");
    @(posedge clock);
    #1;
    set_valid = 1'b0;
    assert (rs1_busy) else $fatal(1, "committed destination was not retained");

    clear_valid = 1'b1;
    clear_address = 5'd5;
    #1;
    assert (!rs1_busy) else $fatal(1, "completion clear was not visible in its cycle");
    @(posedge clock);
    #1;
    clear_valid = 1'b0;
    assert (!rs1_busy) else $fatal(1, "completed destination remained busy");

    set_valid = 1'b1;
    set_address = 5'd7;
    clear_valid = 1'b1;
    clear_address = 5'd7;
    #1;
    assert (!rd_busy) else $fatal(1, "one-cycle completion did not clear its commit");
    @(posedge clock);
    #1;
    set_valid = 1'b0;
    clear_valid = 1'b0;
    assert (!rd_busy) else $fatal(1, "same-cycle set and clear left a busy bit");

    $display("Ricket scoreboard passed");
    $finish;
  end
endmodule

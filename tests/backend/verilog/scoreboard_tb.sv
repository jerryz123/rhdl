// Verifies standard scoreboard set, clear, retention, entry-zero, and bypass behavior.
module scoreboard_tb;
  typedef struct packed { logic valid; logic [2:0] bits; } update_t;

  logic clock = 1'b0;
  logic reset = 1'b1;
  update_t set_in;
  update_t clear_in;
  logic [7:0] busy;

  Scoreboard dut (.*);
  always #5 clock = ~clock;

  initial begin
    set_in = '0;
    clear_in = '0;
    repeat (2) @(posedge clock);
    #1;
    reset = 1'b0;

    set_in.valid = 1'b1;
    set_in.bits = 3'd3;
    #1;
    assert (busy == 8'h08)
      else $fatal(1, "set was not visible in its cycle");
    @(posedge clock);
    #1;
    set_in.valid = 1'b0;
    assert (busy == 8'h08)
      else $fatal(1, "set entry was not retained");

    clear_in.valid = 1'b1;
    clear_in.bits = 3'd3;
    #1;
    assert (busy == 8'h00)
      else $fatal(1, "clear was not visible in its cycle");
    @(posedge clock);
    #1;
    clear_in.valid = 1'b0;
    assert (busy == 8'h00)
      else $fatal(1, "cleared entry remained busy");

    set_in.valid = 1'b1;
    set_in.bits = 3'd0;
    #1;
    assert (busy == 8'h01)
      else $fatal(1, "entry zero could not be set");
    @(posedge clock);
    #1;
    set_in.bits = 3'd5;
    clear_in.valid = 1'b1;
    clear_in.bits = 3'd5;
    assert (busy == 8'h01)
      else $fatal(1, "same-cycle clear did not win");
    @(posedge clock);
    #1;
    set_in.valid = 1'b0;
    clear_in.bits = 3'd0;
    #1;
    assert (busy == 8'h00)
      else $fatal(1, "entry zero clear was not visible");

    $display("standard scoreboard passed");
    $finish;
  end
endmodule

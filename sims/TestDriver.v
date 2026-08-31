// Clocks and resets a generated SoCHarness until FESVR reports target completion.
module TestDriver;
  reg clock;
  reg reset;
  wire [31:0] exit;

  SoCHarness dut (
    .clock(clock),
    .reset(reset),
    .exit(exit)
  );

  always #1 clock = ~clock;

  initial begin
    clock = 1'b0;
    reset = 1'b1;
    repeat (3) @(posedge clock);
    reset = 1'b0;

    repeat (1000000) begin
      @(posedge clock);
      if (exit != 0) begin
        if (exit == 1) begin
          $display("SoC harness simulation passed");
          $finish;
        end else begin
          $fatal(1, "SoC harness reported target failure: exit word %0d", exit);
        end
      end
    end

    $fatal(1, "SoC harness simulation timed out");
  end
endmodule

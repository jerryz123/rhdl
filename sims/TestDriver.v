// Clocks and resets a generated SoCHarness until its generic exit status completes.
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

    repeat (100000) begin
      @(posedge clock);
      if (exit != 0) begin
        if (exit == 1) begin
          $display("SoC harness simulation passed");
          $finish;
        end
        $display("SoC harness reported target failure: exit word %0d", exit);
        $stop;
      end
    end

    $display("SoC harness simulation timed out");
    $stop;
  end
endmodule

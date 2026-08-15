// Clocks the generated FESVR stub harness until HTIF reports completion.
module fesvr_stub_harness_tb;
  logic clock = 1'b0;
  logic reset = 1'b1;
  wire [31:0] exit;

  FesvrStubHarness dut (
    .clock(clock),
    .reset(reset),
    .exit(exit)
  );

  always #1 clock = ~clock;

  initial begin
    repeat (3) @(posedge clock);
    reset = 1'b0;

    repeat (100000) begin
      @(posedge clock);
      if (exit != 0) begin
        if (exit != 1)
          $fatal(1, "FESVR reported target failure: exit word %0d", exit);
        $display("FESVR stub harness passed");
        $finish;
      end
    end

    $fatal(1, "FESVR stub harness timed out");
  end
endmodule

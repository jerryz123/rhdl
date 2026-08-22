// Clocks the FESVR-backed SimpleSoC through load, handoff, and host exit.
module TestDriver;
  logic clock = 1'b0;
  logic reset = 1'b1;
  wire loaded;
  wire [31:0] entry;
  wire [31:0] exit;

  SimpleSoC dut (
    .clock(clock),
    .reset(reset),
    .loaded(loaded),
    .entry(entry),
    .exit(exit)
  );

  always #1 clock = ~clock;

  initial begin
    repeat (3) @(posedge clock);
    reset = 1'b0;

    repeat (100000) begin
      @(posedge clock);
      if (exit != 0) begin
        if (!loaded)
          $fatal(1, "FESVR exited before handing off the ELF entry point");
        if (entry != 32'h80000000)
          $fatal(1, "FESVR handed off unexpected entry point %08x", entry);
        if (exit != 1)
          $fatal(1, "FESVR reported target failure: exit word %0d", exit);
        $display("SimpleSoC coherent CHI smoke passed");
        $finish;
      end
    end

    $fatal(1, "SimpleSoC timed out");
  end
endmodule

// Simulates the CIRCT-exported synchronous-reset counter module.
module counter_tb;
    logic clk = 1'b0;
    logic reset = 1'b1;
    logic [7:0] count;

    Counter dut (
        .clk(clk),
        .reset(reset),
        .count(count)
    );

    always #5 clk = ~clk;

    initial begin
        repeat (2) @(posedge clk);
        #1;
        assert (count == 8'd0) else $fatal(1, "synchronous reset failed");

        reset = 1'b0;
        repeat (3) @(posedge clk);
        #1;
        assert (count == 8'd3) else $fatal(1, "counter increment failed");

        reset = 1'b1;
        @(posedge clk);
        #1;
        assert (count == 8'd0) else $fatal(1, "second synchronous reset failed");

        $display("counter simulation passed");
        $finish;
    end
endmodule

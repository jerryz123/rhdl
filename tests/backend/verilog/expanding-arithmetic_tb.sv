// Simulates carry preservation and full-width unsigned multiplication.
module expanding_arithmetic_tb;
    logic [7:0] a;
    logic [3:0] b;
    logic [8:0] sum;
    logic [11:0] product;

    ExpandingArithmetic dut (
        .a(a),
        .b(b),
        .sum(sum),
        .product(product)
    );

    task automatic check_results(
        input logic [7:0] next_a,
        input logic [3:0] next_b,
        input logic [8:0] expected_sum,
        input logic [11:0] expected_product
    );
        a = next_a;
        b = next_b;
        #1;
        assert (sum == expected_sum) else $fatal(1, "expanding addition failed");
        assert (product == expected_product) else $fatal(1, "expanding multiplication failed");
    endtask

    initial begin
        check_results(8'd0, 4'd0, 9'd0, 12'd0);
        check_results(8'd255, 4'd15, 9'd270, 12'd3825);
        check_results(8'd128, 4'd8, 9'd136, 12'd1024);

        $display("expanding arithmetic simulation passed");
        $finish;
    end
endmodule

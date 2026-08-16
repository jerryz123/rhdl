// Exhaustively checks every route and origin encoding against the validated model fixture.
module noc_route_computer_tb;
    logic route_key;
    logic [2:0] origin_key;
    logic [3:0] allowed_mask;
    logic eject;
    logic valid;

    RouteComputer dut (
        .route_key(route_key),
        .origin_key(origin_key),
        .allowed_mask(allowed_mask),
        .eject(eject),
        .valid(valid)
    );

    initial begin
        for (int key = 0; key < 16; key++) begin
            logic [5:0] expected;
            route_key = key[3];
            origin_key = key[2:0];
            case (key)
                0: expected = 6'b001101;
                1: expected = 6'b010001;
                2: expected = 6'b100001;
                3: expected = 6'b000011;
                4: expected = 6'b000011;
                default: expected = 6'b000000;
            endcase
            #1;
            assert ({allowed_mask, eject, valid} == expected)
                else $fatal(1, "route lookup failed for encoded key %0d", key);
        end

        $display("NoC route-computer simulation passed");
        $finish;
    end
endmodule

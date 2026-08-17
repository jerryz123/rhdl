// Exhaustively checks every local router lookup in the validated two-hop fixture.
module noc_route_computer_tb;
    logic source_route_key;
    logic source_origin_key;
    logic [1:0] source_allowed_mask;
    logic source_eject;
    logic source_valid;

    logic middle_route_key;
    logic middle_origin_key;
    logic [1:0] middle_allowed_mask;
    logic middle_eject;
    logic middle_valid;

    logic destination_route_key;
    logic destination_origin_key;
    logic destination_allowed_mask;
    logic destination_eject;
    logic destination_valid;

    RouteComputerFixture dut (
        .source_route_key(source_route_key),
        .source_origin_key(source_origin_key),
        .source_allowed_mask(source_allowed_mask),
        .source_eject(source_eject),
        .source_valid(source_valid),
        .middle_route_key(middle_route_key),
        .middle_origin_key(middle_origin_key),
        .middle_allowed_mask(middle_allowed_mask),
        .middle_eject(middle_eject),
        .middle_valid(middle_valid),
        .destination_route_key(destination_route_key),
        .destination_origin_key(destination_origin_key),
        .destination_allowed_mask(destination_allowed_mask),
        .destination_eject(destination_eject),
        .destination_valid(destination_valid)
    );

    initial begin
        for (int key = 0; key < 4; key++) begin
            logic [3:0] expected_source;
            logic [3:0] expected_middle;
            logic [2:0] expected_destination;

            source_route_key = key[1];
            source_origin_key = key[0];
            middle_route_key = key[1];
            middle_origin_key = key[0];
            destination_route_key = key[1];
            destination_origin_key = key[0];

            case (key)
                0: begin
                    expected_source = 4'b1101;
                    expected_middle = 4'b0101;
                    expected_destination = 3'b011;
                end
                1: begin
                    expected_source = 4'b0000;
                    expected_middle = 4'b1001;
                    expected_destination = 3'b011;
                end
                default: begin
                    expected_source = 4'b0000;
                    expected_middle = 4'b0000;
                    expected_destination = 3'b000;
                end
            endcase

            #1;
            assert ({source_allowed_mask, source_eject, source_valid} == expected_source)
                else $fatal(1, "source route lookup failed for encoded key %0d", key);
            assert ({middle_allowed_mask, middle_eject, middle_valid} == expected_middle)
                else $fatal(1, "middle route lookup failed for encoded key %0d", key);
            assert ({destination_allowed_mask, destination_eject, destination_valid} == expected_destination)
                else $fatal(1, "destination route lookup failed for encoded key %0d", key);
        end

        $display("NoC router-local route-computer simulation passed");
        $finish;
    end
endmodule

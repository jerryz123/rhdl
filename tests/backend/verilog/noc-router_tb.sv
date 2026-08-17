// Exercises one-beat router matching, buffering, ejection, and backpressure.
module noc_router_tb;
    logic clock;
    logic reset;
    logic [1:0][1:0] allocator_requests;
    logic [1:0][1:0] allocator_grants;

    struct packed {logic valid; RoutedBeat bits;} middle_ingress_0_in;
    struct packed {logic valid; RoutedBeat bits;} middle_ingress_1_in;
    struct packed {logic ready;} middle_egress_0_in;
    struct packed {logic ready;} middle_egress_1_in;
    struct packed {logic ready;} middle_ingress_0_out;
    struct packed {logic ready;} middle_ingress_1_out;
    struct packed {logic valid; RoutedBeat bits;} middle_egress_0_out;
    struct packed {logic valid; RoutedBeat bits;} middle_egress_1_out;

    struct packed {logic valid; RoutedBeat bits;} destination_ingress_0_in;
    struct packed {logic valid; RoutedBeat bits;} destination_ingress_1_in;
    struct packed {logic ready;} destination_egress_0_in;
    struct packed {logic ready;} destination_ingress_0_out;
    struct packed {logic ready;} destination_ingress_1_out;
    struct packed {logic valid; RoutedBeat bits;} destination_egress_0_out;

    OneBeatRouterFixture dut (
        .clock(clock),
        .reset(reset),
        .allocator_requests(allocator_requests),
        .allocator_grants(allocator_grants),
        .middle_ingress_0_in(middle_ingress_0_in),
        .middle_ingress_1_in(middle_ingress_1_in),
        .middle_egress_0_in(middle_egress_0_in),
        .middle_egress_1_in(middle_egress_1_in),
        .destination_ingress_0_in(destination_ingress_0_in),
        .destination_ingress_1_in(destination_ingress_1_in),
        .destination_egress_0_in(destination_egress_0_in),
        .middle_ingress_0_out(middle_ingress_0_out),
        .middle_ingress_1_out(middle_ingress_1_out),
        .middle_egress_0_out(middle_egress_0_out),
        .middle_egress_1_out(middle_egress_1_out),
        .destination_ingress_0_out(destination_ingress_0_out),
        .destination_ingress_1_out(destination_ingress_1_out),
        .destination_egress_0_out(destination_egress_0_out)
    );

    always #5 clock = ~clock;

    task automatic tick;
        @(posedge clock);
        #1;
    endtask

    initial begin
        int sent0;
        int sent1;
        int received;
        int cycles;
        logic [7:0] seen;
        logic [7:0] payload;
        logic [1:0] expected0;
        logic [1:0] expected1;

        clock = 0;
        reset = 1;
        allocator_requests = '0;
        middle_ingress_0_in = '0;
        middle_ingress_1_in = '0;
        middle_egress_0_in = '0;
        middle_egress_1_in = '0;
        destination_ingress_0_in = '0;
        destination_ingress_1_in = '0;
        destination_egress_0_in = '0;
        tick();
        tick();
        reset = 0;
        #1;

        // Exhaust every two-input, two-target request matrix.
        for (int request_image = 0; request_image < 16; request_image++) begin
            allocator_requests = request_image[3:0];
            #1;
            if (allocator_requests[0][0])
                expected0 = 2'b01;
            else if (allocator_requests[0][1])
                expected0 = 2'b10;
            else
                expected0 = 2'b00;
            if (allocator_requests[1][0] && !expected0[0])
                expected1 = 2'b01;
            else if (allocator_requests[1][1] && !expected0[1])
                expected1 = 2'b10;
            else
                expected1 = 2'b00;
            assert (allocator_grants[0] == expected0 &&
                    allocator_grants[1] == expected1)
                else $fatal(1, "allocator mismatch for request image %h",
                            request_image[3:0]);
            assert ((allocator_grants[0] & ~allocator_requests[0]) == 0 &&
                    (allocator_grants[1] & ~allocator_requests[1]) == 0)
                else $fatal(1, "allocator granted an unrequested target");
            assert ((allocator_grants[0] & allocator_grants[1]) == 0)
                else $fatal(1, "allocator granted one target twice");
        end

        assert (middle_ingress_0_out.ready && middle_ingress_1_out.ready)
            else $fatal(1, "middle router did not reset empty");
        assert (destination_ingress_0_out.ready && destination_ingress_1_out.ready)
            else $fatal(1, "destination router did not reset empty");

        // Two adaptive requests are matched to distinct output VCs.
        middle_ingress_0_in = '{valid: 1'b1,
                                bits: '{route_key: 1'b0, payload: 8'hA1}};
        middle_ingress_1_in = '{valid: 1'b1,
                                bits: '{route_key: 1'b0, payload: 8'hB2}};
        tick();
        middle_ingress_0_in.valid = 0;
        middle_ingress_1_in.valid = 0;
        #1;
        assert (middle_egress_0_out.valid && middle_egress_1_out.valid)
            else $fatal(1, "middle router failed to produce two distinct grants");
        assert (middle_egress_0_out.bits.payload == 8'hA1)
            else $fatal(1, "input zero did not take its lowest target");
        assert (middle_egress_1_out.bits.payload == 8'hB2)
            else $fatal(1, "input one was duplicated or blocked by target zero");

        // Independent backpressure drains output one while output zero holds.
        middle_egress_1_in.ready = 1;
        tick();
        assert (middle_egress_0_out.valid &&
                middle_egress_0_out.bits.payload == 8'hA1)
            else $fatal(1, "stalled output did not remain pending");
        assert (!middle_egress_1_out.valid && middle_ingress_1_out.ready)
            else $fatal(1, "accepted output was not released exactly once");
        middle_egress_0_in.ready = 1;
        tick();
        assert (!middle_egress_0_out.valid && middle_ingress_0_out.ready)
            else $fatal(1, "output zero did not release after transfer");
        middle_egress_0_in.ready = 0;
        middle_egress_1_in.ready = 0;

        // Two ejection requests serialize without duplication.
        destination_ingress_0_in = '{valid: 1'b1,
                                     bits: '{route_key: 1'b0, payload: 8'hC3}};
        destination_ingress_1_in = '{valid: 1'b1,
                                     bits: '{route_key: 1'b0, payload: 8'hD4}};
        tick();
        destination_ingress_0_in.valid = 0;
        destination_ingress_1_in.valid = 0;
        #1;
        assert (destination_egress_0_out.valid &&
                destination_egress_0_out.bits.payload == 8'hC3)
            else $fatal(1, "ejection did not grant the first input");
        destination_egress_0_in.ready = 1;
        tick();
        assert (destination_egress_0_out.valid &&
                destination_egress_0_out.bits.payload == 8'hD4)
            else $fatal(1, "ejection did not retain the contending input");
        tick();
        assert (!destination_egress_0_out.valid)
            else $fatal(1, "ejected beat was duplicated");

        // Deterministic randomized backpressure checks conservation across
        // another eight contending packets.
        sent0 = 0;
        sent1 = 0;
        received = 0;
        cycles = 0;
        seen = '0;
        while (received < 8 && cycles < 200) begin
            @(negedge clock);
            destination_egress_0_in.ready = ($urandom_range(0, 1) == 1);
            destination_ingress_0_in.valid = sent0 < 4;
            destination_ingress_0_in.bits.route_key = 0;
            destination_ingress_0_in.bits.payload = {5'b00010, sent0[1:0], 1'b0};
            destination_ingress_1_in.valid = sent1 < 4;
            destination_ingress_1_in.bits.route_key = 0;
            destination_ingress_1_in.bits.payload = {5'b00010, sent1[1:0], 1'b1};

            @(posedge clock);
            if (destination_egress_0_out.valid && destination_egress_0_in.ready) begin
                payload = destination_egress_0_out.bits.payload;
                assert (payload >= 8'h10 && payload <= 8'h17)
                    else $fatal(1, "router produced an unknown payload %h", payload);
                assert (!seen[payload[2:0]])
                    else $fatal(1, "router duplicated payload %h", payload);
                seen[payload[2:0]] = 1;
                received++;
            end
            if (destination_ingress_0_in.valid && destination_ingress_0_out.ready)
                sent0++;
            if (destination_ingress_1_in.valid && destination_ingress_1_out.ready)
                sent1++;
            cycles++;
        end
        #1;
        destination_ingress_0_in.valid = 0;
        destination_ingress_1_in.valid = 0;
        destination_egress_0_in.ready = 0;

        assert (received == 8 && seen == 8'hFF)
            else $fatal(1, "packet conservation failed: received=%0d seen=%h",
                        received, seen);
        assert (sent0 == 4 && sent1 == 4)
            else $fatal(1, "not every offered packet entered the router");

        $display("NoC one-beat router simulation passed");
        $finish;
    end
endmodule

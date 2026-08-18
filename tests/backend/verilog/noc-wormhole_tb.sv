// Exercises retained VC ownership, packet backpressure, and physical-link sharing.
module noc_wormhole_tb;
    logic clock;
    logic reset;
    struct packed {logic valid; WormholeBeat bits;} ingress_0_in;
    struct packed {logic valid; WormholeBeat bits;} ingress_1_in;
    struct packed {logic ready;} egress_0_in;
    struct packed {logic ready;} egress_1_in;
    struct packed {logic ready;} ingress_0_out;
    struct packed {logic ready;} ingress_1_out;
    struct packed {logic valid; WormholeBeat bits;} egress_0_out;
    struct packed {logic valid; WormholeBeat bits;} egress_1_out;
    logic first_head_seen;

    WormholeRouterFixture dut (
        .clock(clock),
        .reset(reset),
        .ingress_0_in(ingress_0_in),
        .ingress_1_in(ingress_1_in),
        .egress_0_in(egress_0_in),
        .egress_1_in(egress_1_in),
        .ingress_0_out(ingress_0_out),
        .ingress_1_out(ingress_1_out),
        .egress_0_out(egress_0_out),
        .egress_1_out(egress_1_out)
    );

    always #5 clock = ~clock;

    task automatic tick;
        @(posedge clock);
        #1;
    endtask

    task automatic send_input_0(
        input logic route_key,
        input logic head,
        input logic tail,
        input logic [7:0] payload
    );
        @(negedge clock);
        ingress_0_in = '{valid: 1'b1,
                         bits: '{route_key: route_key,
                                 head: head,
                                 tail: tail,
                                 payload: payload}};
        do @(posedge clock); while (!ingress_0_out.ready);
        #1;
        ingress_0_in.valid = 0;
    endtask

    task automatic send_input_1(input logic [7:0] payload);
        @(negedge clock);
        ingress_1_in = '{valid: 1'b1,
                         bits: '{route_key: 1'b0,
                                 head: 1'b1,
                                 tail: 1'b1,
                                 payload: payload}};
        do @(posedge clock); while (!ingress_1_out.ready);
        #1;
        ingress_1_in.valid = 0;
    endtask

    initial begin
        int output_0_count;
        int output_1_count;
        int cycles;

        clock = 0;
        reset = 1;
        ingress_0_in = '0;
        ingress_1_in = '0;
        egress_0_in = '{ready: 1'b1};
        egress_1_in = '{ready: 1'b1};
        first_head_seen = 0;
        output_0_count = 0;
        output_1_count = 0;
        cycles = 0;
        tick();
        tick();
        reset = 0;

        fork
            begin
                send_input_0(1'b0, 1'b1, 1'b0, 8'hA0);
                send_input_0(1'b1, 1'b0, 1'b0, 8'hA1);
                send_input_0(1'b1, 1'b0, 1'b1, 8'hA2);
            end
            begin
                send_input_1(8'hB0);
                send_input_1(8'hC0);
            end
            begin
                wait (first_head_seen);
                @(negedge clock);
                egress_0_in.ready = 0;
                repeat (4) @(negedge clock);
                egress_0_in.ready = 1;
            end
            begin
                while ((output_0_count < 3 || output_1_count < 2) && cycles < 100) begin
                    @(posedge clock);
                    assert (!(egress_0_out.valid && egress_0_in.ready &&
                              egress_1_out.valid && egress_1_in.ready))
                        else $fatal(1, "two VCs transferred on one physical-link cycle");
                    if (egress_0_out.valid && egress_0_in.ready) begin
                        case (output_0_count)
                            0: begin
                                assert (egress_0_out.bits.head && !egress_0_out.bits.tail &&
                                        egress_0_out.bits.payload == 8'hA0)
                                    else $fatal(1, "first packet head was misrouted");
                                first_head_seen = 1;
                            end
                            1: assert (!egress_0_out.bits.head && !egress_0_out.bits.tail &&
                                       egress_0_out.bits.route_key == 1'b1 &&
                                       egress_0_out.bits.payload == 8'hA1)
                                   else $fatal(1, "body did not retain its head route");
                            2: assert (!egress_0_out.bits.head && egress_0_out.bits.tail &&
                                       egress_0_out.bits.payload == 8'hA2)
                                   else $fatal(1, "tail did not retain its head route");
                            default: $fatal(1, "unexpected VC0 transfer");
                        endcase
                        output_0_count++;
                    end
                    if (egress_1_out.valid && egress_1_in.ready) begin
                        assert (egress_1_out.bits.head && egress_1_out.bits.tail)
                            else $fatal(1, "single-beat packet markers changed");
                        if (output_1_count == 0)
                            assert (egress_1_out.bits.payload == 8'hB0)
                                else $fatal(1, "first competing packet was reordered");
                        else if (output_1_count == 1)
                            assert (egress_1_out.bits.payload == 8'hC0 && output_0_count == 1)
                                else $fatal(1, "ready VC did not bypass a blocked VC");
                        else
                            $fatal(1, "unexpected VC1 transfer");
                        output_1_count++;
                    end
                    cycles++;
                end
            end
        join

        assert (output_0_count == 3 && output_1_count == 2)
            else $fatal(1, "wormhole packet conservation failed");
        $display("NoC wormhole router simulation passed");
        $finish;
    end
endmodule

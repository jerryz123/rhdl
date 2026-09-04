// Verifies the standalone FP pipeline's LSU bridge, hazards, backpressure, and F64 add path.
module rv5stage_fp_pipeline_tb;
  typedef struct packed {
    logic valid;
    RV5StageFpIssue bits;
  } issue_t;
  typedef struct packed {
    logic valid;
    RV5StageFpLoadReservation bits;
  } load_reserve_t;
  typedef struct packed {
    logic valid;
    RV5StageFpLoadCompletion bits;
  } load_completion_t;
  typedef struct packed {
    logic valid;
    RV5StageFpStoreRequest bits;
  } store_request_t;

  logic clock = 1'b0;
  logic reset = 1'b1;
  issue_t issue_in;
  struct packed {logic ready;} completion_in;
  load_reserve_t load_reserve_in;
  load_completion_t load_completion_in;
  store_request_t store_request_in;
  struct packed {logic ready;} store_response_in;
  struct packed {logic ready;} issue_out;
  struct packed {logic valid; RV5StageFpCompletion bits;} completion_out;
  struct packed {logic ready;} load_reserve_out;
  struct packed {logic ready;} store_request_out;
  struct packed {logic valid; RV5StageFpStoreResponse bits;} store_response_out;
  logic [31:0] busy;
  logic drained;

  RV5StageFpPipeline dut (.*);
  always #5 clock = ~clock;

  task automatic load_register(input logic [4:0] rd,
                               input logic [63:0] data);
    begin
      @(negedge clock);
      load_reserve_in.valid = 1'b1;
      load_reserve_in.bits.context_0 = {3'b0, rd};
      load_reserve_in.bits.precision = 1'b1;
      load_reserve_in.bits.rd = rd;
      do @(posedge clock); while (!load_reserve_out.ready);
      @(negedge clock);
      load_reserve_in.valid = 1'b0;
      load_completion_in.valid = 1'b1;
      load_completion_in.bits.context_0 = {3'b0, rd};
      load_completion_in.bits.precision = 1'b1;
      load_completion_in.bits.rd = rd;
      load_completion_in.bits.data = data;
      @(posedge clock);
      @(negedge clock);
      load_completion_in.valid = 1'b0;
    end
  endtask

  task automatic consume_completion;
    begin
      completion_in.ready = 1'b1;
      @(posedge clock);
      @(negedge clock);
      completion_in.ready = 1'b0;
    end
  endtask

  initial begin
    issue_in = '0;
    completion_in = '0;
    load_reserve_in = '0;
    load_completion_in = '0;
    store_request_in = '0;
    store_response_in = '0;
    repeat (2) @(posedge clock);
    #1;
    reset = 1'b0;

    load_register(5'd1, 64'h3ff0000000000000);
    load_register(5'd2, 64'h4000000000000000);
    assert (busy == 32'b0);

    // A reserved load destination blocks a dependent arithmetic request.
    @(negedge clock);
    load_reserve_in.valid = 1'b1;
    load_reserve_in.bits.context_0 = 8'h44;
    load_reserve_in.bits.precision = 1'b1;
    load_reserve_in.bits.rd = 5'd4;
    @(posedge clock);
    @(negedge clock);
    load_reserve_in.valid = 1'b0;
    issue_in.valid = 1'b1;
    issue_in.bits = '0;
    issue_in.bits.control.registers.uses_frs1 = 1'b1;
    issue_in.bits.control.registers.destination = 2'd2;
    issue_in.bits.control.execution.unit = 4'd2;
    issue_in.bits.control.execution.source_precision = 1'b1;
    issue_in.bits.control.execution.destination_precision = 1'b1;
    issue_in.bits.frs1 = 5'd4;
    issue_in.bits.frs2 = 5'd2;
    issue_in.bits.frd = 5'd5;
    #1;
    assert (!issue_out.ready);
    issue_in.valid = 1'b0;
    load_completion_in.valid = 1'b1;
    load_completion_in.bits.context_0 = 8'h44;
    load_completion_in.bits.precision = 1'b1;
    load_completion_in.bits.rd = 5'd4;
    load_completion_in.bits.data = 64'h4010000000000000;
    @(posedge clock);
    @(negedge clock);
    load_completion_in.valid = 1'b0;

    // Issue FADD.D f3, f1, f2 and hold its completion under backpressure.
    issue_in.valid = 1'b1;
    issue_in.bits = '0;
    issue_in.bits.context_0 = 8'ha5;
    issue_in.bits.control.registers.uses_frs1 = 1'b1;
    issue_in.bits.control.registers.uses_frs2 = 1'b1;
    issue_in.bits.control.registers.destination = 2'd2;
    issue_in.bits.control.execution.unit = 4'd2;
    issue_in.bits.control.execution.source_precision = 1'b1;
    issue_in.bits.control.execution.destination_precision = 1'b1;
    issue_in.bits.control.execution.uses_rounding_mode = 1'b1;
    issue_in.bits.frs1 = 5'd1;
    issue_in.bits.frs2 = 5'd2;
    issue_in.bits.frd = 5'd3;
    issue_in.bits.rounding_mode = 3'd0;
    do @(posedge clock); while (!issue_out.ready);
    @(negedge clock);
    issue_in.valid = 1'b0;
    wait (completion_out.valid);
    #1;
    assert (completion_out.bits.context_0 == 8'ha5);
    assert (completion_out.bits.destination == 2'd2);
    assert (completion_out.bits.rd == 5'd3);
    assert (completion_out.bits.fp_value == 64'h4008000000000000);
    assert (completion_out.bits.exception_flags == 5'b0);
    assert (completion_out.bits.exception_flags_valid);
    assert (busy[3]);
    repeat (2) @(posedge clock);
    #1;
    assert (completion_out.valid);
    assert (completion_out.bits.fp_value == 64'h4008000000000000);
    consume_completion();
    #1;
    assert (!busy[3]);

    // The variable-latency divide lane uses the same buffered completion path.
    issue_in.valid = 1'b1;
    issue_in.bits = '0;
    issue_in.bits.context_0 = 8'hd1;
    issue_in.bits.control.registers.uses_frs1 = 1'b1;
    issue_in.bits.control.registers.uses_frs2 = 1'b1;
    issue_in.bits.control.registers.destination = 2'd2;
    issue_in.bits.control.execution.unit = 4'd4;
    issue_in.bits.control.execution.source_precision = 1'b1;
    issue_in.bits.control.execution.destination_precision = 1'b1;
    issue_in.bits.control.execution.uses_rounding_mode = 1'b1;
    issue_in.bits.control.execution.divide_operation = 1'b0;
    issue_in.bits.frs1 = 5'd4;
    issue_in.bits.frs2 = 5'd2;
    issue_in.bits.frd = 5'd6;
    issue_in.bits.rounding_mode = 3'd0;
    do @(posedge clock); while (!issue_out.ready);
    @(negedge clock);
    issue_in.valid = 1'b0;
    wait (completion_out.valid);
    #1;
    assert (completion_out.bits.context_0 == 8'hd1);
    assert (completion_out.bits.fp_value == 64'h4000000000000000);
    assert (completion_out.bits.exception_flags == 5'b0);
    assert (busy[6]);
    consume_completion();
    #1;
    assert (!busy[6]);

    // The LSU store bridge observes the value written by the FP completion.
    store_request_in.valid = 1'b1;
    store_request_in.bits.context_0 = 8'h3c;
    store_request_in.bits.precision = 1'b1;
    store_request_in.bits.rs = 5'd3;
    do @(posedge clock); while (!store_request_out.ready);
    @(negedge clock);
    store_request_in.valid = 1'b0;
    wait (store_response_out.valid);
    #1;
    assert (store_response_out.bits.context_0 == 8'h3c);
    assert (store_response_out.bits.data == 64'h4008000000000000);
    store_response_in.ready = 1'b1;
    @(posedge clock);
    @(negedge clock);
    store_response_in.ready = 1'b0;
    #1;
    assert (drained);

    $display("RV5Stage FP pipeline passed");
    $finish;
  end
endmodule

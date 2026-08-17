// Verifies Ricket L1I hit throughput, refill correctness, and speculative flushes.
module ricket_icache_tb;
  typedef struct packed { logic [31:0] address; } core_req_bits_t;
  typedef struct packed { logic valid; core_req_bits_t bits; } core_req_t;
  typedef struct packed { logic ready; } ready_t;
  typedef struct packed { logic [31:0] instruction; } instruction_bits_t;
  typedef struct packed { logic valid; instruction_bits_t bits; } instruction_resp_t;
  typedef struct packed { logic flush; core_req_t request; ready_t response; } core_in_t;
  typedef struct packed { ready_t request; instruction_resp_t response; } core_out_t;

  typedef struct packed {
    logic [31:0] address;
    logic write;
    logic [63:0] data;
    logic [7:0] mask;
  } memory_req_bits_t;
  typedef struct packed { logic valid; memory_req_bits_t bits; } memory_req_t;
  typedef struct packed { logic [63:0] data; } memory_resp_bits_t;
  typedef struct packed { logic valid; memory_resp_bits_t bits; } memory_resp_t;
  typedef struct packed { ready_t request; memory_resp_t response; } memory_in_t;
  typedef struct packed { memory_req_t request; ready_t response; } memory_out_t;

  logic clock = 1'b0;
  logic reset = 1'b1;
  core_in_t core_in;
  core_out_t core_out;
  memory_in_t memory_in;
  memory_out_t memory_out;

  RicketL1ICache dut (.*);
  always #5 clock = ~clock;

  function automatic logic [63:0] backing_data(input logic [31:0] address);
    case (address)
      32'h00000000: backing_data = 64'h22222222_11111111;
      32'h00000008: backing_data = 64'h44444444_33333333;
      32'h00000010: backing_data = 64'h66666666_55555555;
      default:       backing_data = 64'h88888888_77777777;
    endcase
  endfunction

  always_ff @(posedge clock) begin
    if (reset) begin
      memory_in.response.valid <= 1'b0;
      memory_in.response.bits.data <= '0;
    end else begin
      if (memory_in.response.valid && memory_out.response.ready)
        memory_in.response.valid <= 1'b0;
      if (memory_out.request.valid && memory_in.request.ready) begin
        assert (!memory_out.request.bits.write)
          else $fatal(1, "instruction cache issued a write");
        memory_in.response.valid <= 1'b1;
        memory_in.response.bits.data <= backing_data(
          memory_out.request.bits.address
        );
      end
    end
  end

  task automatic send_request(input logic [31:0] address);
    core_in.request.bits.address = address;
    core_in.request.valid = 1'b1;
    do begin
      @(negedge clock);
    end while (!core_out.request.ready);
    @(posedge clock);
    #1;
    core_in.request.valid = 1'b0;
  endtask

  task automatic expect_response(input logic [31:0] instruction);
    while (!core_out.response.valid) begin
      @(posedge clock);
      #1;
    end
    assert (core_out.response.bits.instruction == instruction)
      else $fatal(1, "instruction %h, expected %h",
                  core_out.response.bits.instruction, instruction);
    @(posedge clock);
    #1;
  endtask

  initial begin
    core_in = '0;
    memory_in = '0;
    memory_in.request.ready = 1'b1;
    core_in.response.ready = 1'b1;
    repeat (2) @(posedge clock);
    #1;
    reset = 1'b0;

    send_request(32'h00000000);
    expect_response(32'h11111111);

    while (!core_out.request.ready) begin
      @(posedge clock);
      #1;
    end
    core_in.request.valid = 1'b1;
    core_in.request.bits.address = 32'h00000000;
    @(posedge clock);
    #1;
    assert (core_out.request.ready)
      else $fatal(1, "second hit request was not accepted consecutively");
    assert (core_out.response.valid &&
            core_out.response.bits.instruction == 32'h11111111)
      else $fatal(1, "first hit did not return after one lookup cycle");
    core_in.request.bits.address = 32'h00000004;
    @(posedge clock);
    #1;
    core_in.request.valid = 1'b0;
    assert (core_out.response.valid &&
            core_out.response.bits.instruction == 32'h22222222)
      else $fatal(1, "second consecutive hit did not return on time");

    // Flush drops both a buffered hit and the following lookup result.
    @(posedge clock);
    #1;
    core_in.response.ready = 1'b0;
    core_in.request.valid = 1'b1;
    core_in.request.bits.address = 32'h00000000;
    @(posedge clock);
    #1;
    core_in.request.bits.address = 32'h00000004;
    @(posedge clock);
    #1;
    core_in.request.valid = 1'b0;
    core_in.flush = 1'b1;
    assert (!core_out.request.ready)
      else $fatal(1, "instruction cache accepted a request during flush");
    @(posedge clock);
    #1;
    core_in.flush = 1'b0;
    core_in.response.ready = 1'b1;
    repeat (2) begin
      assert (!core_out.response.valid)
        else $fatal(1, "flushed hit response escaped the instruction cache");
      @(posedge clock);
      #1;
    end

    send_request(32'h00000000);
    expect_response(32'h11111111);

    // A wrong-path miss may finish refilling, but flush suppresses its core
    // response and permits a later request to hit the installed line.
    send_request(32'h00000020);
    while (!memory_out.request.valid) begin
      @(posedge clock);
      #1;
    end
    core_in.flush = 1'b1;
    assert (!core_out.request.ready)
      else $fatal(1, "instruction cache accepted a request during refill flush");
    @(posedge clock);
    #1;
    core_in.flush = 1'b0;
    while (!core_out.request.ready) begin
      assert (!core_out.response.valid)
        else $fatal(1, "flushed refill returned an instruction");
      @(posedge clock);
      #1;
    end
    assert (!core_out.response.valid)
      else $fatal(1, "flushed refill response remained buffered");
    send_request(32'h00000020);
    expect_response(32'h77777777);

    $display("Ricket instruction-cache hit pipeline passed");
    $finish;
  end
endmodule

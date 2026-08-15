// Verifies refill, consecutive load hits, and buffered store completion for Ricket L1D.
module ricket_dcache_tb;
  typedef struct packed {
    logic [31:0] address;
    logic write;
    logic [1:0] width;
    logic unsigned_load;
    logic [63:0] data;
    logic [4:0] tag;
  } core_req_bits_t;
  typedef struct packed { logic valid; core_req_bits_t bits; } core_req_t;
  typedef struct packed { logic ready; } ready_t;
  typedef struct packed { logic [63:0] data; logic [4:0] tag; } core_resp_bits_t;
  typedef struct packed { logic valid; core_resp_bits_t bits; } core_resp_t;
  typedef struct packed { core_req_t request; ready_t response; } core_in_t;
  typedef struct packed { ready_t request; core_resp_t response; } core_out_t;

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
  logic saw_store;

  RicketL1DCache dut (.*);
  always #5 clock = ~clock;

  function automatic logic [63:0] backing_data(input logic [31:0] address);
    backing_data = 64'h88776655_44332211 + {32'b0, address};
  endfunction

  always_ff @(posedge clock) begin
    if (reset) begin
      memory_in.response.valid <= 1'b0;
      memory_in.response.bits.data <= '0;
      saw_store <= 1'b0;
    end else begin
      if (memory_in.response.valid && memory_out.response.ready)
        memory_in.response.valid <= 1'b0;
      if (memory_out.request.valid && memory_in.request.ready) begin
        memory_in.response.valid <= 1'b1;
        memory_in.response.bits.data <= backing_data(
          memory_out.request.bits.address
        );
        if (memory_out.request.bits.write) begin
          saw_store <= 1'b1;
          assert (memory_out.request.bits.data == 64'hdeadbeef_cafef00d &&
                  memory_out.request.bits.mask == 8'hff)
            else $fatal(1, "store buffer changed data or mask");
        end
      end
    end
  end

  task automatic send_load(input logic [31:0] address, input logic [4:0] tag);
    core_in.request.bits = '{address: address,
                             write: 1'b0,
                             width: 2'd3,
                             unsigned_load: 1'b0,
                             data: '0,
                             tag: tag};
    core_in.request.valid = 1'b1;
    do begin
      @(negedge clock);
    end while (!core_out.request.ready);
    @(posedge clock);
    #1;
    core_in.request.valid = 1'b0;
  endtask

  task automatic expect_data(input logic [63:0] data, input logic [4:0] tag);
    while (!core_out.response.valid) begin
      @(posedge clock);
      #1;
    end
    assert (core_out.response.bits.data == data)
      else $fatal(1, "load %h, expected %h", core_out.response.bits.data, data);
    assert (core_out.response.bits.tag == tag)
      else $fatal(1, "response tag %0d, expected %0d", core_out.response.bits.tag, tag);
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

    send_load(32'h00000000, 5'd3);
    expect_data(64'h88776655_44332211, 5'd3);

    while (!core_out.request.ready) begin
      @(posedge clock);
      #1;
    end
    core_in.request.valid = 1'b1;
    core_in.request.bits = '{address: 32'h00000000,
                             write: 1'b0,
                             width: 2'd3,
                             unsigned_load: 1'b0,
                             data: '0,
                             tag: 5'd4};
    @(posedge clock);
    #1;
    assert (core_out.request.ready)
      else $fatal(1, "second load hit was not accepted consecutively");
    assert (core_out.response.valid &&
            core_out.response.bits.data == 64'h88776655_44332211 &&
            core_out.response.bits.tag == 5'd4)
      else $fatal(1, "first load hit did not return after one lookup cycle");
    @(posedge clock);
    #1;
    core_in.request.valid = 1'b0;
    assert (core_out.response.valid &&
            core_out.response.bits.data == 64'h88776655_44332211 &&
            core_out.response.bits.tag == 5'd4)
      else $fatal(1, "second consecutive load hit did not return on time");

    while (!core_out.request.ready) begin
      @(posedge clock);
      #1;
    end
    core_in.request.valid = 1'b1;
    core_in.request.bits = '{address: 32'h00000000,
                             write: 1'b1,
                             width: 2'd3,
                             unsigned_load: 1'b0,
                             data: 64'hdeadbeef_cafef00d,
                             tag: 5'd0};
    @(posedge clock);
    #1;
    core_in.request.valid = 1'b0;
    assert (core_out.response.valid)
      else $fatal(1, "store hit did not complete after one lookup cycle");
    while (!saw_store) begin
      @(posedge clock);
      #1;
    end

    $display("Ricket data-cache hit pipeline passed");
    $finish;
  end
endmodule

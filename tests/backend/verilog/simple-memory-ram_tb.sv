// Simulates SimpleMemoryRam writes, masks, reads, stalls, and address rejection.
module simple_memory_ram_tb;
  typedef struct packed {
    logic [31:0] address;
    logic        write;
    logic [31:0] data;
    logic [3:0]  mask;
  } request_bits_t;
  typedef struct packed {
    logic          valid;
    request_bits_t bits;
  } request_forward_t;
  typedef struct packed { logic ready; } request_reverse_t;
  typedef struct packed { logic [31:0] data; } response_bits_t;
  typedef struct packed { logic ready; } response_reverse_t;
  typedef struct packed {
    logic           valid;
    response_bits_t bits;
  } response_forward_t;
  typedef struct packed {
    request_forward_t request;
    response_reverse_t response;
  } port_in_t;
  typedef struct packed {
    request_reverse_t request;
    response_forward_t response;
  } port_out_t;

  logic clock = 1'b0;
  logic reset = 1'b1;
  port_in_t port_in;
  port_out_t port_out;

  SimpleMemoryRam dut (
    .clock(clock),
    .reset(reset),
    .port_in(port_in),
    .port_out(port_out)
  );

  always #5 clock = ~clock;

  task automatic issue_request(
    input logic [31:0] address,
    input logic write,
    input logic [31:0] data,
    input logic [3:0] mask
  );
    port_in.request.bits = '{address: address,
                             write: write,
                             data: data,
                             mask: mask};
    port_in.request.valid = 1'b1;
    #1;
    assert (port_out.request.ready)
      else $fatal(1, "valid request was not accepted from idle");
    @(posedge clock);
    #1;
    port_in.request.valid = 1'b0;
  endtask

  task automatic accept_response(
    input logic check_data,
    input logic [31:0] expected_data
  );
    while (!port_out.response.valid) begin
      @(posedge clock);
      #1;
    end
    if (check_data) begin
      assert (port_out.response.bits.data == expected_data)
        else $fatal(1, "read response %h, expected %h",
                    port_out.response.bits.data, expected_data);
    end
    port_in.response.ready = 1'b1;
    @(posedge clock);
    #1;
    port_in.response.ready = 1'b0;
  endtask

  initial begin
    port_in = '0;
    port_in.request.bits.address = 32'h80000000;
    @(posedge clock);
    #1;
    reset = 1'b0;

    // Two requests fill the configured outstanding window on consecutive
    // cycles, with the masked write ordered behind the full write.
    issue_request(32'h80000004, 1'b1, 32'hAABBCCDD, 4'b1111);
    issue_request(32'h80000004, 1'b1, 32'h11223344, 4'b0101);

    // A third request remains stable and blocked while the response window is
    // full. It transfers concurrently with the first response.
    port_in.request.bits = '{address: 32'h80000004,
                             write: 1'b0,
                             data: 32'h0,
                             mask: 4'b0000};
    port_in.request.valid = 1'b1;
    #1;
    assert (!port_out.request.ready)
      else $fatal(1, "request exceeded the outstanding response depth");
    while (!port_out.response.valid) begin
      @(posedge clock);
      #1;
      assert (!port_out.request.ready)
        else $fatal(1, "full request window reopened without a response");
    end
    assert (port_out.response.bits.data == 32'h0)
      else $fatal(1, "first write response data was not canonical zero");
    port_in.response.ready = 1'b1;
    #1;
    assert (port_out.request.ready)
      else $fatal(1, "request did not reuse a same-cycle response slot");
    @(posedge clock);
    #1;
    port_in.request.valid = 1'b0;
    port_in.response.ready = 1'b0;

    // The second write response must precede the later read response.
    assert (port_out.response.valid)
      else $fatal(1, "second ordered write response was not presented");
    assert (port_out.response.bits.data == 32'h0)
      else $fatal(1, "second write response data was not canonical zero");
    accept_response(1'b1, 32'h0);

    while (!port_out.response.valid) begin
      @(posedge clock);
      #1;
    end
    assert (port_out.response.bits.data == 32'hAA22CC44)
      else $fatal(1, "ordered read response %h, expected AA22CC44",
                  port_out.response.bits.data);
    repeat (2) begin
      @(posedge clock);
      #1;
      assert (port_out.response.valid &&
              port_out.response.bits.data == 32'hAA22CC44)
        else $fatal(1, "read response changed under backpressure");
    end
    accept_response(1'b1, 32'hAA22CC44);

    port_in.request.valid = 1'b1;
    port_in.request.bits.address = 32'h80000002;
    #1;
    assert (!port_out.request.ready)
      else $fatal(1, "misaligned request was accepted");
    port_in.request.bits.address = 32'h80000010;
    #1;
    assert (!port_out.request.ready)
      else $fatal(1, "out-of-region request was accepted");

    $display("simple memory RAM simulation passed");
    $finish;
  end
endmodule

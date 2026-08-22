// Verifies RicketCore ordered commit, scoreboard hazards, and FENCE.I refetch control.
module ricket_core_tb;
  typedef struct packed { logic valid; logic [63:0] bits; } start_in_t;
  typedef struct packed { logic ready; } ready_t;
  typedef struct packed { logic [63:0] address; } instruction_req_bits_t;
  typedef struct packed { logic valid; instruction_req_bits_t bits; } instruction_req_t;
  typedef struct packed { logic [31:0] instruction; } instruction_resp_bits_t;
  typedef struct packed { logic valid; instruction_resp_bits_t bits; } instruction_resp_t;
  typedef struct packed { ready_t request; instruction_resp_t response; } instruction_in_t;
  typedef struct packed {
    logic flush;
    logic invalidate_all;
    instruction_req_t request;
    ready_t response;
  } instruction_out_t;
  typedef struct packed {
    logic [63:0] address;
    logic [2:0] access;
    logic [3:0] atomic;
    logic [1:0] width;
    logic unsigned_0;
    logic [63:0] data;
    logic [4:0] tag;
  } data_req_bits_t;
  typedef struct packed { logic valid; data_req_bits_t bits; } data_req_t;
  typedef struct packed { logic [63:0] data; logic [4:0] tag; } data_resp_bits_t;
  typedef struct packed { logic valid; data_resp_bits_t bits; } data_resp_t;
  typedef struct packed { ready_t request; data_resp_t response; logic drained; } data_in_t;
  typedef struct packed { data_req_t request; } data_out_t;

  logic clock = 1'b0;
  logic reset = 1'b1;
  start_in_t start_in;
  instruction_in_t instruction_access_in;
  data_in_t data_access_in;
  ready_t start_out;
  instruction_out_t instruction_access_out;
  data_out_t data_access_out;
  logic fault;
  logic instruction_response_valid;
  logic [31:0] instruction_response_bits;
  logic data_response_valid;
  logic [63:0] data_response_bits;
  logic [4:0] data_response_tag;
  logic [1:0] load_requests;
  logic first_response_sent;
  logic [1:0] first_response_delay;
  logic second_response_sent;
  logic [2:0] second_response_delay;
  logic [1:0] stores_seen;
  logic saw_fetch_flush;
  logic saw_redirect;
  logic saw_fence_i_invalidate;
  logic saw_fence_i_refetch;
  localparam logic [2:0] MEMORY_LOAD = 3'd1;

  RicketCore dut (.*);
  always #5 clock = ~clock;

  function automatic logic [31:0] instruction_at(input logic [63:0] address);
    case (address)
      64'h00000001_00000000: instruction_at = 32'h00003283;  // ld x5, 0(x0)
      64'h00000001_00000004: instruction_at = 32'h00028533;  // add x10, x5, x0
      64'h00000001_00000008: instruction_at = 32'h01003403;  // ld x8, 16(x0)
      64'h00000001_0000000c: instruction_at = 32'h00100313; // addi x6, x0, 1
      64'h00000001_00000010: instruction_at = 32'h02031863; // bne x6, x0, +48
      64'h00000001_00000040: instruction_at = 32'h006503b3; // add x7, x10, x6
      64'h00000001_00000044: instruction_at = 32'h00900413; // addi x8, x0, 9
      64'h00000001_00000048: instruction_at = 32'h0000100f; // fence.i
      64'h00000001_0000004c: instruction_at = 32'h00703423; // sd x7, 8(x0)
      64'h00000001_00000050: instruction_at = 32'h00803823; // sd x8, 16(x0)
      default: instruction_at = 32'h00000013;
    endcase
  endfunction

  always_comb begin
    instruction_access_in.request.ready = !instruction_response_valid;
    instruction_access_in.response.valid = instruction_response_valid;
    instruction_access_in.response.bits.instruction = instruction_response_bits;
    data_access_in.request.ready = 1'b1;
    data_access_in.response.valid = data_response_valid;
    data_access_in.response.bits.data = data_response_bits;
    data_access_in.response.bits.tag = data_response_tag;
    data_access_in.drained = 1'b1;
  end

  always_ff @(posedge clock) begin
    if (reset) begin
      instruction_response_valid <= 1'b0;
      instruction_response_bits <= '0;
      data_response_valid <= 1'b0;
      data_response_bits <= '0;
      data_response_tag <= '0;
      load_requests <= '0;
      first_response_sent <= 1'b0;
      first_response_delay <= '0;
      second_response_sent <= 1'b0;
      second_response_delay <= '0;
      stores_seen <= '0;
      saw_fetch_flush <= 1'b0;
      saw_redirect <= 1'b0;
      saw_fence_i_invalidate <= 1'b0;
      saw_fence_i_refetch <= 1'b0;
    end else begin
      if (instruction_access_out.flush) begin
        instruction_response_valid <= 1'b0;
        saw_fetch_flush <= 1'b1;
        if (instruction_access_out.invalidate_all)
          saw_fence_i_invalidate <= 1'b1;
      end else begin
        if (instruction_response_valid && instruction_access_out.response.ready)
          instruction_response_valid <= 1'b0;
        if (instruction_access_out.request.valid && instruction_access_in.request.ready) begin
          instruction_response_valid <= 1'b1;
          instruction_response_bits <= instruction_at(instruction_access_out.request.bits.address);
          if (instruction_access_out.request.bits.address == 64'h00000001_00000040) begin
            assert (saw_fetch_flush)
              else $fatal(1, "branch target fetched without flushing wrong-path requests");
            assert (first_response_sent && !second_response_sent)
              else $fatal(1, "branch redirect did not pass only the deferred load");
            saw_redirect <= 1'b1;
          end
          if (instruction_access_out.request.bits.address == 64'h00000001_0000004c &&
              saw_fence_i_invalidate)
            saw_fence_i_refetch <= 1'b1;
        end
      end

      if (data_response_valid) begin
        data_response_valid <= 1'b0;
        if (data_response_tag == 5'd5) begin
          first_response_sent <= 1'b1;
          second_response_delay <= 3'd3;
        end else begin
          assert (data_response_tag == 5'd8)
            else $fatal(1, "unexpected completion tag");
          second_response_sent <= 1'b1;
        end
      end else if (!data_response_valid) begin
        if (load_requests != 0 && !first_response_sent) begin
          if (first_response_delay != 0)
            first_response_delay <= first_response_delay - 1'b1;
          else begin
            data_response_valid <= 1'b1;
            data_response_bits <= 64'd42;
            data_response_tag <= 5'd5;
          end
        end else if (saw_redirect && first_response_sent && !second_response_sent) begin
          if (second_response_delay != 0)
            second_response_delay <= second_response_delay - 1'b1;
          else begin
            data_response_valid <= 1'b1;
            data_response_bits <= 64'd100;
            data_response_tag <= 5'd8;
          end
        end
      end

      if (data_access_out.request.valid && data_access_in.request.ready) begin
        if (data_access_out.request.bits.access == MEMORY_LOAD) begin
          if (load_requests == 0)
            assert (data_access_out.request.bits.address == 64'd0 &&
                    data_access_out.request.bits.tag == 5'd5)
              else $fatal(1, "first load lost its address or destination tag");
          else
            assert (load_requests == 1 &&
                    data_access_out.request.bits.address == 64'd16 &&
                    data_access_out.request.bits.tag == 5'd8)
              else $fatal(1, "second load lost its address or destination tag");
          if (load_requests == 0)
            first_response_delay <= 2'd1;
          load_requests <= load_requests + 1'b1;
        end else begin
          assert (second_response_sent)
            else $fatal(1, "a younger store passed a RAW or WAW hazard");
          if (stores_seen == 0) begin
            assert (data_access_out.request.bits.address == 64'd8 &&
                    data_access_out.request.bits.data == 64'd43 &&
                    data_access_out.request.bits.tag == 5'd0)
              else $fatal(1, "RAW-dependent result was incorrect");
            stores_seen <= 1;
          end else begin
            assert (stores_seen == 1 &&
                    data_access_out.request.bits.address == 64'd16 &&
                    data_access_out.request.bits.data == 64'd9 &&
                    data_access_out.request.bits.tag == 5'd0)
              else $fatal(1, "WAW ordering was not preserved");
            assert (saw_fence_i_invalidate && saw_fence_i_refetch)
              else $fatal(1, "FENCE.I did not invalidate and refetch from pc + 4");
            $display("Ricket out-of-order load completion passed");
            $finish;
          end
        end
      end
      assert (!fault) else $fatal(1, "pipeline raised an unexpected fault");
    end
  end

  initial begin
    start_in.valid = 1'b0;
    start_in.bits = 64'h00000001_00000000;
    repeat (2) @(posedge clock);
    #1;
    reset = 1'b0;
    start_in.valid = 1'b1;
    do begin
      @(posedge clock);
      #1;
    end while (!start_out.ready);
    start_in.valid = 1'b0;
    repeat (200) @(posedge clock);
    $fatal(1, "core did not complete the scoreboard scenario");
  end
endmodule

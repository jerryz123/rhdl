// Verifies Ricket L1I refills, hits, and snoop invalidation over ready-valid RN-F.
module ricket_icache_tb;
  typedef struct packed { logic [63:0] address; } core_req_bits_t;
  typedef struct packed { logic valid; core_req_bits_t bits; } core_req_t;
  typedef struct packed { logic ready; } ready_t;
  typedef struct packed { logic [31:0] instruction; } instruction_bits_t;
  typedef struct packed { logic valid; instruction_bits_t bits; } instruction_resp_t;
  typedef struct packed { logic flush; logic invalidate_all; core_req_t request; ready_t response; } core_in_t;
  typedef struct packed { ready_t request; instruction_resp_t response; } core_out_t;

  typedef struct packed { logic valid; CHIReqFlit bits; } req_forward_t;
  typedef struct packed { logic valid; CHIRspFlit bits; } rsp_forward_t;
  typedef struct packed { logic valid; CHIDatFlit bits; } dat_forward_t;
  typedef struct packed { logic valid; CHISnpFlit bits; } snp_forward_t;
  typedef struct packed {
    ready_t requests;
    ready_t requester_responses;
    ready_t request_data;
    rsp_forward_t responses;
    dat_forward_t response_data;
    snp_forward_t snoops;
  } chi_in_t;
  typedef struct packed {
    req_forward_t requests;
    rsp_forward_t requester_responses;
    dat_forward_t request_data;
    ready_t responses;
    ready_t response_data;
    ready_t snoops;
  } chi_out_t;

  localparam logic [6:0] READ_SHARED = 7'h01;
  localparam logic [4:0] SNP_RESP = 5'h01;
  localparam logic [4:0] COMP_ACK = 5'h02;
  localparam logic [4:0] SNP_MAKE_INVALID = 5'h0a;
  localparam logic [3:0] COMP_DATA = 4'h4;
  localparam logic [6:0] HOME_ID = 7'd1;
  localparam logic [6:0] CACHE_ID = 7'd2;

  logic clock = 1'b0;
  logic reset = 1'b1;
  core_in_t core_in;
  core_out_t core_out;
  chi_in_t chi_in;
  chi_out_t chi_out;

  RicketL1ICache dut (.*);
  always #5 clock = ~clock;

  task automatic tick;
    begin
      @(posedge clock);
      #1;
    end
  endtask

  task automatic send_core_request(input logic [63:0] address);
    integer cycles;
    begin
      cycles = 0;
      while (!core_out.request.ready && cycles < 100) begin
        tick();
        cycles = cycles + 1;
      end
      assert (core_out.request.ready)
        else $fatal(1, "L1I did not accept a core request");
      core_in.request.bits.address = address;
      core_in.request.valid = 1'b1;
      tick();
      core_in.request.valid = 1'b0;
    end
  endtask

  task automatic accept_read_request(input logic [63:0] address);
    integer cycles;
    begin
      cycles = 0;
      while (!chi_out.requests.valid && cycles < 100) begin
        tick();
        cycles = cycles + 1;
      end
      assert (chi_out.requests.valid)
        else $fatal(1, "L1I did not issue ReadShared");
      assert (chi_out.requests.bits.opcode == READ_SHARED &&
              chi_out.requests.bits.src_id == CACHE_ID &&
              chi_out.requests.bits.tgt_id == HOME_ID &&
              chi_out.requests.bits.txn_id == 12'd0 &&
              chi_out.requests.bits.address == address[43:0] &&
              chi_out.requests.bits.size_or_num_req == 6'd5 &&
              chi_out.requests.bits.exp_comp_ack)
        else $fatal(1, "L1I emitted malformed ReadShared");
      tick();
    end
  endtask

  task automatic return_line(
    input logic [63:0] address,
    input logic [255:0] line
  );
    begin
      assert (chi_out.response_data.ready)
        else $fatal(1, "L1I did not accept response data");
      chi_in.response_data.bits = '0;
      chi_in.response_data.bits.data = line[255:128];
      chi_in.response_data.bits.byte_enable = 16'hffff;
      chi_in.response_data.bits.data_id = {address[5], 1'b1};
      chi_in.response_data.bits.resp = 3'b001;
      chi_in.response_data.bits.opcode = COMP_DATA;
      chi_in.response_data.bits.home_nid_or_pbha_or_mismatched_mecid = HOME_ID;
      chi_in.response_data.bits.dbid_or_mecid = 16'h0055;
      chi_in.response_data.bits.txn_id = 12'd0;
      chi_in.response_data.bits.src_id = HOME_ID;
      chi_in.response_data.bits.tgt_id = CACHE_ID;
      chi_in.response_data.valid = 1'b1;
      tick();
      chi_in.response_data.valid = 1'b0;
      chi_in.response_data.bits = '0;
      assert (chi_out.response_data.ready)
        else $fatal(1, "L1I did not accept response data");
      chi_in.response_data.bits.data = line[127:0];
      chi_in.response_data.bits.byte_enable = 16'hffff;
      chi_in.response_data.bits.data_id = {address[5], 1'b0};
      chi_in.response_data.bits.resp = 3'b001;
      chi_in.response_data.bits.opcode = COMP_DATA;
      chi_in.response_data.bits.home_nid_or_pbha_or_mismatched_mecid = HOME_ID;
      chi_in.response_data.bits.dbid_or_mecid = 16'h0055;
      chi_in.response_data.bits.txn_id = 12'd0;
      chi_in.response_data.bits.src_id = HOME_ID;
      chi_in.response_data.bits.tgt_id = CACHE_ID;
      chi_in.response_data.valid = 1'b1;
      tick();
      chi_in.response_data.valid = 1'b0;
      chi_in.response_data.bits = '0;
    end
  endtask

  task automatic accept_comp_ack;
    integer cycles;
    begin
      cycles = 0;
      while (!chi_out.requester_responses.valid && cycles < 100) begin
        tick();
        cycles = cycles + 1;
      end
      assert (chi_out.requester_responses.valid)
        else $fatal(1, "L1I did not issue CompAck");
      assert (chi_out.requester_responses.bits.opcode == COMP_ACK &&
              chi_out.requester_responses.bits.src_id == CACHE_ID &&
              chi_out.requester_responses.bits.tgt_id == HOME_ID &&
              chi_out.requester_responses.bits.txn_id == 12'h055)
        else $fatal(1, "L1I emitted malformed CompAck");
      tick();
    end
  endtask

  task automatic expect_instruction(input logic [31:0] instruction);
    integer cycles;
    begin
      cycles = 0;
      while (!core_out.response.valid && cycles < 100) begin
        tick();
        cycles = cycles + 1;
      end
      assert (core_out.response.valid &&
              core_out.response.bits.instruction == instruction)
        else $fatal(1, "instruction %h, expected %h",
                    core_out.response.bits.instruction, instruction);
      tick();
    end
  endtask

  task automatic invalidate_cache(input logic [63:0] address);
    integer cycles;
    begin
      assert (chi_out.snoops.ready)
        else $fatal(1, "L1I did not accept a snoop");
      chi_in.snoops.bits = '0;
      chi_in.snoops.bits.address = address[43:3];
      chi_in.snoops.bits.opcode = SNP_MAKE_INVALID;
      chi_in.snoops.bits.txn_id = 12'h077;
      chi_in.snoops.bits.src_id = HOME_ID;
      chi_in.snoops.valid = 1'b1;
      tick();
      chi_in.snoops.valid = 1'b0;
      chi_in.snoops.bits = '0;
      cycles = 0;
      while (!chi_out.requester_responses.valid && cycles < 100) begin
        tick();
        cycles = cycles + 1;
      end
      assert (chi_out.requester_responses.valid &&
              chi_out.requester_responses.bits.opcode == SNP_RESP &&
              chi_out.requester_responses.bits.txn_id == 12'h077 &&
              chi_out.requester_responses.bits.src_id == CACHE_ID &&
              chi_out.requester_responses.bits.tgt_id == HOME_ID &&
              chi_out.requester_responses.bits.resp == 3'd0)
        else $fatal(1, "L1I emitted malformed clean snoop response");
      tick();
    end
  endtask

  localparam logic [63:0] ADDRESS = 64'h00000001_00000000;
  localparam logic [63:0] SECOND_ADDRESS = 64'h00000001_00000040;
  localparam logic [255:0] LINE = {
    64'h88888888_77777777,
    64'h66666666_55555555,
    64'h44444444_33333333,
    64'h22222222_11111111
  };

  initial begin
    core_in = '0;
    chi_in = '0;
    core_in.response.ready = 1'b1;
    chi_in.requests.ready = 1'b1;
    chi_in.requester_responses.ready = 1'b1;
    chi_in.request_data.ready = 1'b1;
    repeat (2) tick();
    reset = 1'b0;

    send_core_request(ADDRESS);
    accept_read_request(ADDRESS);
    return_line(ADDRESS, LINE);
    accept_comp_ack();
    expect_instruction(32'h11111111);

    send_core_request(ADDRESS + 64'd4);
    expect_instruction(32'h22222222);

    invalidate_cache(ADDRESS);
    send_core_request(ADDRESS);
    accept_read_request(ADDRESS);
    return_line(ADDRESS, LINE);
    accept_comp_ack();
    expect_instruction(32'h11111111);

    // A speculative flush preserves residency, while architectural
    // invalidation forces the next request back through CHI.
    core_in.flush = 1'b1;
    tick();
    core_in.flush = 1'b0;
    send_core_request(ADDRESS + 64'd4);
    expect_instruction(32'h22222222);
    core_in.invalidate_all = 1'b1;
    tick();
    core_in.invalidate_all = 1'b0;
    send_core_request(ADDRESS);
    accept_read_request(ADDRESS);
    return_line(ADDRESS, LINE);
    accept_comp_ack();
    expect_instruction(32'h11111111);

    // An invalidated in-flight refill may drain, but cannot respond or install.
    send_core_request(SECOND_ADDRESS);
    accept_read_request(SECOND_ADDRESS);
    core_in.invalidate_all = 1'b1;
    tick();
    core_in.invalidate_all = 1'b0;
    return_line(SECOND_ADDRESS, LINE);
    accept_comp_ack();
    repeat (2) tick();
    assert (!core_out.response.valid)
      else $fatal(1, "invalidated refill returned an instruction");
    send_core_request(SECOND_ADDRESS);
    accept_read_request(SECOND_ADDRESS);
    return_line(SECOND_ADDRESS, LINE);
    accept_comp_ack();
    expect_instruction(32'h11111111);

    $display("Ricket instruction-cache ready-valid RN-F simulation passed");
    $finish;
  end
endmodule

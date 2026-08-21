// Verifies Ricket L1D coherent refills and writes over ready-valid RN-F.
module ricket_dcache_tb;
  typedef struct packed {
    logic [63:0] address;
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
  typedef struct packed { core_req_t request; } core_in_t;
  typedef struct packed { ready_t request; core_resp_t response; logic drained; } core_out_t;

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
  localparam logic [6:0] WRITE_UNIQUE_PTL = 7'h18;
  localparam logic [4:0] COMP_ACK = 5'h02;
  localparam logic [4:0] COMP = 5'h04;
  localparam logic [4:0] DBID_RESP = 5'h06;
  localparam logic [3:0] NON_COPY_BACK_WRITE_DATA = 4'h3;
  localparam logic [3:0] COMP_DATA = 4'h4;
  localparam logic [6:0] HOME_ID = 7'd1;
  localparam logic [6:0] CACHE_ID = 7'd3;

  logic clock = 1'b0;
  logic reset = 1'b1;
  core_in_t core_in;
  core_out_t core_out;
  chi_in_t chi_in;
  chi_out_t chi_out;
  logic tx_req_pending = 1'b0;
  logic tx_rsp_pending = 1'b0;
  logic tx_dat_pending = 1'b0;
  CHIReqFlit captured_req;
  CHIRspFlit captured_rsp;
  CHIDatFlit captured_dat;

  RicketL1DCache dut (.*);
  always #5 clock = ~clock;

  task automatic tick;
    begin
      if (!reset && chi_out.requests.valid) begin
        tx_req_pending = 1'b1;
        captured_req = chi_out.requests.bits;
      end
      if (!reset && chi_out.requester_responses.valid) begin
        tx_rsp_pending = 1'b1;
        captured_rsp = chi_out.requester_responses.bits;
      end
      if (!reset && chi_out.request_data.valid) begin
        tx_dat_pending = 1'b1;
        captured_dat = chi_out.request_data.bits;
      end
      @(posedge clock);
      #1;
    end
  endtask

  task automatic send_core_request(
    input logic [63:0] address,
    input logic write,
    input logic [63:0] data,
    input logic [4:0] tag
  );
    integer cycles;
    begin
      cycles = 0;
      while (!core_out.request.ready && cycles < 100) begin
        tick();
        cycles = cycles + 1;
      end
      assert (core_out.request.ready)
        else $fatal(1, "L1D did not accept a core request");
      core_in.request.bits = '{address: address,
                               write: write,
                               width: 2'd3,
                               unsigned_load: 1'b0,
                               data: data,
                               tag: tag};
      core_in.request.valid = 1'b1;
      tick();
      core_in.request.valid = 1'b0;
    end
  endtask

  task automatic accept_request(
    input logic [6:0] opcode,
    input logic [63:0] address,
    input logic [11:0] txn_id,
    input logic [5:0] size
  );
    integer cycles;
    begin
      cycles = 0;
      while (!tx_req_pending && cycles < 100) begin
        tick();
        cycles = cycles + 1;
      end
      assert (tx_req_pending)
        else $fatal(1, "L1D did not issue a CHI request");
      assert (captured_req.opcode == opcode &&
              captured_req.src_id == CACHE_ID &&
              captured_req.tgt_id == HOME_ID &&
              captured_req.txn_id == txn_id &&
              captured_req.address == address[43:0] &&
              captured_req.size_or_num_req == size)
        else $fatal(1, "L1D emitted malformed CHI request");
      tx_req_pending = 1'b0;
    end
  endtask

  task automatic return_line(
    input logic [63:0] address,
    input logic [255:0] line
  );
    begin
      assert (chi_out.response_data.ready)
        else $fatal(1, "L1D did not accept response data");
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
        else $fatal(1, "L1D did not accept response data");
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
      while (!tx_rsp_pending && cycles < 100) begin
        tick();
        cycles = cycles + 1;
      end
      assert (tx_rsp_pending &&
              captured_rsp.opcode == COMP_ACK &&
              captured_rsp.txn_id == 12'h055)
        else $fatal(1, "L1D emitted malformed CompAck");
      tx_rsp_pending = 1'b0;
    end
  endtask

  task automatic expect_core_response(input logic [63:0] data,
                                      input logic [4:0] tag);
    integer cycles;
    begin
      cycles = 0;
      while (!core_out.response.valid && cycles < 100) begin
        tick();
        cycles = cycles + 1;
      end
      assert (core_out.response.valid &&
              core_out.response.bits.data == data &&
              core_out.response.bits.tag == tag)
        else $fatal(1, "L1D core response data or tag mismatch");
      tick();
    end
  endtask

  task automatic send_dbid;
    begin
      assert (chi_out.responses.ready)
        else $fatal(1, "L1D did not accept DBIDResp");
      chi_in.responses.bits = '0;
      chi_in.responses.bits.dbid_or_group_id = 12'h055;
      chi_in.responses.bits.opcode = DBID_RESP;
      chi_in.responses.bits.txn_id = 12'd1;
      chi_in.responses.bits.src_id = HOME_ID;
      chi_in.responses.bits.tgt_id = CACHE_ID;
      chi_in.responses.valid = 1'b1;
      tick();
      chi_in.responses.valid = 1'b0;
      chi_in.responses.bits = '0;
    end
  endtask

  task automatic accept_write_data(input logic [63:0] data);
    integer cycles;
    begin
      cycles = 0;
      while (!tx_dat_pending && cycles < 100) begin
        tick();
        cycles = cycles + 1;
      end
      assert (tx_dat_pending)
        else $fatal(1, "L1D did not issue write data");
      assert (captured_dat.opcode == NON_COPY_BACK_WRITE_DATA &&
              captured_dat.src_id == CACHE_ID &&
              captured_dat.tgt_id == HOME_ID &&
              captured_dat.txn_id == 12'h055 &&
              captured_dat.data[63:0] == data &&
              captured_dat.data[127:64] == 64'd0 &&
              captured_dat.byte_enable == 16'h00ff)
        else $fatal(1, "L1D emitted malformed write data");
      tx_dat_pending = 1'b0;
    end
  endtask

  task automatic send_completion;
    begin
      assert (chi_out.responses.ready)
        else $fatal(1, "L1D did not accept Comp");
      chi_in.responses.bits = '0;
      chi_in.responses.bits.dbid_or_group_id = 12'h055;
      chi_in.responses.bits.opcode = COMP;
      chi_in.responses.bits.txn_id = 12'd1;
      chi_in.responses.bits.src_id = HOME_ID;
      chi_in.responses.bits.tgt_id = CACHE_ID;
      chi_in.responses.valid = 1'b1;
      tick();
      chi_in.responses.valid = 1'b0;
      chi_in.responses.bits = '0;
    end
  endtask

  localparam logic [63:0] ADDRESS = 64'h00000001_00000000;
  localparam logic [255:0] LINE = {
    64'hffeeddcc_bbaa9988,
    64'h77665544_33221100,
    64'h01234567_89abcdef,
    64'h88776655_44332211
  };
  localparam logic [63:0] STORE_DATA = 64'hdeadbeef_cafef00d;

  initial begin
    core_in = '0;
    chi_in = '0;
    chi_in.requests.ready = 1'b1;
    chi_in.requester_responses.ready = 1'b1;
    chi_in.request_data.ready = 1'b1;
    repeat (2) tick();
    reset = 1'b0;
    assert (core_out.drained)
      else $fatal(1, "data cache was not drained after reset");

    send_core_request(ADDRESS, 1'b0, 64'd0, 5'd3);
    assert (!core_out.drained)
      else $fatal(1, "data cache reported drained during a refill");
    accept_request(READ_SHARED, ADDRESS, 12'd0, 6'd5);
    return_line(ADDRESS, LINE);
    accept_comp_ack();
    expect_core_response(64'h88776655_44332211, 5'd3);

    send_core_request(ADDRESS, 1'b0, 64'd0, 5'd4);
    expect_core_response(64'h88776655_44332211, 5'd4);

    send_core_request(ADDRESS, 1'b1, STORE_DATA, 5'd0);
    expect_core_response(64'd0, 5'd0);
    assert (!core_out.drained)
      else $fatal(1, "data cache reported drained before store completion");
    accept_request(WRITE_UNIQUE_PTL, ADDRESS, 12'd1, 6'd3);
    send_dbid();
    accept_write_data(STORE_DATA);
    send_completion();
    tick();
    assert (core_out.drained)
      else $fatal(1, "data cache did not drain after store completion");

    send_core_request(ADDRESS, 1'b0, 64'd0, 5'd5);
    accept_request(READ_SHARED, ADDRESS, 12'd0, 6'd5);
    return_line(ADDRESS, LINE);
    accept_comp_ack();
    expect_core_response(64'h88776655_44332211, 5'd5);

    $display("Ricket data-cache ready-valid RN-F simulation passed");
    $finish;
  end
endmodule

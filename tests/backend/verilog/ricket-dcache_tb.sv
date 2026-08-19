// Verifies Ricket L1D coherent refills and write-through stores over native RN-F.
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
  typedef struct packed { ready_t request; core_resp_t response; } core_out_t;

  typedef struct packed { logic credit; } credit_t;
  typedef struct packed { logic valid; CHIReqFlit bits; } req_forward_t;
  typedef struct packed { logic valid; CHIRspFlit bits; } rsp_forward_t;
  typedef struct packed { logic valid; CHIDatFlit bits; } dat_forward_t;
  typedef struct packed { logic valid; CHISnpFlit bits; } snp_forward_t;
  typedef struct packed {
    credit_t tx_req;
    credit_t tx_rsp;
    credit_t tx_dat;
    logic tx_link_active_ack;
    logic rx_link_active_request;
    rsp_forward_t rx_rsp;
    dat_forward_t rx_dat;
    snp_forward_t rx_snp;
  } chi_in_t;
  typedef struct packed {
    logic tx_link_active_request;
    logic rx_link_active_ack;
    req_forward_t tx_req;
    rsp_forward_t tx_rsp;
    dat_forward_t tx_dat;
    credit_t rx_rsp;
    credit_t rx_dat;
    credit_t rx_snp;
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
  integer rx_rsp_credits = 0;
  integer rx_dat_credits = 0;
  integer rx_snp_credits = 0;
  logic tx_req_pending = 1'b0;
  logic tx_rsp_pending = 1'b0;
  logic tx_dat_pending = 1'b0;
  CHIReqFlit captured_req;
  CHIRspFlit captured_rsp;
  CHIDatFlit captured_dat;

  RicketL1DCache dut (.*);
  always #5 clock = ~clock;

  task automatic tick;
    logic rsp_credit;
    logic dat_credit;
    logic snp_credit;
    begin
      rsp_credit = chi_out.rx_rsp.credit;
      dat_credit = chi_out.rx_dat.credit;
      snp_credit = chi_out.rx_snp.credit;
      if (!reset && chi_out.tx_req.valid) begin
        tx_req_pending = 1'b1;
        captured_req = chi_out.tx_req.bits;
      end
      if (!reset && chi_out.tx_rsp.valid) begin
        tx_rsp_pending = 1'b1;
        captured_rsp = chi_out.tx_rsp.bits;
      end
      if (!reset && chi_out.tx_dat.valid) begin
        tx_dat_pending = 1'b1;
        captured_dat = chi_out.tx_dat.bits;
      end
      @(posedge clock);
      #1;
      if (!reset) begin
        if (rsp_credit)
          rx_rsp_credits = rx_rsp_credits + 1;
        if (dat_credit)
          rx_dat_credits = rx_dat_credits + 1;
        if (snp_credit)
          rx_snp_credits = rx_snp_credits + 1;
        if (chi_in.rx_rsp.valid)
          rx_rsp_credits = rx_rsp_credits - 1;
        if (chi_in.rx_dat.valid)
          rx_dat_credits = rx_dat_credits - 1;
        if (chi_in.rx_snp.valid)
          rx_snp_credits = rx_snp_credits - 1;
      end
    end
  endtask

  task automatic activate_link;
    integer cycles;
    begin
      chi_in.rx_link_active_request = 1'b1;
      cycles = 0;
      while (!chi_out.tx_link_active_request && cycles < 50) begin
        tick();
        cycles = cycles + 1;
      end
      assert (chi_out.tx_link_active_request)
        else $fatal(1, "L1D did not request CHI link activation");
      chi_in.tx_link_active_ack = 1'b1;
      cycles = 0;
      while (!chi_out.rx_link_active_ack && cycles < 50) begin
        tick();
        cycles = cycles + 1;
      end
      assert (chi_out.rx_link_active_ack)
        else $fatal(1, "L1D did not acknowledge CHI receive activation");
    end
  endtask

  task automatic grant_req_credit;
    begin
      chi_in.tx_req.credit = 1'b1;
      tick();
      chi_in.tx_req.credit = 1'b0;
    end
  endtask

  task automatic grant_rsp_credit;
    begin
      chi_in.tx_rsp.credit = 1'b1;
      tick();
      chi_in.tx_rsp.credit = 1'b0;
    end
  endtask

  task automatic grant_dat_credit;
    begin
      chi_in.tx_dat.credit = 1'b1;
      tick();
      chi_in.tx_dat.credit = 1'b0;
    end
  endtask

  task automatic wait_rsp_credit;
    integer cycles;
    begin
      cycles = 0;
      while (rx_rsp_credits == 0 && cycles < 50) begin
        tick();
        cycles = cycles + 1;
      end
      assert (rx_rsp_credits > 0)
        else $fatal(1, "L1D did not grant an RSP credit");
    end
  endtask

  task automatic wait_dat_credit;
    integer cycles;
    begin
      cycles = 0;
      while (rx_dat_credits == 0 && cycles < 50) begin
        tick();
        cycles = cycles + 1;
      end
      assert (rx_dat_credits > 0)
        else $fatal(1, "L1D did not grant a DAT credit");
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
      wait_dat_credit();
      chi_in.rx_dat.bits = '0;
      chi_in.rx_dat.bits.data = line[255:128];
      chi_in.rx_dat.bits.byte_enable = 16'hffff;
      chi_in.rx_dat.bits.data_id = {address[5], 1'b1};
      chi_in.rx_dat.bits.resp = 3'b001;
      chi_in.rx_dat.bits.opcode = COMP_DATA;
      chi_in.rx_dat.bits.home_nid_or_pbha_or_mismatched_mecid = HOME_ID;
      chi_in.rx_dat.bits.dbid_or_mecid = 16'h0055;
      chi_in.rx_dat.bits.txn_id = 12'd0;
      chi_in.rx_dat.bits.src_id = HOME_ID;
      chi_in.rx_dat.bits.tgt_id = CACHE_ID;
      chi_in.rx_dat.valid = 1'b1;
      tick();
      chi_in.rx_dat.valid = 1'b0;
      chi_in.rx_dat.bits = '0;
      wait_dat_credit();
      chi_in.rx_dat.bits = '0;
      chi_in.rx_dat.bits.data = line[127:0];
      chi_in.rx_dat.bits.byte_enable = 16'hffff;
      chi_in.rx_dat.bits.data_id = {address[5], 1'b0};
      chi_in.rx_dat.bits.resp = 3'b001;
      chi_in.rx_dat.bits.opcode = COMP_DATA;
      chi_in.rx_dat.bits.home_nid_or_pbha_or_mismatched_mecid = HOME_ID;
      chi_in.rx_dat.bits.dbid_or_mecid = 16'h0055;
      chi_in.rx_dat.bits.txn_id = 12'd0;
      chi_in.rx_dat.bits.src_id = HOME_ID;
      chi_in.rx_dat.bits.tgt_id = CACHE_ID;
      chi_in.rx_dat.valid = 1'b1;
      tick();
      chi_in.rx_dat.valid = 1'b0;
      chi_in.rx_dat.bits = '0;
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
      wait_rsp_credit();
      chi_in.rx_rsp.bits = '0;
      chi_in.rx_rsp.bits.dbid_or_group_id = 12'h055;
      chi_in.rx_rsp.bits.opcode = DBID_RESP;
      chi_in.rx_rsp.bits.txn_id = 12'd1;
      chi_in.rx_rsp.bits.src_id = HOME_ID;
      chi_in.rx_rsp.bits.tgt_id = CACHE_ID;
      chi_in.rx_rsp.valid = 1'b1;
      tick();
      chi_in.rx_rsp.valid = 1'b0;
      chi_in.rx_rsp.bits = '0;
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
      wait_rsp_credit();
      chi_in.rx_rsp.bits = '0;
      chi_in.rx_rsp.bits.dbid_or_group_id = 12'h055;
      chi_in.rx_rsp.bits.opcode = COMP;
      chi_in.rx_rsp.bits.txn_id = 12'd1;
      chi_in.rx_rsp.bits.src_id = HOME_ID;
      chi_in.rx_rsp.bits.tgt_id = CACHE_ID;
      chi_in.rx_rsp.valid = 1'b1;
      tick();
      chi_in.rx_rsp.valid = 1'b0;
      chi_in.rx_rsp.bits = '0;
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
    repeat (2) tick();
    reset = 1'b0;
    activate_link();
    grant_req_credit();
    grant_rsp_credit();

    send_core_request(ADDRESS, 1'b0, 64'd0, 5'd3);
    accept_request(READ_SHARED, ADDRESS, 12'd0, 6'd5);
    return_line(ADDRESS, LINE);
    accept_comp_ack();
    expect_core_response(64'h88776655_44332211, 5'd3);

    send_core_request(ADDRESS, 1'b0, 64'd0, 5'd4);
    expect_core_response(64'h88776655_44332211, 5'd4);

    grant_req_credit();
    grant_dat_credit();
    send_core_request(ADDRESS, 1'b1, STORE_DATA, 5'd0);
    expect_core_response(64'd0, 5'd0);
    accept_request(WRITE_UNIQUE_PTL, ADDRESS, 12'd1, 6'd3);
    send_dbid();
    accept_write_data(STORE_DATA);
    send_completion();

    grant_req_credit();
    grant_rsp_credit();
    send_core_request(ADDRESS, 1'b0, 64'd0, 5'd5);
    accept_request(READ_SHARED, ADDRESS, 12'd0, 6'd5);
    return_line(ADDRESS, LINE);
    accept_comp_ack();
    expect_core_response(64'h88776655_44332211, 5'd5);

    $display("Ricket data-cache native RN-F simulation passed");
    $finish;
  end
endmodule

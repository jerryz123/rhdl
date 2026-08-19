// Verifies Ricket L1I refills, hits, and clean snoop invalidation over native RN-F.
module ricket_icache_tb;
  typedef struct packed { logic [63:0] address; } core_req_bits_t;
  typedef struct packed { logic valid; core_req_bits_t bits; } core_req_t;
  typedef struct packed { logic ready; } ready_t;
  typedef struct packed { logic [31:0] instruction; } instruction_bits_t;
  typedef struct packed { logic valid; instruction_bits_t bits; } instruction_resp_t;
  typedef struct packed { logic flush; core_req_t request; ready_t response; } core_in_t;
  typedef struct packed { ready_t request; instruction_resp_t response; } core_out_t;

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
  integer rx_rsp_credits = 0;
  integer rx_dat_credits = 0;
  integer rx_snp_credits = 0;

  RicketL1ICache dut (.*);
  always #5 clock = ~clock;

  task automatic tick;
    logic rsp_credit;
    logic dat_credit;
    logic snp_credit;
    begin
      rsp_credit = chi_out.rx_rsp.credit;
      dat_credit = chi_out.rx_dat.credit;
      snp_credit = chi_out.rx_snp.credit;
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
        else $fatal(1, "L1I did not request CHI link activation");
      chi_in.tx_link_active_ack = 1'b1;
      cycles = 0;
      while (!chi_out.rx_link_active_ack && cycles < 50) begin
        tick();
        cycles = cycles + 1;
      end
      assert (chi_out.rx_link_active_ack)
        else $fatal(1, "L1I did not acknowledge CHI receive activation");
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

  task automatic wait_dat_credit;
    integer cycles;
    begin
      cycles = 0;
      while (rx_dat_credits == 0 && cycles < 50) begin
        tick();
        cycles = cycles + 1;
      end
      assert (rx_dat_credits > 0)
        else $fatal(1, "L1I did not grant a DAT credit");
    end
  endtask

  task automatic wait_snp_credit;
    integer cycles;
    begin
      cycles = 0;
      while (rx_snp_credits == 0 && cycles < 50) begin
        tick();
        cycles = cycles + 1;
      end
      assert (rx_snp_credits > 0)
        else $fatal(1, "L1I did not grant a SNP credit");
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
      while (!chi_out.tx_req.valid && cycles < 100) begin
        tick();
        cycles = cycles + 1;
      end
      assert (chi_out.tx_req.valid)
        else $fatal(1, "L1I did not issue ReadShared");
      assert (chi_out.tx_req.bits.opcode == READ_SHARED &&
              chi_out.tx_req.bits.src_id == CACHE_ID &&
              chi_out.tx_req.bits.tgt_id == HOME_ID &&
              chi_out.tx_req.bits.txn_id == 12'd0 &&
              chi_out.tx_req.bits.address == address[43:0] &&
              chi_out.tx_req.bits.size_or_num_req == 6'd5 &&
              chi_out.tx_req.bits.exp_comp_ack)
        else $fatal(1, "L1I emitted malformed ReadShared");
      tick();
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
      while (!chi_out.tx_rsp.valid && cycles < 100) begin
        tick();
        cycles = cycles + 1;
      end
      assert (chi_out.tx_rsp.valid)
        else $fatal(1, "L1I did not issue CompAck");
      assert (chi_out.tx_rsp.bits.opcode == COMP_ACK &&
              chi_out.tx_rsp.bits.src_id == CACHE_ID &&
              chi_out.tx_rsp.bits.tgt_id == HOME_ID &&
              chi_out.tx_rsp.bits.txn_id == 12'h055)
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
      wait_snp_credit();
      chi_in.rx_snp.bits = '0;
      chi_in.rx_snp.bits.address = address[43:3];
      chi_in.rx_snp.bits.opcode = SNP_MAKE_INVALID;
      chi_in.rx_snp.bits.txn_id = 12'h077;
      chi_in.rx_snp.bits.src_id = HOME_ID;
      chi_in.rx_snp.valid = 1'b1;
      tick();
      chi_in.rx_snp.valid = 1'b0;
      chi_in.rx_snp.bits = '0;
      cycles = 0;
      while (!chi_out.tx_rsp.valid && cycles < 100) begin
        tick();
        cycles = cycles + 1;
      end
      assert (chi_out.tx_rsp.valid &&
              chi_out.tx_rsp.bits.opcode == SNP_RESP &&
              chi_out.tx_rsp.bits.txn_id == 12'h077 &&
              chi_out.tx_rsp.bits.src_id == CACHE_ID &&
              chi_out.tx_rsp.bits.tgt_id == HOME_ID &&
              chi_out.tx_rsp.bits.resp == 3'd0)
        else $fatal(1, "L1I emitted malformed clean snoop response");
      tick();
    end
  endtask

  localparam logic [63:0] ADDRESS = 64'h00000001_00000000;
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
    repeat (2) tick();
    reset = 1'b0;
    activate_link();
    grant_req_credit();
    grant_rsp_credit();

    send_core_request(ADDRESS);
    accept_read_request(ADDRESS);
    return_line(ADDRESS, LINE);
    accept_comp_ack();
    expect_instruction(32'h11111111);

    send_core_request(ADDRESS + 64'd4);
    expect_instruction(32'h22222222);

    grant_rsp_credit();
    invalidate_cache(ADDRESS);
    grant_req_credit();
    grant_rsp_credit();
    send_core_request(ADDRESS);
    accept_read_request(ADDRESS);
    return_line(ADDRESS, LINE);
    accept_comp_ack();
    expect_instruction(32'h11111111);

    $display("Ricket instruction-cache native RN-F simulation passed");
    $finish;
  end
endmodule

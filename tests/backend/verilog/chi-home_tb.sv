// Simulates initial-profile HN-I read and write translation across both links.
module chi_home_tb;
  typedef struct packed { logic credit; } credit_t;
  typedef struct packed { logic valid; CHIReqFlit bits; } req_forward_t;
  typedef struct packed { logic valid; CHIRspFlit bits; } rsp_forward_t;
  typedef struct packed { logic valid; CHIDatFlit bits; } dat_forward_t;

  typedef struct packed {
    logic tx_link_active_request;
    logic rx_link_active_ack;
    req_forward_t tx_req;
    rsp_forward_t tx_rsp;
    dat_forward_t tx_dat;
    credit_t rx_rsp;
    credit_t rx_dat;
  } requester_to_home_t;
  typedef struct packed {
    credit_t tx_req;
    credit_t tx_rsp;
    credit_t tx_dat;
    logic tx_link_active_ack;
    logic rx_link_active_request;
    rsp_forward_t rx_rsp;
    dat_forward_t rx_dat;
  } home_to_requester_t;
  typedef struct packed {
    logic tx_link_active_request;
    logic rx_link_active_ack;
    rsp_forward_t tx_rsp;
    dat_forward_t tx_dat;
    credit_t rx_req;
    credit_t rx_dat;
  } subordinate_to_home_t;
  typedef struct packed {
    credit_t tx_rsp;
    credit_t tx_dat;
    logic tx_link_active_ack;
    logic rx_link_active_request;
    req_forward_t rx_req;
    dat_forward_t rx_dat;
  } home_to_subordinate_t;

  localparam logic [6:0] READ_NO_SNP = 7'h04;
  localparam logic [6:0] WRITE_NO_SNP_FULL = 7'h1d;
  localparam logic [4:0] COMP = 5'h04;
  localparam logic [4:0] DBID_RESP = 5'h06;
  localparam logic [3:0] NON_COPY_BACK_WRITE_DATA = 4'h3;
  localparam logic [3:0] COMP_DATA = 4'h4;
  localparam logic [6:0] REQUESTER_ID = 7'h03;
  localparam logic [6:0] HOME_ID = 7'h05;
  localparam logic [6:0] SUBORDINATE_ID = 7'h09;

  logic clock = 1'b0;
  logic reset = 1'b1;
  requester_to_home_t requester_in;
  subordinate_to_home_t subordinate_in;
  home_to_requester_t requester_out;
  home_to_subordinate_t subordinate_out;
  integer requester_req_credits = 0;
  integer requester_dat_credits = 0;
  integer subordinate_rsp_credits = 0;
  integer subordinate_dat_credits = 0;

  CHIHNI dut (.*);
  always #5 clock = ~clock;

  task automatic tick;
    logic requester_req_credit;
    logic requester_dat_credit;
    logic subordinate_rsp_credit;
    logic subordinate_dat_credit;
    begin
      requester_req_credit = requester_out.tx_req.credit;
      requester_dat_credit = requester_out.tx_dat.credit;
      subordinate_rsp_credit = subordinate_out.tx_rsp.credit;
      subordinate_dat_credit = subordinate_out.tx_dat.credit;
      @(posedge clock);
      #1;
      if (requester_req_credit)
        requester_req_credits = requester_req_credits + 1;
      if (requester_dat_credit)
        requester_dat_credits = requester_dat_credits + 1;
      if (subordinate_rsp_credit)
        subordinate_rsp_credits = subordinate_rsp_credits + 1;
      if (subordinate_dat_credit)
        subordinate_dat_credits = subordinate_dat_credits + 1;
    end
  endtask

  task automatic wait_requester_req_credit;
    integer cycles;
    begin
      cycles = 0;
      while (requester_req_credits == 0 && cycles < 50) begin
        tick();
        cycles = cycles + 1;
      end
      assert (requester_req_credits > 0)
        else $fatal(1, "HN-I did not grant a requester REQ credit");
    end
  endtask

  task automatic wait_requester_dat_credit;
    integer cycles;
    begin
      cycles = 0;
      while (requester_dat_credits == 0 && cycles < 50) begin
        tick();
        cycles = cycles + 1;
      end
      assert (requester_dat_credits > 0)
        else $fatal(1, "HN-I did not grant a requester DAT credit");
    end
  endtask

  task automatic wait_subordinate_rsp_credit;
    integer cycles;
    begin
      cycles = 0;
      while (subordinate_rsp_credits == 0 && cycles < 50) begin
        tick();
        cycles = cycles + 1;
      end
      assert (subordinate_rsp_credits > 0)
        else $fatal(1, "HN-I did not grant a subordinate RSP credit");
    end
  endtask

  task automatic wait_subordinate_dat_credit;
    integer cycles;
    begin
      cycles = 0;
      while (subordinate_dat_credits == 0 && cycles < 50) begin
        tick();
        cycles = cycles + 1;
      end
      assert (subordinate_dat_credits > 0)
        else $fatal(1, "HN-I did not grant a subordinate DAT credit");
    end
  endtask

  task automatic grant_downstream_credits;
    begin
      subordinate_in.rx_req.credit = 1'b1;
      subordinate_in.rx_dat.credit = 1'b1;
      tick();
      subordinate_in.rx_req.credit = 1'b0;
      subordinate_in.rx_dat.credit = 1'b0;
    end
  endtask

  task automatic grant_upstream_credits;
    begin
      requester_in.rx_rsp.credit = 1'b1;
      requester_in.rx_dat.credit = 1'b1;
      tick();
      requester_in.rx_rsp.credit = 1'b0;
      requester_in.rx_dat.credit = 1'b0;
    end
  endtask

  task automatic issue_request(
    input logic [6:0] opcode,
    input logic [11:0] txn_id,
    input logic [11:0] return_txn_id
  );
    begin
      wait_requester_req_credit();
      requester_req_credits = requester_req_credits - 1;
      requester_in.tx_req.bits = '0;
      requester_in.tx_req.bits.opcode = opcode;
      requester_in.tx_req.bits.src_id = REQUESTER_ID;
      requester_in.tx_req.bits.tgt_id = HOME_ID;
      requester_in.tx_req.bits.txn_id = txn_id;
      requester_in.tx_req.bits.address = 44'h080000000;
      requester_in.tx_req.bits.size_or_num_req = 6'd4;
      requester_in.tx_req.bits.return_nid_or_stash_nid_or_data_target = REQUESTER_ID;
      requester_in.tx_req.bits.return_txn_id_or_stash_lpid = return_txn_id;
      requester_in.tx_req.valid = 1'b1;
      tick();
      requester_in.tx_req.valid = 1'b0;
      requester_in.tx_req.bits = '0;
    end
  endtask

  task automatic accept_downstream_request(
    input logic [6:0] opcode,
    output logic [11:0] slot
  );
    integer cycles;
    begin
      cycles = 0;
      while (!subordinate_out.rx_req.valid && cycles < 50) begin
        tick();
        cycles = cycles + 1;
      end
      assert (subordinate_out.rx_req.valid)
        else $fatal(1, "timed out waiting for translated REQ");
      assert (subordinate_out.rx_req.bits.opcode == opcode &&
              subordinate_out.rx_req.bits.src_id == HOME_ID &&
              subordinate_out.rx_req.bits.tgt_id == SUBORDINATE_ID)
        else $fatal(1, "translated REQ carried incorrect routing metadata");
      assert (subordinate_out.rx_req.bits.return_nid_or_stash_nid_or_data_target == HOME_ID &&
              subordinate_out.rx_req.bits.return_txn_id_or_stash_lpid ==
                subordinate_out.rx_req.bits.txn_id)
        else $fatal(1, "translated REQ did not return through its HN-I slot");
      slot = subordinate_out.rx_req.bits.txn_id;
      tick();
    end
  endtask

  task automatic send_subordinate_data(
    input logic [11:0] slot,
    input logic [127:0] data
  );
    begin
      wait_subordinate_dat_credit();
      subordinate_dat_credits = subordinate_dat_credits - 1;
      subordinate_in.tx_dat.bits = '0;
      subordinate_in.tx_dat.bits.opcode = COMP_DATA;
      subordinate_in.tx_dat.bits.src_id = SUBORDINATE_ID;
      subordinate_in.tx_dat.bits.tgt_id = HOME_ID;
      subordinate_in.tx_dat.bits.txn_id = slot;
      subordinate_in.tx_dat.bits.byte_enable = 16'hffff;
      subordinate_in.tx_dat.bits.data = data;
      subordinate_in.tx_dat.valid = 1'b1;
      tick();
      subordinate_in.tx_dat.valid = 1'b0;
      subordinate_in.tx_dat.bits = '0;
    end
  endtask

  task automatic accept_upstream_data(
    input logic [11:0] return_txn_id,
    input logic [127:0] data
  );
    integer cycles;
    begin
      cycles = 0;
      while (!requester_out.rx_dat.valid && cycles < 50) begin
        tick();
        cycles = cycles + 1;
      end
      assert (requester_out.rx_dat.valid)
        else $fatal(1, "timed out waiting for translated CompData");
      assert (requester_out.rx_dat.bits.opcode == COMP_DATA &&
              requester_out.rx_dat.bits.src_id == HOME_ID &&
              requester_out.rx_dat.bits.tgt_id == REQUESTER_ID &&
              requester_out.rx_dat.bits.txn_id == return_txn_id)
        else $fatal(1, "translated CompData carried incorrect transaction metadata");
      assert (requester_out.rx_dat.bits.data == data)
        else $fatal(1, "translated CompData carried incorrect payload");
      tick();
    end
  endtask

  task automatic send_subordinate_response(
    input logic [4:0] opcode,
    input logic [11:0] slot,
    input logic [11:0] dbid
  );
    begin
      wait_subordinate_rsp_credit();
      subordinate_rsp_credits = subordinate_rsp_credits - 1;
      subordinate_in.tx_rsp.bits = '0;
      subordinate_in.tx_rsp.bits.opcode = opcode;
      subordinate_in.tx_rsp.bits.src_id = SUBORDINATE_ID;
      subordinate_in.tx_rsp.bits.tgt_id = HOME_ID;
      subordinate_in.tx_rsp.bits.txn_id = slot;
      subordinate_in.tx_rsp.bits.dbid_or_group_id = dbid;
      subordinate_in.tx_rsp.valid = 1'b1;
      tick();
      subordinate_in.tx_rsp.valid = 1'b0;
      subordinate_in.tx_rsp.bits = '0;
    end
  endtask

  task automatic accept_upstream_response(
    input logic [4:0] opcode,
    input logic [11:0] txn_id,
    output logic [11:0] home_dbid
  );
    integer cycles;
    begin
      cycles = 0;
      while (!requester_out.rx_rsp.valid && cycles < 50) begin
        tick();
        cycles = cycles + 1;
      end
      assert (requester_out.rx_rsp.valid)
        else $fatal(1, "timed out waiting for translated RSP");
      assert (requester_out.rx_rsp.bits.opcode == opcode &&
              requester_out.rx_rsp.bits.src_id == HOME_ID &&
              requester_out.rx_rsp.bits.tgt_id == REQUESTER_ID &&
              requester_out.rx_rsp.bits.txn_id == txn_id)
        else $fatal(1, "translated RSP carried incorrect transaction metadata");
      home_dbid = requester_out.rx_rsp.bits.dbid_or_group_id;
      tick();
    end
  endtask

  task automatic issue_write_data(
    input logic [11:0] home_dbid,
    input logic [127:0] data
  );
    begin
      wait_requester_dat_credit();
      requester_dat_credits = requester_dat_credits - 1;
      requester_in.tx_dat.bits = '0;
      requester_in.tx_dat.bits.opcode = NON_COPY_BACK_WRITE_DATA;
      requester_in.tx_dat.bits.src_id = REQUESTER_ID;
      requester_in.tx_dat.bits.tgt_id = HOME_ID;
      requester_in.tx_dat.bits.txn_id = home_dbid;
      requester_in.tx_dat.bits.byte_enable = 16'hffff;
      requester_in.tx_dat.bits.data = data;
      requester_in.tx_dat.valid = 1'b1;
      tick();
      requester_in.tx_dat.valid = 1'b0;
      requester_in.tx_dat.bits = '0;
    end
  endtask

  task automatic accept_downstream_write_data(
    input logic [11:0] subordinate_dbid,
    input logic [127:0] data
  );
    integer cycles;
    begin
      cycles = 0;
      while (!subordinate_out.rx_dat.valid && cycles < 50) begin
        tick();
        cycles = cycles + 1;
      end
      assert (subordinate_out.rx_dat.valid)
        else $fatal(1, "timed out waiting for translated write DAT");
      assert (subordinate_out.rx_dat.bits.opcode == NON_COPY_BACK_WRITE_DATA &&
              subordinate_out.rx_dat.bits.src_id == HOME_ID &&
              subordinate_out.rx_dat.bits.tgt_id == SUBORDINATE_ID &&
              subordinate_out.rx_dat.bits.txn_id == subordinate_dbid)
        else $fatal(1, "translated write DAT carried incorrect transaction metadata");
      assert (subordinate_out.rx_dat.bits.data == data)
        else $fatal(1, "translated write DAT carried incorrect payload");
      tick();
    end
  endtask

  logic [11:0] slot;
  logic [11:0] home_dbid;
  logic [11:0] ignored_dbid;
  localparam logic [11:0] SUBORDINATE_DBID = 12'h055;
  localparam logic [127:0] READ_DATA = 128'h00112233445566778899aabbccddeeff;
  localparam logic [127:0] WRITE_DATA = 128'hffeeddccbbaa99887766554433221100;

  initial begin
    requester_in = '0;
    subordinate_in = '0;
    tick();
    reset = 1'b0;

    requester_in.tx_link_active_request = 1'b1;
    subordinate_in.tx_link_active_request = 1'b1;
    while (!requester_out.tx_link_active_ack ||
           !subordinate_out.tx_link_active_ack)
      tick();
    while (!requester_out.rx_link_active_request ||
           !subordinate_out.rx_link_active_request)
      tick();
    requester_in.rx_link_active_ack = 1'b1;
    subordinate_in.rx_link_active_ack = 1'b1;
    tick();

    grant_downstream_credits();
    grant_upstream_credits();

    issue_request(READ_NO_SNP, 12'h101, 12'h501);
    accept_downstream_request(READ_NO_SNP, slot);
    send_subordinate_data(slot, READ_DATA);
    accept_upstream_data(12'h501, READ_DATA);

    grant_downstream_credits();
    grant_upstream_credits();
    issue_request(WRITE_NO_SNP_FULL, 12'h102, 12'h000);
    accept_downstream_request(WRITE_NO_SNP_FULL, slot);
    send_subordinate_response(DBID_RESP, slot, SUBORDINATE_DBID);
    accept_upstream_response(DBID_RESP, 12'h102, home_dbid);
    issue_write_data(home_dbid, WRITE_DATA);
    accept_downstream_write_data(SUBORDINATE_DBID, WRITE_DATA);
    send_subordinate_response(COMP, slot, SUBORDINATE_DBID);
    accept_upstream_response(COMP, 12'h102, ignored_dbid);
    assert (ignored_dbid == home_dbid)
      else $fatal(1, "completion did not preserve the HN-I DBID");

    $display("CHI HN-I simulation passed");
    $finish;
  end
endmodule

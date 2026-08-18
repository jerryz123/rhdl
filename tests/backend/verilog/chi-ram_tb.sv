// Simulates CHIRam activation, credits, reads, writes, masks, and concurrent DBIDs.
module chi_ram_tb;
  typedef struct packed { logic credit; } credit_t;
  typedef struct packed { logic valid; CHIReqFlit bits; } req_forward_t;
  typedef struct packed { logic valid; CHIRspFlit bits; } rsp_forward_t;
  typedef struct packed { logic valid; CHIDatFlit bits; } dat_forward_t;
  typedef struct packed {
    logic tx_link_active_request;
    logic rx_link_active_ack;
    rsp_forward_t tx_rsp;
    dat_forward_t tx_dat;
    credit_t rx_req;
    credit_t rx_dat;
  } node_to_icn_t;
  typedef struct packed {
    credit_t tx_rsp;
    credit_t tx_dat;
    logic tx_link_active_ack;
    logic rx_link_active_request;
    req_forward_t rx_req;
    dat_forward_t rx_dat;
  } icn_to_node_t;

  localparam logic [6:0] READ_NO_SNP = 7'h04;
  localparam logic [6:0] WRITE_NO_SNP_PTL = 7'h1c;
  localparam logic [6:0] WRITE_NO_SNP_FULL = 7'h1d;
  localparam logic [4:0] COMP = 5'h04;
  localparam logic [4:0] DBID_RESP = 5'h06;
  localparam logic [3:0] NON_COPY_BACK_WRITE_DATA = 4'h3;
  localparam logic [3:0] COMP_DATA = 4'h4;
  localparam logic [6:0] REQUESTER_ID = 7'h03;
  localparam logic [6:0] RAM_ID = 7'h09;

  logic clock = 1'b0;
  logic reset = 1'b1;
  icn_to_node_t port_in;
  node_to_icn_t port_out;
  integer req_credit_balance = 0;
  integer dat_credit_balance = 0;

  CHIRam dut (.*);
  always #5 clock = ~clock;

  task automatic tick;
    logic req_credit;
    logic dat_credit;
    begin
      req_credit = port_out.rx_req.credit;
      dat_credit = port_out.rx_dat.credit;
      @(posedge clock);
      #1;
      if (req_credit)
        req_credit_balance = req_credit_balance + 1;
      if (dat_credit)
        dat_credit_balance = dat_credit_balance + 1;
    end
  endtask

  task automatic wait_req_credit;
    integer cycles;
    begin
      cycles = 0;
      while (req_credit_balance == 0 && cycles < 50) begin
        tick();
        cycles = cycles + 1;
      end
      assert (req_credit_balance > 0)
        else $fatal(1, "CHIRam did not grant a REQ credit");
    end
  endtask

  task automatic wait_dat_credit;
    integer cycles;
    begin
      cycles = 0;
      while (dat_credit_balance == 0 && cycles < 50) begin
        tick();
        cycles = cycles + 1;
      end
      assert (dat_credit_balance > 0)
        else $fatal(1, "CHIRam did not grant a DAT credit");
    end
  endtask

  task automatic grant_rsp_credit;
    begin
      port_in.tx_rsp.credit = 1'b1;
      tick();
      port_in.tx_rsp.credit = 1'b0;
    end
  endtask

  task automatic grant_dat_credit;
    begin
      port_in.tx_dat.credit = 1'b1;
      tick();
      port_in.tx_dat.credit = 1'b0;
    end
  endtask

  task automatic issue_request(
    input logic [6:0] opcode,
    input logic [11:0] txn_id,
    input logic [43:0] address,
    input logic [11:0] return_txn_id
  );
    begin
      wait_req_credit();
      req_credit_balance = req_credit_balance - 1;
      port_in.rx_req.bits = '0;
      port_in.rx_req.bits.opcode = opcode;
      port_in.rx_req.bits.src_id = REQUESTER_ID;
      port_in.rx_req.bits.tgt_id = RAM_ID;
      port_in.rx_req.bits.txn_id = txn_id;
      port_in.rx_req.bits.address = address;
      port_in.rx_req.bits.size_or_num_req = 6'd4;
      port_in.rx_req.bits.return_nid_or_stash_nid_or_data_target = REQUESTER_ID;
      port_in.rx_req.bits.return_txn_id_or_stash_lpid = return_txn_id;
      port_in.rx_req.valid = 1'b1;
      tick();
      port_in.rx_req.valid = 1'b0;
      port_in.rx_req.bits = '0;
    end
  endtask

  task automatic issue_write_data(
    input logic [11:0] dbid,
    input logic [15:0] byte_enable,
    input logic [127:0] data
  );
    begin
      wait_dat_credit();
      dat_credit_balance = dat_credit_balance - 1;
      port_in.rx_dat.bits = '0;
      port_in.rx_dat.bits.opcode = NON_COPY_BACK_WRITE_DATA;
      port_in.rx_dat.bits.src_id = REQUESTER_ID;
      port_in.rx_dat.bits.tgt_id = RAM_ID;
      port_in.rx_dat.bits.txn_id = dbid;
      port_in.rx_dat.bits.byte_enable = byte_enable;
      port_in.rx_dat.bits.data = data;
      port_in.rx_dat.valid = 1'b1;
      tick();
      port_in.rx_dat.valid = 1'b0;
      port_in.rx_dat.bits = '0;
    end
  endtask

  task automatic wait_rsp;
    integer cycles;
    begin
      cycles = 0;
      while (!port_out.tx_rsp.valid && cycles < 100) begin
        tick();
        cycles = cycles + 1;
      end
      assert (port_out.tx_rsp.valid)
        else $fatal(1, "timed out waiting for CHIRam RSP");
    end
  endtask

  task automatic wait_dat;
    integer cycles;
    begin
      cycles = 0;
      while (!port_out.tx_dat.valid && cycles < 100) begin
        tick();
        cycles = cycles + 1;
      end
      assert (port_out.tx_dat.valid)
        else $fatal(1, "timed out waiting for CHIRam DAT");
    end
  endtask

  task automatic accept_dbid(
    input logic [11:0] request_txn_id,
    output logic [11:0] dbid
  );
    begin
      grant_rsp_credit();
      wait_rsp();
      assert (port_out.tx_rsp.bits.opcode == DBID_RESP)
        else $fatal(1, "write did not receive DBIDResp");
      assert (port_out.tx_rsp.bits.src_id == RAM_ID &&
              port_out.tx_rsp.bits.tgt_id == REQUESTER_ID &&
              port_out.tx_rsp.bits.txn_id == request_txn_id)
        else $fatal(1, "DBIDResp carried incorrect routing metadata");
      dbid = port_out.tx_rsp.bits.dbid_or_group_id;
      tick();
    end
  endtask

  task automatic accept_comp(
    input logic [11:0] request_txn_id,
    input logic [11:0] dbid
  );
    begin
      grant_rsp_credit();
      wait_rsp();
      assert (port_out.tx_rsp.bits.opcode == COMP)
        else $fatal(1, "write did not receive Comp");
      assert (port_out.tx_rsp.bits.src_id == RAM_ID &&
              port_out.tx_rsp.bits.tgt_id == REQUESTER_ID &&
              port_out.tx_rsp.bits.txn_id == request_txn_id &&
              port_out.tx_rsp.bits.dbid_or_group_id == dbid)
        else $fatal(1, "Comp carried incorrect transaction metadata");
      tick();
    end
  endtask

  task automatic accept_read(
    input logic [11:0] return_txn_id,
    input logic [15:0] byte_enable,
    input logic [127:0] data
  );
    begin
      grant_dat_credit();
      wait_dat();
      assert (port_out.tx_dat.bits.opcode == COMP_DATA)
        else $fatal(1, "read did not receive CompData");
      assert (port_out.tx_dat.bits.src_id == RAM_ID &&
              port_out.tx_dat.bits.tgt_id == REQUESTER_ID &&
              port_out.tx_dat.bits.txn_id == return_txn_id)
        else $fatal(1, "CompData carried incorrect routing metadata");
      assert (port_out.tx_dat.bits.byte_enable == byte_enable)
        else $fatal(1, "CompData carried incorrect byte enable");
      assert (port_out.tx_dat.bits.data == data)
        else $fatal(1, "CompData %h, expected %h",
                    port_out.tx_dat.bits.data, data);
      tick();
    end
  endtask

  logic [11:0] dbid_a;
  logic [11:0] dbid_b;

  initial begin
    port_in = '0;
    tick();
    assert (!port_out.tx_rsp.valid && !port_out.tx_dat.valid)
      else $fatal(1, "reset did not clear the CHIRam response paths");
    reset = 1'b0;

    port_in.rx_link_active_request = 1'b1;
    while (!port_out.tx_link_active_request)
      tick();
    port_in.tx_link_active_ack = 1'b1;
    while (!port_out.rx_link_active_ack)
      tick();
    wait_req_credit();
    wait_dat_credit();

    issue_request(READ_NO_SNP, 12'h101, 44'h080000000, 12'h501);
    accept_read(12'h501, 16'hffff, 128'b0);

    issue_request(WRITE_NO_SNP_FULL, 12'h102, 44'h080000000, 12'b0);
    accept_dbid(12'h102, dbid_a);
    issue_write_data(dbid_a, 16'hffff,
                     128'h00112233445566778899aabbccddeeff);
    accept_comp(12'h102, dbid_a);

    issue_request(WRITE_NO_SNP_PTL, 12'h103, 44'h080000000, 12'b0);
    accept_dbid(12'h103, dbid_a);
    issue_write_data(dbid_a, 16'h00ff,
                     128'hffeeddccbbaa99887766554433221100);
    accept_comp(12'h103, dbid_a);

    issue_request(READ_NO_SNP, 12'h104, 44'h080000000, 12'h504);
    accept_read(12'h504, 16'hffff,
                128'h00112233445566777766554433221100);

    // Fill both transaction slots before returning either DBID. This checks
    // that outstanding writes receive distinct live DBIDs under RSP starvation.
    issue_request(WRITE_NO_SNP_FULL, 12'h201, 44'h080000010, 12'b0);
    issue_request(WRITE_NO_SNP_FULL, 12'h202, 44'h080000020, 12'b0);
    accept_dbid(12'h201, dbid_a);
    accept_dbid(12'h202, dbid_b);
    assert (dbid_a != dbid_b)
      else $fatal(1, "concurrent CHIRam writes reused a live DBID");

    issue_write_data(dbid_a, 16'hffff,
                     128'h11111111222222223333333344444444);
    issue_write_data(dbid_b, 16'hffff,
                     128'haaaaaaaabbbbbbbbccccccccdddddddd);
    accept_comp(12'h201, dbid_a);
    accept_comp(12'h202, dbid_b);

    $display("CHI RAM simulation passed");
    $finish;
  end
endmodule

// Simulates initial-profile HN-I translation through CHIHNDecoupled.
module chi_home_tb;
  typedef struct packed { logic ready; } ready_t;
  typedef struct packed { logic valid; CHIReqFlit bits; } req_t;
  typedef struct packed { logic valid; CHIRspFlit bits; } rsp_t;
  typedef struct packed { logic valid; CHIDatFlit bits; } dat_t;
  typedef struct packed {
    req_t requests;
    rsp_t requester_responses;
    dat_t request_data;
    ready_t responses;
    ready_t response_data;
  } requester_in_t;
  typedef struct packed {
    ready_t requests;
    ready_t requester_responses;
    ready_t request_data;
    rsp_t responses;
    dat_t response_data;
  } requester_out_t;
  typedef struct packed {
    rsp_t responses;
    dat_t response_data;
    ready_t requests;
    ready_t request_data;
  } subordinate_in_t;
  typedef struct packed {
    ready_t responses;
    ready_t response_data;
    req_t requests;
    dat_t request_data;
  } subordinate_out_t;
  typedef struct packed {
    requester_in_t requester;
    subordinate_in_t subordinate;
  } hni_in_t;
  typedef struct packed {
    requester_out_t requester;
    subordinate_out_t subordinate;
  } hni_out_t;

  localparam logic [6:0] READ_NO_SNP = 7'h04;
  localparam logic [6:0] WRITE_NO_SNP_FULL = 7'h1d;
  localparam logic [4:0] COMP = 5'h04;
  localparam logic [4:0] DBID_RESP = 5'h06;
  localparam logic [3:0] NON_COPY_BACK_WRITE_DATA = 4'h3;
  localparam logic [3:0] COMP_DATA = 4'h4;
  localparam logic [6:0] REQUESTER_ID = 7'h03;
  localparam logic [6:0] HOME_ID = 7'h05;
  localparam logic [6:0] SUBORDINATE_ID = 7'h09;
  localparam logic [11:0] SUBORDINATE_DBID = 12'h055;
  localparam logic [127:0] READ_DATA = 128'h00112233445566778899aabbccddeeff;
  localparam logic [127:0] WRITE_DATA = 128'hffeeddccbbaa99887766554433221100;

  logic clock = 1'b0;
  logic reset = 1'b1;
  req_t upstream_requests_in;
  rsp_t upstream_requester_responses_in;
  dat_t upstream_request_data_in;
  ready_t upstream_responses_in;
  ready_t upstream_response_data_in;
  ready_t downstream_requests_in;
  ready_t downstream_request_data_in;
  rsp_t downstream_responses_in;
  dat_t downstream_response_data_in;
  ready_t upstream_requests_out;
  ready_t upstream_requester_responses_out;
  ready_t upstream_request_data_out;
  rsp_t upstream_responses_out;
  dat_t upstream_response_data_out;
  req_t downstream_requests_out;
  dat_t downstream_request_data_out;
  ready_t downstream_responses_out;
  ready_t downstream_response_data_out;
  hni_in_t port_in;
  hni_out_t port_out;

  assign port_in.requester.requests = upstream_requests_in;
  assign port_in.requester.requester_responses = upstream_requester_responses_in;
  assign port_in.requester.request_data = upstream_request_data_in;
  assign port_in.requester.responses = upstream_responses_in;
  assign port_in.requester.response_data = upstream_response_data_in;
  assign port_in.subordinate.requests = downstream_requests_in;
  assign port_in.subordinate.request_data = downstream_request_data_in;
  assign port_in.subordinate.responses = downstream_responses_in;
  assign port_in.subordinate.response_data = downstream_response_data_in;
  assign upstream_requests_out = port_out.requester.requests;
  assign upstream_requester_responses_out = port_out.requester.requester_responses;
  assign upstream_request_data_out = port_out.requester.request_data;
  assign upstream_responses_out = port_out.requester.responses;
  assign upstream_response_data_out = port_out.requester.response_data;
  assign downstream_requests_out = port_out.subordinate.requests;
  assign downstream_request_data_out = port_out.subordinate.request_data;
  assign downstream_responses_out = port_out.subordinate.responses;
  assign downstream_response_data_out = port_out.subordinate.response_data;

  CHIHNI dut (.*);
  always #5 clock = ~clock;

  task automatic tick;
    begin
      @(posedge clock);
      #1;
    end
  endtask

  task automatic translate_request(
    input logic [6:0] opcode,
    input logic [11:0] txn_id,
    input logic [11:0] return_txn_id,
    output logic [11:0] slot
  );
    begin
      upstream_requests_in.bits = '0;
      upstream_requests_in.bits.opcode = opcode;
      upstream_requests_in.bits.src_id = REQUESTER_ID;
      upstream_requests_in.bits.tgt_id = HOME_ID;
      upstream_requests_in.bits.txn_id = txn_id;
      upstream_requests_in.bits.address = 44'h080000000;
      upstream_requests_in.bits.size_or_num_req = 6'd4;
      upstream_requests_in.bits.return_nid_or_stash_nid_or_data_target = REQUESTER_ID;
      upstream_requests_in.bits.return_txn_id_or_stash_lpid = return_txn_id;
      upstream_requests_in.valid = 1'b1;
      downstream_requests_in.ready = 1'b0;
      #1;
      assert (downstream_requests_out.valid && !upstream_requests_out.ready)
        else $fatal(1, "request backpressure was not preserved");
      downstream_requests_in.ready = 1'b1;
      #1;
      assert (upstream_requests_out.ready)
        else $fatal(1, "HN-I did not accept the upstream request");
      assert (downstream_requests_out.bits.opcode == opcode &&
              downstream_requests_out.bits.src_id == HOME_ID &&
              downstream_requests_out.bits.tgt_id == SUBORDINATE_ID)
        else $fatal(1, "translated REQ carried incorrect routing metadata");
      assert (downstream_requests_out.bits.return_nid_or_stash_nid_or_data_target == HOME_ID &&
              downstream_requests_out.bits.return_txn_id_or_stash_lpid ==
                downstream_requests_out.bits.txn_id)
        else $fatal(1, "translated REQ did not return through its HN-I slot");
      slot = downstream_requests_out.bits.txn_id;
      tick();
      upstream_requests_in = '0;
      downstream_requests_in.ready = 1'b0;
    end
  endtask

  task automatic translate_subordinate_data(
    input logic [11:0] slot,
    input logic [11:0] return_txn_id,
    input logic [127:0] data
  );
    begin
      downstream_response_data_in.bits = '0;
      downstream_response_data_in.bits.opcode = COMP_DATA;
      downstream_response_data_in.bits.src_id = SUBORDINATE_ID;
      downstream_response_data_in.bits.tgt_id = HOME_ID;
      downstream_response_data_in.bits.txn_id = slot;
      downstream_response_data_in.bits.byte_enable = 16'hffff;
      downstream_response_data_in.bits.data = data;
      downstream_response_data_in.valid = 1'b1;
      upstream_response_data_in.ready = 1'b1;
      #1;
      assert (downstream_response_data_out.ready && upstream_response_data_out.valid)
        else $fatal(1, "HN-I did not forward subordinate read data");
      assert (upstream_response_data_out.bits.opcode == COMP_DATA &&
              upstream_response_data_out.bits.src_id == HOME_ID &&
              upstream_response_data_out.bits.tgt_id == REQUESTER_ID &&
              upstream_response_data_out.bits.txn_id == return_txn_id)
        else $fatal(1, "translated CompData carried incorrect transaction metadata");
      assert (upstream_response_data_out.bits.data == data)
        else $fatal(1, "translated CompData carried incorrect payload");
      tick();
      downstream_response_data_in = '0;
      upstream_response_data_in.ready = 1'b0;
    end
  endtask

  task automatic translate_subordinate_response(
    input logic [4:0] opcode,
    input logic [11:0] slot,
    input logic [11:0] dbid,
    input logic [11:0] requester_txn_id,
    output logic [11:0] home_dbid
  );
    begin
      downstream_responses_in.bits = '0;
      downstream_responses_in.bits.opcode = opcode;
      downstream_responses_in.bits.src_id = SUBORDINATE_ID;
      downstream_responses_in.bits.tgt_id = HOME_ID;
      downstream_responses_in.bits.txn_id = slot;
      downstream_responses_in.bits.dbid_or_group_id = dbid;
      downstream_responses_in.valid = 1'b1;
      upstream_responses_in.ready = 1'b1;
      #1;
      assert (downstream_responses_out.ready && upstream_responses_out.valid)
        else $fatal(1, "HN-I did not forward the subordinate response");
      assert (upstream_responses_out.bits.opcode == opcode &&
              upstream_responses_out.bits.src_id == HOME_ID &&
              upstream_responses_out.bits.tgt_id == REQUESTER_ID &&
              upstream_responses_out.bits.txn_id == requester_txn_id)
        else $fatal(1, "translated RSP carried incorrect transaction metadata");
      home_dbid = upstream_responses_out.bits.dbid_or_group_id;
      tick();
      downstream_responses_in = '0;
      upstream_responses_in.ready = 1'b0;
    end
  endtask

  task automatic translate_write_data(
    input logic [11:0] home_dbid,
    input logic [11:0] subordinate_dbid,
    input logic [127:0] data
  );
    begin
      upstream_request_data_in.bits = '0;
      upstream_request_data_in.bits.opcode = NON_COPY_BACK_WRITE_DATA;
      upstream_request_data_in.bits.src_id = REQUESTER_ID;
      upstream_request_data_in.bits.tgt_id = HOME_ID;
      upstream_request_data_in.bits.txn_id = home_dbid;
      upstream_request_data_in.bits.byte_enable = 16'hffff;
      upstream_request_data_in.bits.data = data;
      upstream_request_data_in.valid = 1'b1;
      downstream_request_data_in.ready = 1'b1;
      #1;
      assert (upstream_request_data_out.ready && downstream_request_data_out.valid)
        else $fatal(1, "HN-I did not forward requester write data");
      assert (downstream_request_data_out.bits.opcode == NON_COPY_BACK_WRITE_DATA &&
              downstream_request_data_out.bits.src_id == HOME_ID &&
              downstream_request_data_out.bits.tgt_id == SUBORDINATE_ID &&
              downstream_request_data_out.bits.txn_id == subordinate_dbid)
        else $fatal(1, "translated write DAT carried incorrect transaction metadata");
      assert (downstream_request_data_out.bits.data == data)
        else $fatal(1, "translated write DAT carried incorrect payload");
      tick();
      upstream_request_data_in = '0;
      downstream_request_data_in.ready = 1'b0;
    end
  endtask

  logic [11:0] slot;
  logic [11:0] home_dbid;
  logic [11:0] completion_dbid;

  initial begin
    upstream_requests_in = '0;
    upstream_requester_responses_in = '0;
    upstream_request_data_in = '0;
    upstream_responses_in = '0;
    upstream_response_data_in = '0;
    downstream_requests_in = '0;
    downstream_request_data_in = '0;
    downstream_responses_in = '0;
    downstream_response_data_in = '0;
    tick();
    reset = 1'b0;

    translate_request(READ_NO_SNP, 12'h101, 12'h501, slot);
    translate_subordinate_data(slot, 12'h501, READ_DATA);

    translate_request(WRITE_NO_SNP_FULL, 12'h102, 12'h000, slot);
    translate_subordinate_response(DBID_RESP,
                                   slot,
                                   SUBORDINATE_DBID,
                                   12'h102,
                                   home_dbid);
    translate_write_data(home_dbid, SUBORDINATE_DBID, WRITE_DATA);
    translate_subordinate_response(COMP,
                                   slot,
                                   SUBORDINATE_DBID,
                                   12'h102,
                                   completion_dbid);
    assert (completion_dbid == home_dbid)
      else $fatal(1, "completion did not preserve the HN-I DBID");

    $display("CHI HN-I decoupled simulation passed");
    $finish;
  end
endmodule

// Drives an out-of-range request into CHIRam to prove its address assertion.
module chi_ram_invalid_tb;
  typedef struct packed { logic ready; } ready_t;
  typedef struct packed { logic valid; CHIReqFlit bits; } req_forward_t;
  typedef struct packed { logic valid; CHIRspFlit bits; } rsp_forward_t;
  typedef struct packed { logic valid; CHIDatFlit bits; } dat_forward_t;
  typedef struct packed {
    ready_t responses;
    ready_t response_data;
    req_forward_t requests;
    dat_forward_t request_data;
  } sn_in_t;
  typedef struct packed {
    rsp_forward_t responses;
    dat_forward_t response_data;
    ready_t requests;
    ready_t request_data;
  } sn_out_t;

  logic clock = 1'b0;
  logic reset = 1'b1;
  req_forward_t requests_in;
  ready_t requests_out;
  dat_forward_t request_data_in;
  ready_t request_data_out;
  ready_t responses_in;
  rsp_forward_t responses_out;
  ready_t response_data_in;
  dat_forward_t response_data_out;
  sn_in_t port_in;
  sn_out_t port_out;

  assign port_in.responses = responses_in;
  assign port_in.response_data = response_data_in;
  assign port_in.requests = requests_in;
  assign port_in.request_data = request_data_in;
  assign responses_out = port_out.responses;
  assign response_data_out = port_out.response_data;
  assign requests_out = port_out.requests;
  assign request_data_out = port_out.request_data;

  CHIRam dut (.*);
  always #5 clock = ~clock;

  task automatic tick;
    begin
      @(posedge clock);
      #1;
    end
  endtask

  initial begin
    requests_in = '0;
    request_data_in = '0;
    responses_in = '0;
    response_data_in = '0;
    tick();
    reset = 1'b0;

    requests_in.bits = '0;
    requests_in.bits.opcode = 7'h04;
    requests_in.bits.src_id = 7'h03;
    requests_in.bits.tgt_id = 7'h09;
    requests_in.bits.txn_id = 12'h301;
    requests_in.bits.address = 44'h080000040;
    requests_in.bits.size_or_num_req = 6'd4;
    requests_in.bits.return_nid_or_stash_nid_or_data_target = 7'h03;
    requests_in.bits.return_txn_id_or_stash_lpid = 12'h701;
    requests_in.valid = 1'b1;
    while (!requests_out.ready)
      tick();
    tick();

    $fatal(1, "out-of-range CHIRam request did not assert");
  end
endmodule

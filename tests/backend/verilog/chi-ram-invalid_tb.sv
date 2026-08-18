// Drives an out-of-range CHI request to prove CHIRam's generated address assertion.
module chi_ram_invalid_tb;
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

  logic clock = 1'b0;
  logic reset = 1'b1;
  icn_to_node_t port_in;
  node_to_icn_t port_out;

  CHIRam dut (.*);
  always #5 clock = ~clock;

  task automatic tick;
    begin
      @(posedge clock);
      #1;
    end
  endtask

  initial begin
    port_in = '0;
    tick();
    reset = 1'b0;
    port_in.rx_link_active_request = 1'b1;
    while (!port_out.tx_link_active_request)
      tick();
    port_in.tx_link_active_ack = 1'b1;
    while (!port_out.rx_link_active_ack)
      tick();

    // A credit visible after an edge is usable only from the following edge.
    while (!port_out.rx_req.credit)
      tick();
    tick();
    port_in.rx_req.bits = '0;
    port_in.rx_req.bits.opcode = 7'h04;
    port_in.rx_req.bits.src_id = 7'h03;
    port_in.rx_req.bits.tgt_id = 7'h09;
    port_in.rx_req.bits.txn_id = 12'h301;
    port_in.rx_req.bits.address = 44'h080000040;
    port_in.rx_req.bits.size_or_num_req = 6'd4;
    port_in.rx_req.bits.return_nid_or_stash_nid_or_data_target = 7'h03;
    port_in.rx_req.bits.return_txn_id_or_stash_lpid = 12'h701;
    port_in.rx_req.valid = 1'b1;
    tick();

    $fatal(1, "out-of-range CHIRam request did not assert");
  end
endmodule

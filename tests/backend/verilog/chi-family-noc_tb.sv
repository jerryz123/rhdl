// Sends one CHI request across three stamped routers using family-remapped ports.
module chi_family_noc_tb;
  typedef struct packed { logic ready; } ready_t;
  typedef struct packed { logic valid; CHIReqFlit bits; } request_t;

  logic clock = 1'b0;
  logic reset = 1'b1;
  request_t request_in_in;
  ready_t request_out_in;
  ready_t request_in_out;
  request_t request_out_out;

  CHIFamilyNoCFixture dut (.*);
  always #5 clock = ~clock;

  task automatic tick;
    begin
      @(posedge clock);
      #1;
    end
  endtask

  initial begin
    integer cycles;
    request_in_in = '0;
    request_out_in.ready = 1'b1;
    tick();
    tick();
    reset = 1'b0;

    request_in_in.bits.tgt_id = 7'd5;
    request_in_in.bits.src_id = 7'd3;
    request_in_in.bits.txn_id = 12'h456;
    request_in_in.bits.opcode = 7'h01;
    request_in_in.bits.address = 44'h1234_5678;
    request_in_in.valid = 1'b1;
    for (cycles = 0; cycles < 8 && !request_in_out.ready; cycles = cycles + 1)
      tick();
    assert (request_in_out.ready)
      else $fatal(1, "family NoC did not accept the CHI request");
    tick();
    request_in_in.valid = 1'b0;

    for (cycles = 0; cycles < 16 && !request_out_out.valid; cycles = cycles + 1)
      tick();
    assert (request_out_out.valid)
      else $fatal(1, "CHI request did not cross the family-remapped path");
    assert (request_out_out.bits.tgt_id == 7'd5 &&
            request_out_out.bits.src_id == 7'd3 &&
            request_out_out.bits.txn_id == 12'h456 &&
            request_out_out.bits.opcode == 7'h01 &&
            request_out_out.bits.address == 44'h1234_5678)
      else $fatal(1, "CHI request payload changed across the family NoC");

    $display("CHI family NoC simulation passed");
    $finish;
  end
endmodule

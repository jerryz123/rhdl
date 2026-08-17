// Simulates AMBA CHI flit pass-through and protocol classification.
module chi_foundation_tb;
  logic [136:0] req;
  logic [70:0] rsp;
  logic [93:0] snp;
  logic [239:0] dat;
  logic [6:0] req_opcode;
  logic [4:0] rsp_opcode;
  logic [4:0] snp_opcode;
  logic [3:0] dat_opcode;
  logic [2:0] size;
  logic [1:0] data_id;
  logic [136:0] req_out;
  logic [70:0] rsp_out;
  logic [93:0] snp_out;
  logic [239:0] dat_out;
  logic req_opcode_valid;
  logic rsp_opcode_valid;
  logic snp_opcode_valid;
  logic dat_opcode_valid;
  logic req_atomic;
  logic req_read_no_snp;
  logic req_write_no_snp;
  logic rsp_allocates_dbid;
  logic dat_write_data;
  logic dat_response_data;
  logic size_valid;
  logic [1:0] data_beats_minus_one;
  logic data_id_valid;

  CHIFoundationFixture dut (.*);

  initial begin
    req = 137'h123456789abcdef;
    rsp = 71'h123456789ab;
    snp = 94'h123456789abcdef;
    dat = 240'h123456789abcdef;
    req_opcode = 7'h04;
    rsp_opcode = 5'h05;
    snp_opcode = 5'h17;
    dat_opcode = 4'h03;
    size = 3'h6;
    data_id = 2'h3;
    #1;

    assert (req_out == req && rsp_out == rsp && snp_out == snp && dat_out == dat)
      else $fatal(1, "flit pass-through changed packed CHI bits");
    assert (req_opcode_valid && rsp_opcode_valid && snp_opcode_valid && dat_opcode_valid)
      else $fatal(1, "a defined CHI opcode was rejected");
    assert (req_read_no_snp && !req_write_no_snp && !req_atomic)
      else $fatal(1, "ReadNoSnp classification failed");
    assert (rsp_allocates_dbid && dat_write_data && !dat_response_data)
      else $fatal(1, "response or data classification failed");
    assert (size_valid && data_beats_minus_one == 2'h3 && data_id_valid)
      else $fatal(1, "128-bit DAT packetization failed");

    req_opcode = 7'h06;
    rsp_opcode = 5'h0f;
    snp_opcode = 5'h0e;
    dat_opcode = 4'h08;
    size = 3'h7;
    #1;
    assert (!req_opcode_valid && !rsp_opcode_valid && !snp_opcode_valid && !dat_opcode_valid)
      else $fatal(1, "a reserved CHI opcode was accepted");
    assert (!size_valid)
      else $fatal(1, "reserved Size encoding was accepted");

    req_opcode = 7'h28;
    rsp_opcode = 5'h04;
    dat_opcode = 4'h04;
    size = 3'h5;
    #1;
    assert (req_atomic && !rsp_allocates_dbid)
      else $fatal(1, "atomic or response classification failed");
    assert (!dat_write_data && dat_response_data && data_beats_minus_one == 2'h1)
      else $fatal(1, "response-data or 32-byte packetization failed");

    $display("CHI foundation simulation passed");
    $finish;
  end
endmodule

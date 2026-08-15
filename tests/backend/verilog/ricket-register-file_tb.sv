// Verifies simultaneous writes, write-first reads, retention, and x0 behavior.
module ricket_register_file_tb;
  logic clock = 1'b0;
  logic reset = 1'b1;
  logic [4:0] read_address_1;
  logic [4:0] read_address_2;
  logic write_enable_1;
  logic [4:0] write_address_1;
  logic [63:0] write_data_1;
  logic write_enable_2;
  logic [4:0] write_address_2;
  logic [63:0] write_data_2;
  logic [63:0] read_data_1;
  logic [63:0] read_data_2;

  RicketRegisterFile dut (.*);
  always #5 clock = ~clock;

  initial begin
    read_address_1 = 5'd5;
    read_address_2 = 5'd6;
    write_enable_1 = 1'b0;
    write_address_1 = '0;
    write_data_1 = '0;
    write_enable_2 = 1'b0;
    write_address_2 = '0;
    write_data_2 = '0;
    repeat (2) @(posedge clock);
    #1;
    reset = 1'b0;

    write_enable_1 = 1'b1;
    write_address_1 = 5'd5;
    write_data_1 = 64'd11;
    write_enable_2 = 1'b1;
    write_address_2 = 5'd6;
    write_data_2 = 64'd22;
    #1;
    assert (read_data_1 == 64'd11 && read_data_2 == 64'd22)
      else $fatal(1, "simultaneous writes were not write-first");
    @(posedge clock);
    #1;
    write_enable_1 = 1'b0;
    write_enable_2 = 1'b0;
    assert (read_data_1 == 64'd11 && read_data_2 == 64'd22)
      else $fatal(1, "simultaneous writes were not retained");

    read_address_1 = 5'd9;
    read_address_2 = 5'd9;
    write_enable_1 = 1'b1;
    write_address_1 = 5'd9;
    write_data_1 = 64'd44;
    write_enable_2 = 1'b1;
    write_address_2 = 5'd9;
    write_data_2 = 64'd55;
    #1;
    assert (read_data_1 == 64'd55 && read_data_2 == 64'd55)
      else $fatal(1, "younger load port did not win a same-address write");
    @(posedge clock);
    #1;
    write_enable_1 = 1'b0;
    write_enable_2 = 1'b0;
    assert (read_data_1 == 64'd55 && read_data_2 == 64'd55)
      else $fatal(1, "same-address write priority was not retained");

    read_address_1 = 5'd0;
    read_address_2 = 5'd7;
    write_enable_1 = 1'b1;
    write_address_1 = 5'd0;
    write_data_1 = 64'hffffffffffffffff;
    write_enable_2 = 1'b1;
    write_address_2 = 5'd7;
    write_data_2 = 64'd33;
    #1;
    assert (read_data_1 == 64'd0 && read_data_2 == 64'd33)
      else $fatal(1, "x0 or second-port bypass behavior was incorrect");
    @(posedge clock);
    #1;
    write_enable_1 = 1'b0;
    write_enable_2 = 1'b0;
    assert (read_data_1 == 64'd0 && read_data_2 == 64'd33)
      else $fatal(1, "x0 or second-port retention behavior was incorrect");

    $display("Ricket two-write register file passed");
    $finish;
  end
endmodule

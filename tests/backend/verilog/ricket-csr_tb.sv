// Verifies Ricket CSR updates, privilege returns, and synchronous trap delegation.
module ricket_csr_tb;
  typedef struct packed {
    logic [63:0] pc;
    logic [31:0] instruction;
    logic [4:0] rd;
    logic [1:0] csr_operation;
    logic [11:0] csr_address;
    logic [63:0] csr_source;
    logic [2:0] system_operation;
    logic exception_valid;
    logic [63:0] exception_cause;
    logic [63:0] exception_value;
  } commit_bits_t;
  typedef struct packed { logic valid; commit_bits_t bits; } commit_in_t;
  typedef struct packed { logic valid; logic [63:0] bits; } redirect_out_t;

  localparam logic [1:0] CSR_NONE = 2'd0;
  localparam logic [1:0] CSR_WRITE = 2'd1;
  localparam logic [1:0] CSR_SET = 2'd2;
  localparam logic [1:0] CSR_CLEAR = 2'd3;
  localparam logic [11:0] CSR_STVEC = 12'h105;
  localparam logic [11:0] CSR_SEPC = 12'h141;
  localparam logic [11:0] CSR_SCAUSE = 12'h142;
  localparam logic [11:0] CSR_MSTATUS = 12'h300;
  localparam logic [11:0] CSR_MEDELEG = 12'h302;
  localparam logic [11:0] CSR_MTVEC = 12'h305;
  localparam logic [11:0] CSR_MSCRATCH = 12'h340;
  localparam logic [11:0] CSR_MEPC = 12'h341;
  localparam logic [11:0] CSR_MCAUSE = 12'h342;
  localparam logic [2:0] SYSTEM_NONE = 3'd0;
  localparam logic [2:0] SYSTEM_ECALL = 3'd1;
  localparam logic [2:0] SYSTEM_EBREAK = 3'd2;
  localparam logic [2:0] SYSTEM_MRET = 3'd3;
  localparam logic [2:0] SYSTEM_SRET = 3'd4;
  localparam logic [1:0] PRIVILEGE_U = 2'd0;
  localparam logic [1:0] PRIVILEGE_S = 2'd1;
  localparam logic [1:0] PRIVILEGE_M = 2'd3;

  logic clock = 1'b0;
  logic reset = 1'b1;
  commit_in_t commit_in;
  redirect_out_t redirect_out;
  logic writeback_valid;
  logic [63:0] writeback_value;
  logic [1:0] privilege;
  logic [63:0] satp;

  RicketCsrFile dut (.*);
  always #5 clock = ~clock;

  task automatic clear_commit;
    commit_in = '0;
  endtask

  task automatic csr_access(
    input logic [1:0] operation,
    input logic [11:0] address,
    input logic [63:0] source,
    input logic [63:0] expected_old
  );
    @(negedge clock);
    clear_commit();
    commit_in.valid = 1'b1;
    commit_in.bits.rd = 5'd1;
    commit_in.bits.csr_operation = operation;
    commit_in.bits.csr_address = address;
    commit_in.bits.csr_source = source;
    #1;
    assert (writeback_valid && writeback_value == expected_old)
      else $fatal(1, "CSR read/modify/write returned the wrong old value");
    assert (!redirect_out.valid)
      else $fatal(1, "legal CSR access unexpectedly redirected");
    @(posedge clock);
    #1;
    clear_commit();
  endtask

  task automatic system_action(
    input logic [2:0] operation,
    input logic [63:0] pc,
    input logic [63:0] expected_target
  );
    @(negedge clock);
    clear_commit();
    commit_in.valid = 1'b1;
    commit_in.bits.pc = pc;
    commit_in.bits.instruction = operation == SYSTEM_EBREAK ? 32'h00100073 : 32'h00000073;
    commit_in.bits.system_operation = operation;
    #1;
    assert (redirect_out.valid && redirect_out.bits == expected_target)
      else $fatal(1, "system operation selected the wrong trap or return target");
    @(posedge clock);
    #1;
    clear_commit();
  endtask

  initial begin
    clear_commit();
    repeat (2) @(posedge clock);
    #1;
    reset = 1'b0;
    assert (privilege == PRIVILEGE_M && satp == 0)
      else $fatal(1, "CSR file did not reset into M mode with bare translation");

    csr_access(CSR_WRITE, CSR_MSCRATCH, 64'h12, 64'h0);
    csr_access(CSR_SET, CSR_MSCRATCH, 64'h1, 64'h12);
    csr_access(CSR_CLEAR, CSR_MSCRATCH, 64'h10, 64'h13);
    csr_access(CSR_SET, CSR_MSCRATCH, 64'h0, 64'h3);

    csr_access(CSR_WRITE, CSR_MTVEC, 64'h100, 64'h0);
    csr_access(CSR_WRITE, CSR_STVEC, 64'h200, 64'h0);
    csr_access(CSR_WRITE, CSR_MEDELEG, 64'h104, 64'h0);
    csr_access(CSR_WRITE, CSR_MEPC, 64'h80, 64'h0);
    csr_access(CSR_WRITE, CSR_MSTATUS, 64'h800, 64'h0);
    system_action(SYSTEM_MRET, 64'h0, 64'h80);
    assert (privilege == PRIVILEGE_S)
      else $fatal(1, "MRET did not enter S mode");

    csr_access(CSR_WRITE, CSR_SEPC, 64'h40, 64'h0);
    system_action(SYSTEM_SRET, 64'h0, 64'h40);
    assert (privilege == PRIVILEGE_U)
      else $fatal(1, "SRET did not enter U mode");

    system_action(SYSTEM_ECALL, 64'h44, 64'h200);
    assert (privilege == PRIVILEGE_S)
      else $fatal(1, "delegated U-mode ECALL did not enter S mode");
    csr_access(CSR_SET, CSR_SCAUSE, 64'h0, 64'h8);
    csr_access(CSR_SET, CSR_SEPC, 64'h0, 64'h44);

    system_action(SYSTEM_EBREAK, 64'h48, 64'h100);
    assert (privilege == PRIVILEGE_M)
      else $fatal(1, "nondelegated breakpoint did not enter M mode");
    csr_access(CSR_SET, CSR_MCAUSE, 64'h0, 64'h3);
    csr_access(CSR_SET, CSR_MEPC, 64'h0, 64'h48);

    $display("Ricket CSR and privilege transitions passed");
    $finish;
  end
endmodule

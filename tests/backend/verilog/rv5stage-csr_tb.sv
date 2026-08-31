// Verifies RV5Stage CSR updates, trap delegation, interrupt delivery, and returns.
module rv5stage_csr_tb;
  typedef struct packed {
    logic supervisor_software;
    logic machine_software;
    logic supervisor_timer;
    logic machine_timer;
    logic supervisor_external;
    logic machine_external;
  } interrupts_t;
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
  localparam logic [11:0] CSR_SSTATUS = 12'h100;
  localparam logic [11:0] CSR_SEPC = 12'h141;
  localparam logic [11:0] CSR_SCAUSE = 12'h142;
  localparam logic [11:0] CSR_SIP = 12'h144;
  localparam logic [11:0] CSR_MSTATUS = 12'h300;
  localparam logic [11:0] CSR_MEDELEG = 12'h302;
  localparam logic [11:0] CSR_MIDELEG = 12'h303;
  localparam logic [11:0] CSR_MIE = 12'h304;
  localparam logic [11:0] CSR_MTVEC = 12'h305;
  localparam logic [11:0] CSR_MSCRATCH = 12'h340;
  localparam logic [11:0] CSR_MEPC = 12'h341;
  localparam logic [11:0] CSR_MCAUSE = 12'h342;
  localparam logic [11:0] CSR_MTVAL = 12'h343;
  localparam logic [11:0] CSR_MIP = 12'h344;
  localparam logic [11:0] CSR_TIME = 12'hc01;
  localparam logic [11:0] CSR_MHARTID = 12'hf14;
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
  logic [63:0] time_counter = 64'h12345678_9abcdef0;
  logic [63:0] hart_id = 64'd7;
  interrupts_t interrupts;
  logic interrupt_boundary;
  logic [63:0] interrupt_pc;
  commit_in_t commit_in;
  redirect_out_t redirect_out;
  logic interrupt_request;
  logic writeback_valid;
  logic [63:0] writeback_value;
  logic [1:0] privilege;
  logic [63:0] mstatus;
  logic [63:0] satp;

  RV5StageCsrFile dut (.*);
  always #5 clock = ~clock;

  task automatic clear_commit;
    commit_in = '0;
    interrupt_boundary = 1'b0;
  endtask

  task automatic take_interrupt(
    input logic [63:0] pc,
    input logic [63:0] expected_target,
    input logic [1:0] expected_privilege
  );
    @(negedge clock);
    clear_commit();
    interrupt_pc = pc;
    interrupt_boundary = 1'b1;
    #1;
    assert (interrupt_request && redirect_out.valid && redirect_out.bits == expected_target)
      else $fatal(1, "eligible interrupt did not select its trap target");
    @(posedge clock);
    #1;
    clear_commit();
    interrupts = '0;
    assert (privilege == expected_privilege)
      else $fatal(1, "interrupt entered the wrong privilege mode");
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
      else $fatal(1, "CSR %03h returned %016h instead of %016h",
                  address, writeback_value, expected_old);
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
    interrupts = '0;
    interrupt_pc = '0;
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
    csr_access(CSR_SET, CSR_TIME, 64'h0, time_counter);
    csr_access(CSR_SET, CSR_MHARTID, 64'h0, hart_id);

    csr_access(CSR_WRITE, CSR_MTVEC, 64'h100, 64'h0);
    csr_access(CSR_WRITE, CSR_STVEC, 64'h200, 64'h0);

    // A platform timer level is visible in mip, but cannot redirect until
    // both the local enable and M-mode global enable are set and WB offers a
    // precise architectural boundary.
    interrupts.machine_timer = 1'b1;
    #1;
    assert (!interrupt_request && !redirect_out.valid)
      else $fatal(1, "disabled machine timer interrupt became eligible");
    csr_access(CSR_SET, CSR_MIP, 64'h0, 64'h80);
    csr_access(CSR_WRITE, CSR_MIE, 64'h80, 64'h0);
    csr_access(CSR_WRITE, CSR_MSTATUS, 64'h8, 64'h0);
    #1;
    assert (interrupt_request && !redirect_out.valid)
      else $fatal(1, "eligible interrupt redirected without a precise boundary");
    take_interrupt(64'h60, 64'h100, PRIVILEGE_M);
    csr_access(CSR_SET, CSR_MCAUSE, 64'h0, 64'h8000000000000007);
    csr_access(CSR_SET, CSR_MEPC, 64'h0, 64'h60);
    csr_access(CSR_SET, CSR_MTVAL, 64'h0, 64'h0);
    system_action(SYSTEM_MRET, 64'h0, 64'h60);
    csr_access(CSR_WRITE, CSR_MSTATUS, 64'h0, 64'h88);

    // Supervisor interrupt-pending bits remain software-injectable through
    // mip/sip even when no platform source is asserted.
    csr_access(CSR_WRITE, CSR_MIP, 64'h20, 64'h0);
    csr_access(CSR_SET, CSR_MIP, 64'h0, 64'h20);
    csr_access(CSR_WRITE, CSR_MIP, 64'h0, 64'h20);

    csr_access(CSR_WRITE, CSR_MEDELEG, 64'h104, 64'h0);
    csr_access(CSR_WRITE, CSR_MIDELEG, 64'h200, 64'h0);
    csr_access(CSR_WRITE, CSR_MIE, 64'h200, 64'h80);
    csr_access(CSR_WRITE, CSR_MEPC, 64'h80, 64'h60);
    csr_access(CSR_WRITE, CSR_MSTATUS, 64'h802, 64'h0);
    system_action(SYSTEM_MRET, 64'h0, 64'h80);
    assert (privilege == PRIVILEGE_S)
      else $fatal(1, "MRET did not enter S mode");

    interrupts.supervisor_external = 1'b1;
    #1;
    assert (interrupt_request)
      else $fatal(1, "delegated supervisor external interrupt was not eligible");
    csr_access(CSR_SET, CSR_SIP, 64'h0, 64'h200);
    take_interrupt(64'h84, 64'h200, PRIVILEGE_S);
    csr_access(CSR_SET, CSR_SCAUSE, 64'h0, 64'h8000000000000009);
    csr_access(CSR_SET, CSR_SEPC, 64'h0, 64'h84);
    system_action(SYSTEM_SRET, 64'h0, 64'h84);
    assert (privilege == PRIVILEGE_S)
      else $fatal(1, "SRET did not resume the interrupted supervisor");
    csr_access(CSR_CLEAR, CSR_SSTATUS, 64'h100, 64'h22);

    csr_access(CSR_WRITE, CSR_SEPC, 64'h40, 64'h84);
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

    $display("RV5Stage CSR and privilege transitions passed");
    $finish;
  end
endmodule

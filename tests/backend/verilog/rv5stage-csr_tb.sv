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
    logic [1:0] csr;
    logic immediate;
    logic [2:0] action;
  } system_control_t;
  typedef struct packed {
    logic [1:0] action;
  } fence_control_t;
  typedef struct packed {
    logic [63:0] pc;
    logic [31:0] instruction;
    logic [4:0] rd;
    system_control_t system;
    fence_control_t fence;
    logic [11:0] csr_address;
    logic [63:0] csr_source;
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
  localparam logic [11:0] CSR_SCOUNTEREN = 12'h106;
  localparam logic [11:0] CSR_SEPC = 12'h141;
  localparam logic [11:0] CSR_SCAUSE = 12'h142;
  localparam logic [11:0] CSR_SIP = 12'h144;
  localparam logic [11:0] CSR_SATP = 12'h180;
  localparam logic [11:0] CSR_MSTATUS = 12'h300;
  localparam logic [11:0] CSR_MEDELEG = 12'h302;
  localparam logic [11:0] CSR_MIDELEG = 12'h303;
  localparam logic [11:0] CSR_MIE = 12'h304;
  localparam logic [11:0] CSR_MTVEC = 12'h305;
  localparam logic [11:0] CSR_MCOUNTEREN = 12'h306;
  localparam logic [11:0] CSR_MSCRATCH = 12'h340;
  localparam logic [11:0] CSR_MEPC = 12'h341;
  localparam logic [11:0] CSR_MCAUSE = 12'h342;
  localparam logic [11:0] CSR_MTVAL = 12'h343;
  localparam logic [11:0] CSR_MIP = 12'h344;
  localparam logic [11:0] CSR_MCYCLE = 12'hb00;
  localparam logic [11:0] CSR_MINSTRET = 12'hb02;
  localparam logic [11:0] CSR_CYCLE = 12'hc00;
  localparam logic [11:0] CSR_TIME = 12'hc01;
  localparam logic [11:0] CSR_INSTRET = 12'hc02;
  localparam logic [11:0] CSR_MHARTID = 12'hf14;
  localparam logic [2:0] SYSTEM_NONE = 3'd0;
  localparam logic [2:0] SYSTEM_ECALL = 3'd1;
  localparam logic [2:0] SYSTEM_EBREAK = 3'd2;
  localparam logic [2:0] SYSTEM_MRET = 3'd3;
  localparam logic [2:0] SYSTEM_SRET = 3'd4;
  localparam logic [2:0] SYSTEM_WFI = 3'd5;
  localparam logic [1:0] FENCE_NONE = 2'd0;
  localparam logic [1:0] FENCE_ADDRESS_TRANSLATION = 2'd3;
  localparam logic [1:0] PRIVILEGE_U = 2'd0;
  localparam logic [1:0] PRIVILEGE_S = 2'd1;
  localparam logic [1:0] PRIVILEGE_M = 2'd3;
  localparam logic [63:0] RV64_MSTATUS_FIXED = 64'h0000000a_00000000;
  localparam logic [63:0] RV64_SSTATUS_FIXED = 64'h00000002_00000000;
  localparam logic [63:0] MSTATUS_MPP_S = 64'h00000000_00000800;
  localparam logic [63:0] MSTATUS_TVM = 64'h00000000_00100000;
  localparam logic [63:0] MSTATUS_TW = 64'h00000000_00200000;
  localparam logic [63:0] MSTATUS_TSR = 64'h00000000_00400000;

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
  logic translation_flush;

  RV5StageCsrFile dut (.*);
  always #5 clock = ~clock;

  task automatic clear_commit;
    commit_in = '0;
    interrupt_boundary = 1'b0;
  endtask

  task automatic reset_dut;
    reset = 1'b1;
    interrupts = '0;
    interrupt_pc = '0;
    clear_commit();
    repeat (2) @(posedge clock);
    #1;
    reset = 1'b0;
    assert (privilege == PRIVILEGE_M && satp == 0 && mstatus == RV64_MSTATUS_FIXED)
      else $fatal(1, "CSR file did not reset into M mode with bare translation");
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
    commit_in.bits.system.csr = operation;
    commit_in.bits.csr_address = address;
    commit_in.bits.csr_source = source;
    if ((operation == CSR_SET || operation == CSR_CLEAR) && source != 0)
      commit_in.bits.instruction[19:15] = 5'd1;
    #1;
    assert (writeback_valid && writeback_value == expected_old)
      else $fatal(1, "CSR %03h returned %016h instead of %016h",
                  address, writeback_value, expected_old);
    assert (!redirect_out.valid && !translation_flush)
      else $fatal(1, "legal CSR access unexpectedly redirected");
    @(posedge clock);
    #1;
    clear_commit();
  endtask

  task automatic csr_read_legal(input logic [11:0] address);
    @(negedge clock);
    clear_commit();
    commit_in.valid = 1'b1;
    commit_in.bits.rd = 5'd1;
    commit_in.bits.system.csr = CSR_SET;
    commit_in.bits.csr_address = address;
    #1;
    assert (writeback_valid && !redirect_out.valid && !translation_flush)
      else $fatal(1, "legal CSR %03h read trapped", address);
    @(posedge clock);
    #1;
    clear_commit();
  endtask

  task automatic csr_write_intent_traps(
    input logic [1:0] operation,
    input logic [11:0] address,
    input logic [4:0] source_specifier
  );
    @(negedge clock);
    clear_commit();
    commit_in.valid = 1'b1;
    commit_in.bits.rd = 5'd1;
    commit_in.bits.system.csr = operation;
    commit_in.bits.csr_address = address;
    commit_in.bits.instruction[19:15] = source_specifier;
    #1;
    assert (!writeback_valid && redirect_out.valid)
      else $fatal(1, "illegal CSR %03h write intent did not trap", address);
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
    case (operation)
      SYSTEM_EBREAK: commit_in.bits.instruction = 32'h00100073;
      SYSTEM_MRET: commit_in.bits.instruction = 32'h30200073;
      SYSTEM_SRET: commit_in.bits.instruction = 32'h10200073;
      SYSTEM_WFI: commit_in.bits.instruction = 32'h10500073;
      default: commit_in.bits.instruction = 32'h00000073;
    endcase
    commit_in.bits.system.action = operation;
    #1;
    assert (redirect_out.valid && redirect_out.bits == expected_target)
      else $fatal(1, "system operation selected the wrong trap or return target");
    @(posedge clock);
    #1;
    clear_commit();
  endtask

  task automatic privileged_action(
    input logic [2:0] system_operation,
    input logic [1:0] fence_operation,
    input logic [63:0] pc,
    input logic [31:0] instruction,
    input logic expect_trap,
    input logic expect_flush
  );
    @(negedge clock);
    clear_commit();
    commit_in.valid = 1'b1;
    commit_in.bits.pc = pc;
    commit_in.bits.instruction = instruction;
    commit_in.bits.system.action = system_operation;
    commit_in.bits.fence.action = fence_operation;
    #1;
    assert (redirect_out.valid == expect_trap)
      else $fatal(1, "privileged operation trap decision was incorrect");
    if (expect_trap)
      assert (redirect_out.bits == 64'h100)
        else $fatal(1, "illegal privileged operation selected the wrong trap target");
    assert (translation_flush == expect_flush)
      else $fatal(1, "privileged operation translation-flush decision was incorrect");
    @(posedge clock);
    #1;
    clear_commit();
  endtask

  task automatic illegal_csr_read(
    input logic [11:0] address,
    input logic [63:0] pc,
    input logic [31:0] instruction
  );
    @(negedge clock);
    clear_commit();
    commit_in.valid = 1'b1;
    commit_in.bits.pc = pc;
    commit_in.bits.instruction = instruction;
    commit_in.bits.rd = 5'd1;
    commit_in.bits.system.csr = CSR_SET;
    commit_in.bits.csr_address = address;
    #1;
    assert (!writeback_valid && redirect_out.valid && redirect_out.bits == 64'h100)
      else $fatal(1, "restricted CSR %03h read did not trap", address);
    assert (!translation_flush)
      else $fatal(1, "restricted CSR %03h read caused a translation flush", address);
    @(posedge clock);
    #1;
    clear_commit();
  endtask

  task automatic enter_supervisor(input logic [63:0] mstatus_flags);
    csr_access(CSR_WRITE, CSR_MTVEC, 64'h100, 64'h0);
    csr_access(CSR_WRITE, CSR_MSTATUS, mstatus_flags | MSTATUS_MPP_S, RV64_MSTATUS_FIXED);
    csr_access(CSR_WRITE, CSR_MEPC, 64'h200, 64'h0);
    system_action(SYSTEM_MRET, 64'h0, 64'h200);
    assert (privilege == PRIVILEGE_S)
      else $fatal(1, "MRET did not enter S mode for privileged-operation test");
  endtask

  task automatic check_illegal_trap(
    input logic [63:0] pc,
    input logic [31:0] instruction
  );
    assert (privilege == PRIVILEGE_M)
      else $fatal(1, "illegal privileged operation did not enter M mode");
    csr_access(CSR_SET, CSR_MCAUSE, 64'h0, 64'h2);
    csr_access(CSR_SET, CSR_MEPC, 64'h0, pc);
    csr_access(CSR_SET, CSR_MTVAL, 64'h0, {32'h0, instruction});
  endtask

  initial begin
    reset_dut();

    csr_access(CSR_WRITE, CSR_MCYCLE, 64'h100, 64'h0);
    csr_access(CSR_SET, CSR_CYCLE, 64'h0, 64'h100);
    csr_access(CSR_WRITE, CSR_MINSTRET, 64'h200, 64'h2);
    csr_access(CSR_SET, CSR_INSTRET, 64'h0, 64'h200);

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
    csr_access(CSR_WRITE, CSR_MSTATUS, 64'h8, RV64_MSTATUS_FIXED);
    #1;
    assert (interrupt_request && !redirect_out.valid)
      else $fatal(1, "eligible interrupt redirected without a precise boundary");
    take_interrupt(64'h60, 64'h100, PRIVILEGE_M);
    csr_access(CSR_SET, CSR_MCAUSE, 64'h0, 64'h8000000000000007);
    csr_access(CSR_SET, CSR_MEPC, 64'h0, 64'h60);
    csr_access(CSR_SET, CSR_MTVAL, 64'h0, 64'h0);
    system_action(SYSTEM_MRET, 64'h0, 64'h60);
    csr_access(CSR_WRITE, CSR_MSTATUS, 64'h0, RV64_MSTATUS_FIXED | 64'h88);

    // Supervisor interrupt-pending bits remain software-injectable through
    // mip/sip even when no platform source is asserted.
    csr_access(CSR_WRITE, CSR_MIP, 64'h20, 64'h0);
    csr_access(CSR_SET, CSR_MIP, 64'h0, 64'h20);
    csr_access(CSR_WRITE, CSR_MIP, 64'h0, 64'h20);

    csr_access(CSR_WRITE, CSR_MEDELEG, 64'h104, 64'h0);
    csr_access(CSR_WRITE, CSR_MIDELEG, 64'h200, 64'h0);
    csr_access(CSR_WRITE, CSR_MIE, 64'h200, 64'h80);
    csr_access(CSR_WRITE, CSR_MCOUNTEREN, 64'h5, 64'h0);
    csr_access(CSR_WRITE, CSR_SCOUNTEREN, 64'h5, 64'h0);
    csr_access(CSR_WRITE, CSR_MEPC, 64'h80, 64'h60);
    csr_access(CSR_WRITE, CSR_MSTATUS, 64'h802, RV64_MSTATUS_FIXED);
    system_action(SYSTEM_MRET, 64'h0, 64'h80);
    assert (privilege == PRIVILEGE_S)
      else $fatal(1, "MRET did not enter S mode");
    csr_read_legal(CSR_CYCLE);
    csr_read_legal(CSR_INSTRET);

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
    csr_access(CSR_CLEAR, CSR_SSTATUS, 64'h100, RV64_SSTATUS_FIXED | 64'h22);

    csr_access(CSR_WRITE, CSR_SEPC, 64'h40, 64'h84);
    system_action(SYSTEM_SRET, 64'h0, 64'h40);
    assert (privilege == PRIVILEGE_U)
      else $fatal(1, "SRET did not enter U mode");
    csr_read_legal(CSR_CYCLE);
    csr_read_legal(CSR_INSTRET);

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

    // CSRRS with a nonzero source register is a write attempt even when that
    // register's runtime value is zero, so the read-only cycle view must trap.
    csr_write_intent_traps(CSR_SET, CSR_CYCLE, 5'd1);

    // TVM, TW, and TSR are writable M-mode controls. Their legality checks
    // happen at commit, where the current privilege and complete operation are
    // available and rejected operations cannot trigger translation effects.
    reset_dut();
    enter_supervisor(64'h0);
    csr_read_legal(CSR_SATP);
    privileged_action(SYSTEM_NONE, FENCE_ADDRESS_TRANSLATION, 64'h204, 32'h12000073, 1'b0, 1'b1);
    privileged_action(SYSTEM_WFI, FENCE_NONE, 64'h208, 32'h10500073, 1'b0, 1'b0);

    reset_dut();
    enter_supervisor(MSTATUS_TVM);
    privileged_action(SYSTEM_NONE, FENCE_ADDRESS_TRANSLATION, 64'h20c, 32'h12000073, 1'b1, 1'b0);
    check_illegal_trap(64'h20c, 32'h12000073);

    reset_dut();
    enter_supervisor(MSTATUS_TVM);
    illegal_csr_read(CSR_SATP, 64'h210, 32'h180020f3);
    check_illegal_trap(64'h210, 32'h180020f3);

    reset_dut();
    enter_supervisor(MSTATUS_TSR);
    privileged_action(SYSTEM_SRET, FENCE_NONE, 64'h214, 32'h10200073, 1'b1, 1'b0);
    check_illegal_trap(64'h214, 32'h10200073);

    reset_dut();
    enter_supervisor(MSTATUS_TW);
    privileged_action(SYSTEM_WFI, FENCE_NONE, 64'h218, 32'h10500073, 1'b1, 1'b0);
    check_illegal_trap(64'h218, 32'h10500073);

    $display("RV5Stage CSR and privilege transitions passed");
    $finish;
  end
endmodule

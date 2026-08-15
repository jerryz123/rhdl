// Simulates every RV64I integer ALU control combination and important width edge cases.
module rv64i_alu_tb;
    typedef struct packed {
        logic [5:0] result_select;
        logic subtract;
        logic signed_mode;
        logic shift_right;
        logic word;
    } alu_control_t;

    localparam alu_control_t ALU_ADD = '{
        result_select: 6'b000001, default: 1'b0
    };
    localparam alu_control_t ALU_SUB = '{
        result_select: 6'b000001, subtract: 1'b1, default: 1'b0
    };
    localparam alu_control_t ALU_SLL = '{
        result_select: 6'b000010, default: 1'b0
    };
    localparam alu_control_t ALU_SLT = '{
        result_select: 6'b000100, signed_mode: 1'b1, default: 1'b0
    };
    localparam alu_control_t ALU_SLTU = '{
        result_select: 6'b000100, default: 1'b0
    };
    localparam alu_control_t ALU_XOR = '{
        result_select: 6'b001000, default: 1'b0
    };
    localparam alu_control_t ALU_SRL = '{
        result_select: 6'b000010, shift_right: 1'b1, default: 1'b0
    };
    localparam alu_control_t ALU_SRA = '{
        result_select: 6'b000010, signed_mode: 1'b1, shift_right: 1'b1,
        default: 1'b0
    };
    localparam alu_control_t ALU_OR = '{
        result_select: 6'b010000, default: 1'b0
    };
    localparam alu_control_t ALU_AND = '{
        result_select: 6'b100000, default: 1'b0
    };
    localparam alu_control_t ALU_ADDW = '{
        result_select: 6'b000001, word: 1'b1, default: 1'b0
    };
    localparam alu_control_t ALU_SUBW = '{
        result_select: 6'b000001, subtract: 1'b1, word: 1'b1,
        default: 1'b0
    };
    localparam alu_control_t ALU_SLLW = '{
        result_select: 6'b000010, word: 1'b1, default: 1'b0
    };
    localparam alu_control_t ALU_SRLW = '{
        result_select: 6'b000010, shift_right: 1'b1, word: 1'b1,
        default: 1'b0
    };
    localparam alu_control_t ALU_SRAW = '{
        result_select: 6'b000010, signed_mode: 1'b1, shift_right: 1'b1,
        word: 1'b1, default: 1'b0
    };

    logic [63:0] left;
    logic [63:0] right;
    alu_control_t control;
    logic [63:0] result;

    ALU dut (
        .left(left),
        .right(right),
        .control(control),
        .result(result)
    );

    task automatic check_alu(
        input alu_control_t control_in,
        input logic [63:0] left_in,
        input logic [63:0] right_in,
        input logic [63:0] expected
    );
        control = control_in;
        left = left_in;
        right = right_in;
        #1;
        assert (result == expected)
            else $fatal(1,
                        "ALU control %b failed: left=%h right=%h result=%h expected=%h",
                        control_in, left_in, right_in, result, expected);
    endtask

    initial begin
        check_alu(ALU_ADD,  64'hFFFFFFFFFFFFFFFF, 64'd1, 64'd0);
        check_alu(ALU_SUB,  64'd0, 64'd1, 64'hFFFFFFFFFFFFFFFF);
        check_alu(ALU_SLL,  64'h1, 64'd63, 64'h8000000000000000);
        check_alu(ALU_SLL,  64'h1, 64'd64, 64'h1);
        check_alu(ALU_SLT,  64'hFFFFFFFFFFFFFFFF, 64'd0, 64'd1);
        check_alu(ALU_SLT,  64'h7FFFFFFFFFFFFFFF, 64'h8000000000000000, 64'd0);
        check_alu(ALU_SLTU, 64'hFFFFFFFFFFFFFFFF, 64'd0, 64'd0);
        check_alu(ALU_SLTU, 64'd0, 64'hFFFFFFFFFFFFFFFF, 64'd1);
        check_alu(ALU_XOR,  64'hAA55AA55AA55AA55, 64'hFFFF0000FFFF0000, 64'h55AAAA5555AAAA55);
        check_alu(ALU_SRL,  64'h8000000000000000, 64'd63, 64'd1);
        check_alu(ALU_SRL,  64'h8000000000000000, 64'd64, 64'h8000000000000000);
        check_alu(ALU_SRA,  64'h8000000000000000, 64'd63, 64'hFFFFFFFFFFFFFFFF);
        check_alu(ALU_SRA,  64'h8000000000000000, 64'd1, 64'hC000000000000000);
        check_alu(ALU_OR,   64'hF000, 64'h0F0F, 64'hFF0F);
        check_alu(ALU_AND,  64'hF0F0, 64'h0FF0, 64'h00F0);
        check_alu(ALU_ADDW, 64'h000000007FFFFFFF, 64'd1, 64'hFFFFFFFF80000000);
        check_alu(ALU_ADDW, 64'hFFFFFFFFFFFFFFFF, 64'd1, 64'd0);
        check_alu(ALU_SUBW, 64'd0, 64'd1, 64'hFFFFFFFFFFFFFFFF);
        check_alu(ALU_SLLW, 64'd1, 64'd31, 64'hFFFFFFFF80000000);
        check_alu(ALU_SLLW, 64'd1, 64'd32, 64'd1);
        check_alu(ALU_SRLW, 64'h0000000080000000, 64'd31, 64'd1);
        check_alu(ALU_SRAW, 64'h0000000080000000, 64'd31, 64'hFFFFFFFFFFFFFFFF);
        check_alu(ALU_SRAW, 64'h0000000080000000, 64'd1, 64'hFFFFFFFFC0000000);
        $display("RV64I integer ALU simulation passed");
        $finish;
    end
endmodule

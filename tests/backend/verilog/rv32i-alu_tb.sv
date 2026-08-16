// Simulates 32-bit integer ALU operations and shift-width edge cases.
module rv32i_alu_tb;
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
    localparam alu_control_t ALU_ADD_WORD = '{
        result_select: 6'b000001, word: 1'b1, default: 1'b0
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
    localparam alu_control_t ALU_OR = '{
        result_select: 6'b010000, default: 1'b0
    };
    localparam alu_control_t ALU_AND = '{
        result_select: 6'b100000, default: 1'b0
    };
    localparam alu_control_t ALU_SRL = '{
        result_select: 6'b000010, shift_right: 1'b1, default: 1'b0
    };
    localparam alu_control_t ALU_SRA = '{
        result_select: 6'b000010, signed_mode: 1'b1, shift_right: 1'b1,
        default: 1'b0
    };

    logic [31:0] left;
    logic [31:0] right;
    alu_control_t control;
    logic [31:0] result;

    ALU dut (
        .left(left),
        .right(right),
        .control(control),
        .result(result)
    );

    task automatic check_alu(
        input alu_control_t control_in,
        input logic [31:0] left_in,
        input logic [31:0] right_in,
        input logic [31:0] expected
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
        check_alu(ALU_ADD,  32'hFFFFFFFF, 32'd1, 32'd0);
        check_alu(ALU_SUB,  32'd0, 32'd1, 32'hFFFFFFFF);
        check_alu(ALU_ADD_WORD, 32'h7FFFFFFF, 32'd1, 32'h80000000);
        check_alu(ALU_SLL,  32'h1, 32'd31, 32'h80000000);
        check_alu(ALU_SLL,  32'h1, 32'd32, 32'h1);
        check_alu(ALU_SLT,  32'hFFFFFFFF, 32'd0, 32'd1);
        check_alu(ALU_SLT,  32'h7FFFFFFF, 32'h80000000, 32'd0);
        check_alu(ALU_SLTU, 32'hFFFFFFFF, 32'd0, 32'd0);
        check_alu(ALU_SLTU, 32'd0, 32'hFFFFFFFF, 32'd1);
        check_alu(ALU_XOR,  32'hAA55AA55, 32'hFFFF0000, 32'h55AAAA55);
        check_alu(ALU_OR,   32'hF000, 32'h0F0F, 32'hFF0F);
        check_alu(ALU_AND,  32'hF0F0, 32'h0FF0, 32'h00F0);
        check_alu(ALU_SRL,  32'h80000000, 32'd31, 32'd1);
        check_alu(ALU_SRL,  32'h80000000, 32'd32, 32'h80000000);
        check_alu(ALU_SRA,  32'h80000000, 32'd31, 32'hFFFFFFFF);
        check_alu(ALU_SRA,  32'h80000000, 32'd1, 32'hC0000000);
        $display("32-bit integer ALU simulation passed");
        $finish;
    end
endmodule

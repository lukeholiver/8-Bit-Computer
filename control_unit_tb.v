`timescale 1ns/1ps
`include "control_unit_defines.vh"

module control_unit_tb;

    reg clk;
    reg reset;

    wire [2:0] data_path;
    wire [3:0] alu_sel;
    wire [1:0] comp_sel;
    wire [2:0] reg_data_sel;
    wire [1:0] mem_data_sel;
    wire [1:0] pc_inc_sel;
    wire branch_gate_ena;
    wire rsp_inc;
    wire rsp_dec;

    integer errors = 0;

    control_unit uut (
        .clk(clk),
        .reset(reset),
        .data_path(data_path),
        .alu_sel(alu_sel),
        .comp_sel(comp_sel),
        .reg_data_sel(reg_data_sel),
        .mem_data_sel(mem_data_sel),
        .pc_inc_sel(pc_inc_sel),
        .branch_gate_ena(branch_gate_ena),
        .rsp_inc(rsp_inc),
        .rsp_dec(rsp_dec)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, control_unit_tb);
    end

    // checks every output signal for a given ir value in one shot,
    // reporting exactly which field(s) mismatched if any
    task check_decode;
        input [7:0] ir_val;
        input [3:0] exp_data_path;
        input [3:0] exp_alu_sel;
        input [1:0] exp_comp_sel;
        input [2:0] exp_reg_data_sel;
        input [1:0] exp_mem_data_sel;
        input [1:0] exp_pc_inc_sel;
        input exp_branch_gate_ena;
        input exp_rsp_inc;
        input exp_rsp_dec;
        input [191:0] label;
        reg fail;
        begin
            uut.ir = ir_val;
            #1;
            fail = 0;

            if (data_path !== exp_data_path) begin
                $display("  FAIL[%0s]: data_path expected %h got %h", label, exp_data_path, data_path);
                fail = 1;
            end
            if (alu_sel !== exp_alu_sel) begin
                $display("  FAIL[%0s]: alu_sel expected %h got %h", label, exp_alu_sel, alu_sel);
                fail = 1;
            end
            if (comp_sel !== exp_comp_sel) begin
                $display("  FAIL[%0s]: comp_sel expected %b got %b", label, exp_comp_sel, comp_sel);
                fail = 1;
            end
            if (reg_data_sel !== exp_reg_data_sel) begin
                $display("  FAIL[%0s]: reg_data_sel expected %b got %b", label, exp_reg_data_sel, reg_data_sel);
                fail = 1;
            end
            if (mem_data_sel !== exp_mem_data_sel) begin
                $display("  FAIL[%0s]: mem_data_sel expected %b got %b", label, exp_mem_data_sel, mem_data_sel);
                fail = 1;
            end
            if (pc_inc_sel !== exp_pc_inc_sel) begin
                $display("  FAIL[%0s]: pc_inc_sel expected %b got %b", label, exp_pc_inc_sel, pc_inc_sel);
                fail = 1;
            end
            if (branch_gate_ena !== exp_branch_gate_ena) begin
                $display("  FAIL[%0s]: branch_gate_ena expected %b got %b", label, exp_branch_gate_ena, branch_gate_ena);
                fail = 1;
            end
            if (rsp_inc !== exp_rsp_inc) begin
                $display("  FAIL[%0s]: rsp_inc expected %b got %b", label, exp_rsp_inc, rsp_inc);
                fail = 1;
            end
            if (rsp_dec !== exp_rsp_dec) begin
                $display("  FAIL[%0s]: rsp_dec expected %b got %b", label, exp_rsp_dec, rsp_dec);
                fail = 1;
            end

            if (fail)
                errors = errors + 1;
            else
                $display("PASS: %0s", label);
        end
    endtask

    initial begin
        clk = 0;
        reset = 0;

        // ---- icode 0x0: neg / bnot / lnot / mov pc,%rA ----
        check_decode(8'b0000_00_00, `REG_ONLY, `NEG,  `JNE, `REG_SEL_ALU, `MEM_SEL_NONE, `PC_SEL_1, 0, 0, 0, "0x0.0 neg");
        check_decode(8'b0000_00_01, `REG_ONLY, `BNOT, `JNE, `REG_SEL_ALU, `MEM_SEL_NONE, `PC_SEL_1, 0, 0, 0, "0x0.1 bnot");
        check_decode(8'b0000_00_10, `REG_ONLY, `LNOT, `JNE, `REG_SEL_ALU, `MEM_SEL_NONE, `PC_SEL_1, 0, 0, 0, "0x0.2 lnot");
        check_decode(8'b0000_00_11, `SMP_MOVE, `NEG,  `JNE, `REG_SEL_PC,  `MEM_SEL_NONE, `PC_SEL_1, 0, 0, 0, "0x0.3 mov pc,rA");

        // ---- icode 0x1: mov %rB,%rA ----
        check_decode(8'b0001_00_00, `SMP_MOVE, `NEG, `JNE, `REG_SEL_REG, `MEM_SEL_NONE, `PC_SEL_1, 0, 0, 0, "0x1 mov reg,reg");

        // ---- icodes 0x2-0x9: register-form ALU ops ----
        check_decode(8'b0010_00_00, `REG_ONLY, `ADD, `JNE, `REG_SEL_ALU, `MEM_SEL_NONE, `PC_SEL_1, 0, 0, 0, "0x2 add");
        check_decode(8'b0011_00_00, `REG_ONLY, `SUB, `JNE, `REG_SEL_ALU, `MEM_SEL_NONE, `PC_SEL_1, 0, 0, 0, "0x3 sub");
        check_decode(8'b0100_00_00, `REG_ONLY, `MUL, `JNE, `REG_SEL_ALU, `MEM_SEL_NONE, `PC_SEL_1, 0, 0, 0, "0x4 mul");
        check_decode(8'b0101_00_00, `REG_ONLY, `SHL, `JNE, `REG_SEL_ALU, `MEM_SEL_NONE, `PC_SEL_1, 0, 0, 0, "0x5 shl");
        check_decode(8'b0110_00_00, `REG_ONLY, `SHR, `JNE, `REG_SEL_ALU, `MEM_SEL_NONE, `PC_SEL_1, 0, 0, 0, "0x6 shr");
        check_decode(8'b0111_00_00, `REG_ONLY, `AND, `JNE, `REG_SEL_ALU, `MEM_SEL_NONE, `PC_SEL_1, 0, 0, 0, "0x7 and");
        check_decode(8'b1000_00_00, `REG_ONLY, `OR,  `JNE, `REG_SEL_ALU, `MEM_SEL_NONE, `PC_SEL_1, 0, 0, 0, "0x8 or");
        check_decode(8'b1001_00_00, `REG_ONLY, `XOR, `JNE, `REG_SEL_ALU, `MEM_SEL_NONE, `PC_SEL_1, 0, 0, 0, "0x9 xor");

        // ---- icode 0xA/0xB: single memory move ----
        check_decode(8'b1010_00_00, `MEM_MOVE, `NEG, `JNE, `REG_SEL_MEM_SPC, `MEM_SEL_NONE, `PC_SEL_1, 0, 0, 0, "0xA mov (rB),rA");
        check_decode(8'b1011_00_00, `MEM_MOVE, `NEG, `JNE, `REG_SEL_NONE,    `MEM_SEL_REG,  `PC_SEL_1, 0, 0, 0, "0xB mov rA,(rB)");

        // ---- icode 0xC: immediate-touching variants ----
        check_decode(8'b1100_00_00, `MEM_MOVE, `NEG, `JNE, `REG_SEL_MEM_IMM, `MEM_SEL_NONE, `PC_SEL_2, 0, 0, 0, "0xC.0 mov $imm,rA");
        check_decode(8'b1100_00_01, `IMM_OP,   `ADD, `JNE, `REG_SEL_ALU,     `MEM_SEL_NONE, `PC_SEL_2, 0, 0, 0, "0xC.1 add $imm,rA");
        check_decode(8'b1100_00_10, `DBL_MEM,  `NEG, `JNE, `REG_SEL_NONE,    `MEM_SEL_IMM,  `PC_SEL_2, 0, 0, 0, "0xC.2 mov $imm,(rA)");
        check_decode(8'b1100_00_11, `DBL_MEM,  `NEG, `JNE, `REG_SEL_MEM_SPC, `MEM_SEL_NONE, `PC_SEL_2, 0, 0, 0, "0xC.3 mov ($imm),rA");

        // ---- icode 0xD: branches ----
        check_decode(8'b1101_00_00, `IMM_OP, `NEG, `JGT, `REG_SEL_NONE, `MEM_SEL_NONE, `PC_SEL_IMM, 1, 0, 0, "0xD.0 jgt");
        check_decode(8'b1101_00_01, `IMM_OP, `NEG, `JLT, `REG_SEL_NONE, `MEM_SEL_NONE, `PC_SEL_IMM, 1, 0, 0, "0xD.1 jlt");
        check_decode(8'b1101_00_10, `IMM_OP, `NEG, `JE,  `REG_SEL_NONE, `MEM_SEL_NONE, `PC_SEL_IMM, 1, 0, 0, "0xD.2 je");
        check_decode(8'b1101_00_11, `IMM_OP, `NEG, `JNE, `REG_SEL_NONE, `MEM_SEL_NONE, `PC_SEL_IMM, 1, 0, 0, "0xD.3 jne");

        // ---- icode 0xE: stack ops ----
        check_decode(8'b1110_00_00, `MEM_MOVE, `NEG, `JNE, `REG_SEL_NONE,    `MEM_SEL_REG, `PC_SEL_1,   0, 0, 1, "0xE.0 push reg");
        check_decode(8'b1110_00_01, `DBL_MEM,  `NEG, `JNE, `REG_SEL_NONE,    `MEM_SEL_IMM, `PC_SEL_2,   0, 0, 1, "0xE.1 push imm");
        check_decode(8'b1110_00_10, `MEM_MOVE, `NEG, `JNE, `REG_SEL_MEM_RSP, `MEM_SEL_NONE,`PC_SEL_1,   0, 1, 0, "0xE.2 pop");
        check_decode(8'b1110_00_11, `SMP_MOVE, `NEG, `JNE, `REG_SEL_RSP,     `MEM_SEL_NONE,`PC_SEL_1,   0, 0, 0, "0xE.3 mov rsp,rA");

        // ---- icode 0xF: jmp / call / ret / halt ----
        check_decode(8'b1111_00_00, `MEM_MOVE, `NEG, `JNE, `REG_SEL_NONE, `MEM_SEL_NONE,  `PC_SEL_IMM, 0, 0, 0, "0xF.0 jmp");
        check_decode(8'b1111_00_01, `DBL_MEM,  `NEG, `JNE, `REG_SEL_NONE, `MEM_SEL_PC2,   `PC_SEL_IMM, 0, 0, 1, "0xF.1 call");
        check_decode(8'b1111_00_10, `MEM_MOVE, `NEG, `JNE, `REG_SEL_NONE, `MEM_SEL_NONE,  `PC_SEL_RSP, 0, 1, 0, "0xF.2 ret");
        check_decode(8'b1111_00_11, `SMP_MOVE, `NEG, `JNE, `REG_SEL_NONE, `MEM_SEL_NONE,  `PC_SEL_1,   0, 0, 0, "0xF.3 halt");

        // ---- summary ----
        if (errors == 0)
            $display("\nALL TESTS PASSED");
        else
            $display("\n%0d TEST(S) FAILED", errors);

        $finish;
    end

endmodule
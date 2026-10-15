`timescale 1ns/1ps
`include "control_unit_defines.vh"

// Decode-level testbench for control_unit.
// Forces uut.ir directly and checks every selector the combinational decode block
// produces. reset is held high for the whole test: the reset branch only drives
// state, so the FSM can never reach FETCH and overwrite the forced ir value.
// State timing and enable gating are covered separately in control_unit_full_tb.

module control_unit_tb;

    reg clk;
    reg reset;
    reg [7:0] mem_pc;

    wire [3:0] alu_sel;
    wire [1:0] comp_sel;
    wire [2:0] reg_data_sel;
    wire [1:0] mem_data_sel;
    wire [1:0] pc_inc_sel;
    wire alu_source_sel;
    wire [1:0] special_addr_source_sel;
    wire branch_gate_ena;
    wire rsp_inc;
    wire rsp_dec;
    wire rsp_write_ena;
    wire write_ena;
    wire special_write_ena;
    wire pc_ena;
    wire [1:0] reg_addr_a;
    wire [1:0] reg_addr_b;

    integer errors = 0;

    control_unit uut (
        .clk(clk),
        .reset(reset),
        .mem_pc(mem_pc),
        .alu_sel(alu_sel),
        .comp_sel(comp_sel),
        .reg_data_sel(reg_data_sel),
        .mem_data_sel(mem_data_sel),
        .pc_inc_sel(pc_inc_sel),
        .alu_source_sel(alu_source_sel),
        .special_addr_source_sel(special_addr_source_sel),
        .branch_gate_ena(branch_gate_ena),
        .rsp_inc(rsp_inc),
        .rsp_dec(rsp_dec),
        .rsp_write_ena(rsp_write_ena),
        .write_ena(write_ena),
        .special_write_ena(special_write_ena),
        .pc_ena(pc_ena),
        .reg_addr_a(reg_addr_a),
        .reg_addr_b(reg_addr_b)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("control_unit_tb.vcd");
        $dumpvars(0, control_unit_tb);
    end

    // forces ir, lets decode settle, then checks every decode output in one shot
    // argument order: ir, data_path, alu_sel, comp_sel, reg_data_sel, mem_data_sel,
    //                 pc_inc_sel, alu_source_sel, special_addr_source_sel,
    //                 branch_gate_ena, rsp_inc_sel, rsp_dec_sel, label
    task check_decode;
        input [7:0] ir_val;
        input [2:0] exp_data_path;
        input [3:0] exp_alu_sel;
        input [1:0] exp_comp_sel;
        input [2:0] exp_reg_data_sel;
        input [1:0] exp_mem_data_sel;
        input [1:0] exp_pc_inc_sel;
        input exp_alu_source_sel;
        input [1:0] exp_special_addr_source_sel;
        input exp_branch_gate_ena;
        input exp_rsp_inc_sel;
        input exp_rsp_dec_sel;
        input [255:0] label;
        reg fail;
        begin
            uut.ir = ir_val;
            #1;
            fail = 0;

            if (uut.data_path !== exp_data_path) begin
                $display("  FAIL[%0s]: data_path expected %h got %h", label, exp_data_path, uut.data_path);
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
            if (alu_source_sel !== exp_alu_source_sel) begin
                $display("  FAIL[%0s]: alu_source_sel expected %b got %b", label, exp_alu_source_sel, alu_source_sel);
                fail = 1;
            end
            if (special_addr_source_sel !== exp_special_addr_source_sel) begin
                $display("  FAIL[%0s]: special_addr_source_sel expected %b got %b", label, exp_special_addr_source_sel, special_addr_source_sel);
                fail = 1;
            end
            if (branch_gate_ena !== exp_branch_gate_ena) begin
                $display("  FAIL[%0s]: branch_gate_ena expected %b got %b", label, exp_branch_gate_ena, branch_gate_ena);
                fail = 1;
            end
            if (uut.rsp_inc_sel !== exp_rsp_inc_sel) begin
                $display("  FAIL[%0s]: rsp_inc_sel expected %b got %b", label, exp_rsp_inc_sel, uut.rsp_inc_sel);
                fail = 1;
            end
            if (uut.rsp_dec_sel !== exp_rsp_dec_sel) begin
                $display("  FAIL[%0s]: rsp_dec_sel expected %b got %b", label, exp_rsp_dec_sel, uut.rsp_dec_sel);
                fail = 1;
            end

            if (fail)
                errors = errors + 1;
            else
                $display("PASS: %0s", label);
        end
    endtask

    // forces ir and checks that the register address outputs track ir[3:2] / ir[1:0]
    task check_reg_addr;
        input [7:0] ir_val;
        input [255:0] label;
        begin
            uut.ir = ir_val;
            #1;
            if (reg_addr_a !== ir_val[3:2] || reg_addr_b !== ir_val[1:0]) begin
                $display("  FAIL[%0s]: reg_addr_a/b expected %b/%b got %b/%b",
                         label, ir_val[3:2], ir_val[1:0], reg_addr_a, reg_addr_b);
                errors = errors + 1;
            end
            else
                $display("PASS: %0s", label);
        end
    endtask

    initial begin
        clk = 0;
        reset = 1;      // held high for the entire test - see header comment
        mem_pc = 8'h00;

        // ---- icode 0x0: neg / bnot / lnot / mov pc,%rA ----
        check_decode(8'b0000_00_00, `REG_ONLY, `NEG,  `JNE, `REG_SEL_ALU, `MEM_SEL_NONE, `PC_SEL_1, 0, `SADDR_NONE, 0, 0, 0, "0x0.0 neg");
        check_decode(8'b0000_00_01, `REG_ONLY, `BNOT, `JNE, `REG_SEL_ALU, `MEM_SEL_NONE, `PC_SEL_1, 0, `SADDR_NONE, 0, 0, 0, "0x0.1 bnot");
        check_decode(8'b0000_00_10, `REG_ONLY, `LNOT, `JNE, `REG_SEL_ALU, `MEM_SEL_NONE, `PC_SEL_1, 0, `SADDR_NONE, 0, 0, 0, "0x0.2 lnot");
        check_decode(8'b0000_00_11, `SMP_MOVE, `NEG,  `JNE, `REG_SEL_PC,  `MEM_SEL_NONE, `PC_SEL_1, 0, `SADDR_NONE, 0, 0, 0, "0x0.3 mov pc,rA");

        // ---- icode 0x1: mov %rB,%rA ----
        check_decode(8'b0001_00_00, `SMP_MOVE, `NEG, `JNE, `REG_SEL_REG, `MEM_SEL_NONE, `PC_SEL_1, 0, `SADDR_NONE, 0, 0, 0, "0x1 mov reg,reg");

        // ---- icodes 0x2-0x9: register-form ALU ops ----
        check_decode(8'b0010_00_00, `REG_ONLY, `ADD, `JNE, `REG_SEL_ALU, `MEM_SEL_NONE, `PC_SEL_1, 0, `SADDR_NONE, 0, 0, 0, "0x2 add");
        check_decode(8'b0011_00_00, `REG_ONLY, `SUB, `JNE, `REG_SEL_ALU, `MEM_SEL_NONE, `PC_SEL_1, 0, `SADDR_NONE, 0, 0, 0, "0x3 sub");
        check_decode(8'b0100_00_00, `REG_ONLY, `MUL, `JNE, `REG_SEL_ALU, `MEM_SEL_NONE, `PC_SEL_1, 0, `SADDR_NONE, 0, 0, 0, "0x4 mul");
        check_decode(8'b0101_00_00, `REG_ONLY, `SHL, `JNE, `REG_SEL_ALU, `MEM_SEL_NONE, `PC_SEL_1, 0, `SADDR_NONE, 0, 0, 0, "0x5 shl");
        check_decode(8'b0110_00_00, `REG_ONLY, `SHR, `JNE, `REG_SEL_ALU, `MEM_SEL_NONE, `PC_SEL_1, 0, `SADDR_NONE, 0, 0, 0, "0x6 shr");
        check_decode(8'b0111_00_00, `REG_ONLY, `AND, `JNE, `REG_SEL_ALU, `MEM_SEL_NONE, `PC_SEL_1, 0, `SADDR_NONE, 0, 0, 0, "0x7 and");
        check_decode(8'b1000_00_00, `REG_ONLY, `OR,  `JNE, `REG_SEL_ALU, `MEM_SEL_NONE, `PC_SEL_1, 0, `SADDR_NONE, 0, 0, 0, "0x8 or");
        check_decode(8'b1001_00_00, `REG_ONLY, `XOR, `JNE, `REG_SEL_ALU, `MEM_SEL_NONE, `PC_SEL_1, 0, `SADDR_NONE, 0, 0, 0, "0x9 xor");

        // register fields must not change decode for icodes without subcodes
        check_decode(8'b0010_11_10, `REG_ONLY, `ADD, `JNE, `REG_SEL_ALU, `MEM_SEL_NONE, `PC_SEL_1, 0, `SADDR_NONE, 0, 0, 0, "0x2 add (rA=3, rB=2: fields ignored by decode)");

        // ---- icode 0xA/0xB: single memory move, address from rB ----
        check_decode(8'b1010_00_00, `MEM_MOVE, `NEG, `JNE, `REG_SEL_MEM_SPC, `MEM_SEL_NONE, `PC_SEL_1, 0, `SADDR_RB, 0, 0, 0, "0xA mov (rB),rA");
        check_decode(8'b1011_00_00, `MEM_MOVE, `NEG, `JNE, `REG_SEL_NONE,    `MEM_SEL_REG,  `PC_SEL_1, 0, `SADDR_RB, 0, 0, 0, "0xB mov rA,(rB)");
        check_decode(8'b1011_01_11, `MEM_MOVE, `NEG, `JNE, `REG_SEL_NONE,    `MEM_SEL_REG,  `PC_SEL_1, 0, `SADDR_RB, 0, 0, 0, "0xB mov rA,(rB) (rA=1, rB=3: fields ignored by decode)");

        // ---- icode 0xC: immediate-touching variants ----
        check_decode(8'b1100_00_00, `MEM_MOVE, `NEG, `JNE, `REG_SEL_MEM_IMM, `MEM_SEL_NONE, `PC_SEL_2, 0, `SADDR_NONE, 0, 0, 0, "0xC.0 mov $imm,rA");
        check_decode(8'b1100_00_01, `IMM_OP,   `ADD, `JNE, `REG_SEL_ALU,     `MEM_SEL_NONE, `PC_SEL_2, 1, `SADDR_NONE, 0, 0, 0, "0xC.1 add $imm,rA (alu_source_sel=1)");
        check_decode(8'b1100_00_10, `DBL_MEM,  `NEG, `JNE, `REG_SEL_NONE,    `MEM_SEL_IMM,  `PC_SEL_2, 0, `SADDR_RA,   0, 0, 0, "0xC.2 mov $imm,(rA) (addr from rA)");
        check_decode(8'b1100_00_11, `DBL_MEM,  `NEG, `JNE, `REG_SEL_MEM_SPC, `MEM_SEL_NONE, `PC_SEL_2, 0, `SADDR_MEM,  0, 0, 0, "0xC.3 mov ($imm),rA (addr from M[pc+1])");

        // ---- icode 0xD: branches ----
        check_decode(8'b1101_00_00, `IMM_OP, `NEG, `JGT, `REG_SEL_NONE, `MEM_SEL_NONE, `PC_SEL_IMM, 0, `SADDR_NONE, 1, 0, 0, "0xD.0 jgt");
        check_decode(8'b1101_00_01, `IMM_OP, `NEG, `JLT, `REG_SEL_NONE, `MEM_SEL_NONE, `PC_SEL_IMM, 0, `SADDR_NONE, 1, 0, 0, "0xD.1 jlt");
        check_decode(8'b1101_00_10, `IMM_OP, `NEG, `JE,  `REG_SEL_NONE, `MEM_SEL_NONE, `PC_SEL_IMM, 0, `SADDR_NONE, 1, 0, 0, "0xD.2 je");
        check_decode(8'b1101_00_11, `IMM_OP, `NEG, `JNE, `REG_SEL_NONE, `MEM_SEL_NONE, `PC_SEL_IMM, 0, `SADDR_NONE, 1, 0, 0, "0xD.3 jne");

        // ---- icode 0xE: stack ops ----
        check_decode(8'b1110_00_00, `MEM_MOVE, `NEG, `JNE, `REG_SEL_NONE,    `MEM_SEL_REG,  `PC_SEL_1, 0, `SADDR_NONE, 0, 0, 1, "0xE.0 push reg");
        check_decode(8'b1110_00_01, `DBL_MEM,  `NEG, `JNE, `REG_SEL_NONE,    `MEM_SEL_IMM,  `PC_SEL_2, 0, `SADDR_NONE, 0, 0, 1, "0xE.1 push imm");
        check_decode(8'b1110_00_10, `MEM_MOVE, `NEG, `JNE, `REG_SEL_MEM_RSP, `MEM_SEL_NONE, `PC_SEL_1, 0, `SADDR_NONE, 0, 1, 0, "0xE.2 pop");
        check_decode(8'b1110_00_11, `SMP_MOVE, `NEG, `JNE, `REG_SEL_RSP,     `MEM_SEL_NONE, `PC_SEL_1, 0, `SADDR_NONE, 0, 0, 0, "0xE.3 mov rsp,rA");

        // ---- icode 0xF: jmp / call / ret / halt ----
        check_decode(8'b1111_00_00, `MEM_MOVE, `NEG, `JNE, `REG_SEL_NONE, `MEM_SEL_NONE, `PC_SEL_IMM, 0, `SADDR_NONE, 0, 0, 0, "0xF.0 jmp");
        check_decode(8'b1111_00_01, `DBL_MEM,  `NEG, `JNE, `REG_SEL_NONE, `MEM_SEL_PC2,  `PC_SEL_IMM, 0, `SADDR_NONE, 0, 0, 1, "0xF.1 call");
        check_decode(8'b1111_00_10, `MEM_MOVE, `NEG, `JNE, `REG_SEL_NONE, `MEM_SEL_NONE, `PC_SEL_RSP, 0, `SADDR_NONE, 0, 1, 0, "0xF.2 ret");
        check_decode(8'b1111_00_11, `HALT_OP,  `NEG, `JNE, `REG_SEL_NONE, `MEM_SEL_NONE, `PC_SEL_1,   0, `SADDR_NONE, 0, 0, 0, "0xF.3 halt");

        // ---- register address outputs ----
        check_reg_addr(8'b0010_00_00, "reg_addr: rA=0, rB=0");
        check_reg_addr(8'b0010_01_10, "reg_addr: rA=1, rB=2");
        check_reg_addr(8'b0010_10_01, "reg_addr: rA=2, rB=1");
        check_reg_addr(8'b0010_11_11, "reg_addr: rA=3, rB=3");

        // ---- summary ----
        if (errors == 0)
            $display("\nALL TESTS PASSED");
        else
            $display("\n%0d TEST(S) FAILED", errors);

        $finish;
    end

endmodule
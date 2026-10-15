`timescale 1ns/1ps
`include "control_unit_defines.vh"

module control_unit_full_tb;

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
        .pc_ena(pc_ena)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, control_unit_full_tb);
    end

    // steps one clock edge, then checks FSM state plus every enable signal in one shot
    task check_step;
        input [5:0] exp_state;
        input exp_write_ena;
        input exp_special_write_ena;
        input exp_rsp_write_ena;
        input exp_rsp_inc;
        input exp_rsp_dec;
        input exp_pc_ena;
        input exp_branch_gate_ena;
        input [255:0] label;
        reg fail;
        begin
            @(posedge clk);
            #1;
            fail = 0;

            if (uut.state !== exp_state) begin
                $display("  FAIL[%0s]: state expected %b got %b", label, exp_state, uut.state);
                fail = 1;
            end
            if (write_ena !== exp_write_ena) begin
                $display("  FAIL[%0s]: write_ena expected %b got %b", label, exp_write_ena, write_ena);
                fail = 1;
            end
            if (special_write_ena !== exp_special_write_ena) begin
                $display("  FAIL[%0s]: special_write_ena expected %b got %b", label, exp_special_write_ena, special_write_ena);
                fail = 1;
            end
            if (rsp_write_ena !== exp_rsp_write_ena) begin
                $display("  FAIL[%0s]: rsp_write_ena expected %b got %b", label, exp_rsp_write_ena, rsp_write_ena);
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
            if (pc_ena !== exp_pc_ena) begin
                $display("  FAIL[%0s]: pc_ena expected %b got %b", label, exp_pc_ena, pc_ena);
                fail = 1;
            end
            if (branch_gate_ena !== exp_branch_gate_ena) begin
                $display("  FAIL[%0s]: branch_gate_ena expected %b got %b", label, exp_branch_gate_ena, branch_gate_ena);
                fail = 1;
            end

            if (fail)
                errors = errors + 1;
            else
                $display("PASS: %0s", label);
        end
    endtask

    // starts a fresh instruction: waits for a negedge, loads mem_pc, and consumes the FETCH cycle
    task start_instruction;
        input [7:0] ir_val;
        input [255:0] label;
        begin
            @(negedge clk);
            mem_pc = ir_val;
            check_step(`DECODE, 0,0,0,0,0,0,0, {label, ": FETCH->DECODE"});
        end
    endtask

    initial begin
        clk = 0;
        reset = 1;
        mem_pc = 8'h00;

        @(posedge clk);
        #1;
        reset = 0;

        // =========================================================
        // 1) REG_ONLY: 0x2 add %rB,%rA  -> F D E W
        // =========================================================
        start_instruction(8'h20, "add");
        check_step(`EXECUTE,   0,0,0,0,0,0,0, "add: DECODE->EXECUTE");
        check_step(`WRITEBACK, 1,0,0,0,0,1,0, "add: EXECUTE->WRITEBACK (write_ena+pc_ena)");
        check_step(`FETCH,     0,0,0,0,0,0,0, "add: WRITEBACK->FETCH");

        // =========================================================
        // 2) SMP_MOVE: 0x1 mov %rB,%rA  -> F D W
        // =========================================================
        start_instruction(8'h10, "mov reg,reg");
        check_step(`WRITEBACK, 1,0,0,0,0,1,0, "mov reg,reg: DECODE->WRITEBACK (write_ena+pc_ena)");
        check_step(`FETCH,     0,0,0,0,0,0,0, "mov reg,reg: WRITEBACK->FETCH");

        // =========================================================
        // 3) IMM_OP (ALU): 0xC.1 add $imm,%rA  -> F D M1 E W
        // =========================================================
        start_instruction(8'hC1, "add imm");
        check_step(`MEM1,      0,0,0,0,0,0,0, "add imm: DECODE->MEM1");
        check_step(`EXECUTE,   0,0,0,0,0,0,0, "add imm: MEM1->EXECUTE");
        check_step(`WRITEBACK, 1,0,0,0,0,1,0, "add imm: EXECUTE->WRITEBACK (write_ena+pc_ena)");
        check_step(`FETCH,     0,0,0,0,0,0,0, "add imm: WRITEBACK->FETCH");

        // =========================================================
        // 4) IMM_OP (branch): 0xD.0 jgt  -> F D M1 E W
        //    branches never write a register - write_ena stays 0 throughout
        //    branch_gate_ena asserts from DECODE onward
        // =========================================================
        @(negedge clk);
        mem_pc = 8'hD0;
        check_step(`DECODE,   0,0,0,0,0,0,1, "jgt: FETCH->DECODE (branch_gate_ena asserts as soon as ir latches)");
        check_step(`MEM1,      0,0,0,0,0,0,1, "jgt: DECODE->MEM1 (branch_gate_ena)");
        check_step(`EXECUTE,   0,0,0,0,0,0,1, "jgt: MEM1->EXECUTE (branch_gate_ena)");
        check_step(`WRITEBACK, 0,0,0,0,0,1,1, "jgt: EXECUTE->WRITEBACK (pc_ena, no write_ena, branch_gate_ena)");
        check_step(`FETCH,     0,0,0,0,0,0,1, "jgt: WRITEBACK->FETCH (branch_gate_ena still reflects ir, not yet re-latched)");

        // =========================================================
        // 5) MEM_MOVE (read): 0xA mov (%rB),%rA  -> F D M1 W
        // =========================================================
        start_instruction(8'hA0, "mov (rB),rA");
        check_step(`MEM1,      0,0,0,0,0,0,0, "mov (rB),rA: DECODE->MEM1");
        check_step(`WRITEBACK, 1,0,0,0,0,1,0, "mov (rB),rA: MEM1->WRITEBACK (write_ena+pc_ena)");
        check_step(`FETCH,     0,0,0,0,0,0,0, "mov (rB),rA: WRITEBACK->FETCH");

        // =========================================================
        // 6) MEM_MOVE (write): 0xB mov %rA,(%rB)  -> F D M1 W
        //    special_write_ena fires at MEM1, never write_ena
        // =========================================================
        start_instruction(8'hB0, "mov rA,(rB)");
        check_step(`MEM1,      0,1,0,0,0,0,0, "mov rA,(rB): DECODE->MEM1 (special_write_ena)");
        check_step(`WRITEBACK, 0,0,0,0,0,1,0, "mov rA,(rB): MEM1->WRITEBACK (pc_ena, no write_ena)");
        check_step(`FETCH,     0,0,0,0,0,0,0, "mov rA,(rB): WRITEBACK->FETCH");

        // =========================================================
        // 7) MEM_MOVE (immediate load): 0xC.0 mov $imm,%rA  -> F D M1 W
        // =========================================================
        start_instruction(8'hC0, "mov imm,rA");
        check_step(`MEM1,      0,0,0,0,0,0,0, "mov imm,rA: DECODE->MEM1");
        check_step(`WRITEBACK, 1,0,0,0,0,1,0, "mov imm,rA: MEM1->WRITEBACK (write_ena+pc_ena)");
        check_step(`FETCH,     0,0,0,0,0,0,0, "mov imm,rA: WRITEBACK->FETCH");

        // =========================================================
        // 8) DBL_MEM (write): 0xC.2 mov $imm,(%rA)  -> F D M1 M2 W
        //    special_write_ena fires at MEM2, never write_ena
        // =========================================================
        start_instruction(8'hC2, "mov imm,(rA)");
        check_step(`MEM1,      0,0,0,0,0,0,0, "mov imm,(rA): DECODE->MEM1");
        check_step(`MEM2,      0,1,0,0,0,0,0, "mov imm,(rA): MEM1->MEM2 (special_write_ena)");
        check_step(`WRITEBACK, 0,0,0,0,0,1,0, "mov imm,(rA): MEM2->WRITEBACK (pc_ena, no write_ena)");
        check_step(`FETCH,     0,0,0,0,0,0,0, "mov imm,(rA): WRITEBACK->FETCH");

        // =========================================================
        // 9) DBL_MEM (read): 0xC.3 mov ($imm),%rA  -> F D M1 M2 W
        // =========================================================
        start_instruction(8'hC3, "mov (imm),rA");
        check_step(`MEM1,      0,0,0,0,0,0,0, "mov (imm),rA: DECODE->MEM1");
        check_step(`MEM2,      0,0,0,0,0,0,0, "mov (imm),rA: MEM1->MEM2");
        check_step(`WRITEBACK, 1,0,0,0,0,1,0, "mov (imm),rA: MEM2->WRITEBACK (write_ena+pc_ena)");
        check_step(`FETCH,     0,0,0,0,0,0,0, "mov (imm),rA: WRITEBACK->FETCH");

        // =========================================================
        // 10) push %rA: 0xE.0  -> F D M1 W
        //     rsp_write_ena + rsp_dec fire together at MEM1
        // =========================================================
        start_instruction(8'hE0, "push reg");
        check_step(`MEM1,      0,0,1,0,1,0,0, "push reg: DECODE->MEM1 (rsp_write_ena+rsp_dec)");
        check_step(`WRITEBACK, 0,0,0,0,0,1,0, "push reg: MEM1->WRITEBACK (pc_ena, no write_ena)");
        check_step(`FETCH,     0,0,0,0,0,0,0, "push reg: WRITEBACK->FETCH");

        // =========================================================
        // 11) push $imm: 0xE.1  -> F D M1 M2 W
        //     rsp_write_ena + rsp_dec fire together at MEM2, not MEM1
        // =========================================================
        start_instruction(8'hE1, "push imm");
        check_step(`MEM1,      0,0,0,0,0,0,0, "push imm: DECODE->MEM1");
        check_step(`MEM2,      0,0,1,0,1,0,0, "push imm: MEM1->MEM2 (rsp_write_ena+rsp_dec)");
        check_step(`WRITEBACK, 0,0,0,0,0,1,0, "push imm: MEM2->WRITEBACK (pc_ena, no write_ena)");
        check_step(`FETCH,     0,0,0,0,0,0,0, "push imm: WRITEBACK->FETCH");

        // =========================================================
        // 12) pop %rA: 0xE.2  -> F D M1 W
        //     rsp_inc fires at MEM1; write_ena fires later at WRITEBACK
        //     NOTE: see write-up after this file regarding a possible
        //     ordering issue between rsp_inc (MEM1) and the register
        //     write reading mem_rsp (WRITEBACK) - flagged separately.
        // =========================================================
        start_instruction(8'hE2, "pop");
        check_step(`MEM1,      0,0,0,1,0,0,0, "pop: DECODE->MEM1 (rsp_inc)");
        check_step(`WRITEBACK, 1,0,0,0,0,1,0, "pop: MEM1->WRITEBACK (write_ena+pc_ena)");
        check_step(`FETCH,     0,0,0,0,0,0,0, "pop: WRITEBACK->FETCH");

        // =========================================================
        // 13) mov rsp,%rA: 0xE.3  -> F D W
        // =========================================================
        start_instruction(8'hE3, "mov rsp,rA");
        check_step(`WRITEBACK, 1,0,0,0,0,1,0, "mov rsp,rA: DECODE->WRITEBACK (write_ena+pc_ena)");
        check_step(`FETCH,     0,0,0,0,0,0,0, "mov rsp,rA: WRITEBACK->FETCH");

        // =========================================================
        // 14) jmp: 0xF.0  -> F D M1 W
        //     no register write, no memory write - just pc_inc_sel routing (untested here)
        // =========================================================
        start_instruction(8'hF0, "jmp");
        check_step(`MEM1,      0,0,0,0,0,0,0, "jmp: DECODE->MEM1");
        check_step(`WRITEBACK, 0,0,0,0,0,1,0, "jmp: MEM1->WRITEBACK (pc_ena only)");
        check_step(`FETCH,     0,0,0,0,0,0,0, "jmp: WRITEBACK->FETCH");

        // =========================================================
        // 15) call: 0xF.1  -> F D M1 M2 W
        //     rsp_write_ena + rsp_dec fire together at MEM2
        // =========================================================
        start_instruction(8'hF1, "call");
        check_step(`MEM1,      0,0,0,0,0,0,0, "call: DECODE->MEM1");
        check_step(`MEM2,      0,0,1,0,1,0,0, "call: MEM1->MEM2 (rsp_write_ena+rsp_dec)");
        check_step(`WRITEBACK, 0,0,0,0,0,1,0, "call: MEM2->WRITEBACK (pc_ena only)");
        check_step(`FETCH,     0,0,0,0,0,0,0, "call: WRITEBACK->FETCH");

        // =========================================================
        // 16) ret: 0xF.2  -> F D M1 W
        //     rsp_inc fires at MEM1; ret never writes a register
        // =========================================================
        start_instruction(8'hF2, "ret");
        check_step(`MEM1,      0,0,0,1,0,0,0, "ret: DECODE->MEM1 (rsp_inc)");
        check_step(`WRITEBACK, 0,0,0,0,0,1,0, "ret: MEM1->WRITEBACK (pc_ena only)");
        check_step(`FETCH,     0,0,0,0,0,0,0, "ret: WRITEBACK->FETCH");

        // =========================================================
        // 17) halt: 0xF.3  -> F D W
        //     halt handling not yet implemented - this documents
        //     CURRENT (pre-halt-fix) behavior: pc_ena still fires normally
        // =========================================================
        start_instruction(8'hF3, "halt");
        check_step(`WRITEBACK, 0,0,0,0,0,1,0, "halt: DECODE->WRITEBACK (pc_ena, no write_ena) [pre-halt-fix]");
        check_step(`FETCH,     0,0,0,0,0,0,0, "halt: WRITEBACK->FETCH [pre-halt-fix]");

        // ---- summary ----
        if (errors == 0)
            $display("\nALL TESTS PASSED");
        else
            $display("\n%0d TEST(S) FAILED", errors);

        $finish;
    end

endmodule
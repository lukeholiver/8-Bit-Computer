`timescale 1ns/1ps
`include "control_unit_defines.vh"

module control_unit_fsm_tb;

    reg clk;
    reg reset;
    reg [7:0] mem_pc;

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
        .mem_pc(mem_pc),
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
        $dumpvars(0, control_unit_fsm_tb);
    end

    task check_state;
        input [5:0] expected;
        input [191:0] label;
        begin
            if (uut.state !== expected) begin
                $display("FAIL: %0s - expected state %b, got %b", label, expected, uut.state);
                errors = errors + 1;
            end
            else
                $display("PASS: %0s - state = %b", label, uut.state);
        end
    endtask

    task check_ir;
        input [7:0] expected;
        input [191:0] label;
        begin
            if (uut.ir !== expected) begin
                $display("FAIL: %0s - expected ir %h, got %h", label, expected, uut.ir);
                errors = errors + 1;
            end
            else
                $display("PASS: %0s - ir = %h", label, uut.ir);
        end
    endtask

    // steps one clock edge, waits for combinational settle, then checks state
    task step_and_check;
        input [5:0] expected;
        input [191:0] label;
        begin
            @(posedge clk);
            #1;
            check_state(expected, label);
        end
    endtask

    initial begin
        clk = 0;
        reset = 1;
        mem_pc = 8'h00;

        // ---- reset behavior ----
        @(posedge clk);
        #1;
        check_state(`FETCH, "reset: state = FETCH");

        // ================= REG_ONLY: 0x2 (add %rB,%rA) =================
        @(negedge clk);
        reset = 0;
        mem_pc = 8'h20; // icode 0x2, rA=00, rB=00 - set in the same negedge as clearing reset
        step_and_check(`DECODE, "REG_ONLY: FETCH -> DECODE");
        check_ir(8'h20, "REG_ONLY: ir latched correctly");
        step_and_check(`EXECUTE,  "REG_ONLY: DECODE -> EXECUTE");
        step_and_check(`WRITEBACK,"REG_ONLY: EXECUTE -> WRITEBACK");
        step_and_check(`FETCH,    "REG_ONLY: WRITEBACK -> FETCH");

        // ================= SMP_MOVE: 0x1 (mov %rB,%rA) =================
        @(negedge clk);
        mem_pc = 8'h10; // icode 0x1
        step_and_check(`DECODE, "SMP_MOVE: FETCH -> DECODE");
        check_ir(8'h10, "SMP_MOVE: ir latched correctly");
        step_and_check(`WRITEBACK,"SMP_MOVE: DECODE -> WRITEBACK");
        step_and_check(`FETCH,    "SMP_MOVE: WRITEBACK -> FETCH");

        // ================= IMM_OP: 0xC.1 (add $imm,%rA) =================
        @(negedge clk);
        mem_pc = 8'hC1; // icode 0xC, rB=01
        step_and_check(`DECODE, "IMM_OP: FETCH -> DECODE");
        check_ir(8'hC1, "IMM_OP: ir latched correctly");
        step_and_check(`MEM1,     "IMM_OP: DECODE -> MEM1");
        step_and_check(`EXECUTE,  "IMM_OP: MEM1 -> EXECUTE");
        step_and_check(`WRITEBACK,"IMM_OP: EXECUTE -> WRITEBACK");
        step_and_check(`FETCH,    "IMM_OP: WRITEBACK -> FETCH");

        // ================= MEM_MOVE: 0xA (mov (%rB),%rA) =================
        @(negedge clk);
        mem_pc = 8'hA0; // icode 0xA
        step_and_check(`DECODE, "MEM_MOVE: FETCH -> DECODE");
        check_ir(8'hA0, "MEM_MOVE: ir latched correctly");
        step_and_check(`MEM1,     "MEM_MOVE: DECODE -> MEM1");
        step_and_check(`WRITEBACK,"MEM_MOVE: MEM1 -> WRITEBACK");
        step_and_check(`FETCH,    "MEM_MOVE: WRITEBACK -> FETCH");

        // ================= DBL_MEM: 0xC.2 (mov $imm,(%rA)) =================
        @(negedge clk);
        mem_pc = 8'hC2; // icode 0xC, rB=10
        step_and_check(`DECODE, "DBL_MEM: FETCH -> DECODE");
        check_ir(8'hC2, "DBL_MEM: ir latched correctly");
        step_and_check(`MEM1,     "DBL_MEM: DECODE -> MEM1");
        step_and_check(`MEM2,     "DBL_MEM: MEM1 -> MEM2");
        step_and_check(`WRITEBACK,"DBL_MEM: MEM2 -> WRITEBACK");
        step_and_check(`FETCH,    "DBL_MEM: WRITEBACK -> FETCH");

        // ---- summary ----
        if (errors == 0)
            $display("\nALL TESTS PASSED");
        else
            $display("\n%0d TEST(S) FAILED", errors);

        $finish;
    end

endmodule
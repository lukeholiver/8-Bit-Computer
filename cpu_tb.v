`timescale 1ns/1ps
`include "control_unit_defines.vh"

module cpu_tb;

    reg clk;
    reg reset;

    integer pass_count;
    integer fail_count;

    // ---------------------------------------------------------------
    // DUT
    // ---------------------------------------------------------------
    cpu dut (
        .clk    (clk),
        .reset  (reset)
    );

    // clock: 10ns period
    initial clk = 0;
    always #5 clk = ~clk;

    // ---------------------------------------------------------------
    // Instruction encoding helper: {icode, fieldA, fieldB}
    // fieldA/fieldB mean rA/rB, or (icode, subcode-carrying-field) for
    // icodes 0/C/D/E/F where one field selects a sub-operation instead
    // of naming a register. Matches the icode table in the README.
    // ---------------------------------------------------------------
    function [7:0] enc;
        input [3:0] icode;
        input [1:0] a;
        input [1:0] b;
        begin
            enc = {icode, a, b};
        end
    endfunction

    // ---------------------------------------------------------------
    // Memory setup helpers (hierarchical pokes - testbench only, not
    // meant to model UART loading; that's a separate future milestone)
    // ---------------------------------------------------------------
    task clear_memory;
        integer j;
        begin
            for (j = 0; j < 256; j = j + 1)
                dut.memory.memory_file[j] = 8'h00;
        end
    endtask

    task poke;
        input [7:0] addr;
        input [7:0] data;
        begin
            dut.memory.memory_file[addr] = data;
        end
    endtask

    // ---------------------------------------------------------------
    // Reset
    // ---------------------------------------------------------------
    task do_reset;
        begin
            reset = 1;
            @(posedge clk);
            @(posedge clk);
            reset = 0;
        end
    endtask

    // ---------------------------------------------------------------
    // Run exactly one instruction to completion.
    // Waits for the FSM to reach WRITEBACK, then advances one more
    // edge so the writeback (register/memory/pc/rsp update) commits
    // and the FSM returns to FETCH. Watchdog guards against hangs.
    // ---------------------------------------------------------------
    task run_one;
        integer timeout;
        begin
            timeout = 0;
            while (dut.control_unit.state !== `WRITEBACK && timeout < 50) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            if (timeout >= 50) begin
                $display("FATAL: instruction never reached WRITEBACK (possible FSM hang) - aborting");
                $finish;
            end
            @(posedge clk); // commit writeback, FSM returns to FETCH
        end
    endtask

    task run_n;
        input integer n;
        integer k;
        begin
            for (k = 0; k < n; k = k + 1)
                run_one;
        end
    endtask

    // ---------------------------------------------------------------
    // Pass/fail checking
    // ---------------------------------------------------------------
    task check;
        input [8*48:1] name;
        input [7:0] actual;
        input [7:0] expected;
        begin
            if (actual === expected) begin
                pass_count = pass_count + 1;
                $display("  PASS: %0s (0x%02h)", name, actual);
            end else begin
                fail_count = fail_count + 1;
                $display("  FAIL: %0s -- expected 0x%02h, got 0x%02h", name, expected, actual);
            end
        end
    endtask

    task note;
        input [8*80:1] msg;
        begin
            $display("  NOTE: %0s", msg);
        end
    endtask

    // convenience read wrappers (purely for readability at call sites)
    function [7:0] reg_val;
        input [1:0] idx;
        reg_val = dut.register_file.reg_file[idx];
    endfunction

    function [7:0] mem_val;
        input [7:0] addr;
        mem_val = dut.memory.memory_file[addr];
    endfunction

    function [7:0] pc_val;
        pc_val = dut.control_registers.pc;
    endfunction

    function [7:0] rsp_val;
        rsp_val = dut.control_registers.rsp;
    endfunction

    // =================================================================
    // MAIN TEST SEQUENCE
    // =================================================================
    initial begin
        pass_count = 0;
        fail_count = 0;
        reset = 1;

        $dumpfile("cpu_tb.vcd");
        $dumpvars(0, cpu_tb);

        // -------------------------------------------------------
        // GROUP A: icode 0x0 (neg / bnot / lnot / mov pc,%rA)
        // -------------------------------------------------------
        $display("\n=== GROUP A: icode 0x0 sub-ops ===");

        clear_memory;
        poke(8'h00, enc(4'hC, 2'd0, 2'd0)); poke(8'h01, 8'h05); // mov $05,%r0
        poke(8'h02, enc(4'h0, 2'd0, 2'd0));                     // neg %r0
        do_reset; run_n(2);
        check("neg %r0 (5 -> -5)", reg_val(0), 8'hFB);

        clear_memory;
        poke(8'h00, enc(4'hC, 2'd1, 2'd0)); poke(8'h01, 8'h0F); // mov $0F,%r1
        poke(8'h02, enc(4'h0, 2'd1, 2'd1));                     // bnot %r1
        do_reset; run_n(2);
        check("bnot %r1 (0x0F -> 0xF0)", reg_val(1), 8'hF0);

        clear_memory;
        poke(8'h00, enc(4'hC, 2'd2, 2'd0)); poke(8'h01, 8'h00); // mov $00,%r2
        poke(8'h02, enc(4'h0, 2'd2, 2'd2));                     // lnot %r2
        do_reset; run_n(2);
        check("lnot %r2 (0 -> 1)", reg_val(2), 8'h01);

        clear_memory;
        poke(8'h00, enc(4'hC, 2'd2, 2'd0)); poke(8'h01, 8'h05); // mov $05,%r2
        poke(8'h02, enc(4'h0, 2'd2, 2'd2));                     // lnot %r2
        do_reset; run_n(2);
        check("lnot %r2 (5 -> 0)", reg_val(2), 8'h00);

        clear_memory;
        poke(8'h00, enc(4'h0, 2'd3, 2'd3));                     // mov pc,%r3 (first instr, addr 0)
        do_reset; run_n(1);
        check("mov pc,%r3 (addr 0x00)", reg_val(3), 8'h00);

        // -------------------------------------------------------
        // GROUP B: icode 0x1 (mov %rB,%rA)
        // -------------------------------------------------------
        $display("\n=== GROUP B: icode 0x1 mov reg,reg ===");

        clear_memory;
        poke(8'h00, enc(4'hC, 2'd0, 2'd0)); poke(8'h01, 8'h42); // mov $42,%r0
        poke(8'h02, enc(4'h1, 2'd1, 2'd0));                     // mov %r0,%r1
        do_reset; run_n(2);
        check("mov %r0,%r1 dest", reg_val(1), 8'h42);
        check("mov %r0,%r1 src unchanged", reg_val(0), 8'h42);

        // -------------------------------------------------------
        // GROUP C: icode 0x2-0x9 (reg-reg ALU ops)
        // -------------------------------------------------------
        $display("\n=== GROUP C: reg-reg ALU ops ===");

        clear_memory;
        poke(8'h00, enc(4'hC, 2'd0, 2'd0)); poke(8'h01, 8'h10); // mov $10,%r0
        poke(8'h02, enc(4'hC, 2'd1, 2'd0)); poke(8'h03, 8'h05); // mov $05,%r1
        poke(8'h04, enc(4'h2, 2'd0, 2'd1));                     // add %r1,%r0
        do_reset; run_n(3);
        check("add %r1,%r0 (0x10+0x05)", reg_val(0), 8'h15);

        clear_memory;
        poke(8'h00, enc(4'hC, 2'd0, 2'd0)); poke(8'h01, 8'hFF); // mov $FF,%r0
        poke(8'h02, enc(4'hC, 2'd1, 2'd0)); poke(8'h03, 8'h01); // mov $01,%r1
        poke(8'h04, enc(4'h2, 2'd0, 2'd1));                     // add %r1,%r0
        do_reset; run_n(3);
        check("add overflow (0xFF+0x01 wraps)", reg_val(0), 8'h00);

        clear_memory;
        poke(8'h00, enc(4'hC, 2'd0, 2'd0)); poke(8'h01, 8'h0A); // mov $0A,%r0
        poke(8'h02, enc(4'hC, 2'd1, 2'd0)); poke(8'h03, 8'h03); // mov $03,%r1
        poke(8'h04, enc(4'h3, 2'd0, 2'd1));                     // sub %r1,%r0
        do_reset; run_n(3);
        check("sub %r1,%r0 (0x0A-0x03)", reg_val(0), 8'h07);

        clear_memory;
        poke(8'h00, enc(4'hC, 2'd0, 2'd0)); poke(8'h01, 8'h00); // mov $00,%r0
        poke(8'h02, enc(4'hC, 2'd1, 2'd0)); poke(8'h03, 8'h01); // mov $01,%r1
        poke(8'h04, enc(4'h3, 2'd0, 2'd1));                     // sub %r1,%r0
        do_reset; run_n(3);
        check("sub underflow (0x00-0x01 wraps)", reg_val(0), 8'hFF);

        clear_memory;
        poke(8'h00, enc(4'hC, 2'd0, 2'd0)); poke(8'h01, 8'h06); // mov $06,%r0
        poke(8'h02, enc(4'hC, 2'd1, 2'd0)); poke(8'h03, 8'h07); // mov $07,%r1
        poke(8'h04, enc(4'h4, 2'd0, 2'd1));                     // mul %r1,%r0
        do_reset; run_n(3);
        check("mul %r1,%r0 (6*7)", reg_val(0), 8'h2A);

        clear_memory;
        poke(8'h00, enc(4'hC, 2'd0, 2'd0)); poke(8'h01, 8'h10); // mov $10,%r0
        poke(8'h02, enc(4'hC, 2'd1, 2'd0)); poke(8'h03, 8'h10); // mov $10,%r1
        poke(8'h04, enc(4'h4, 2'd0, 2'd1));                     // mul %r1,%r0
        do_reset; run_n(3);
        check("mul truncation (0x10*0x10 -> low byte)", reg_val(0), 8'h00);

        clear_memory;
        poke(8'h00, enc(4'hC, 2'd0, 2'd0)); poke(8'h01, 8'h01); // mov $01,%r0
        poke(8'h02, enc(4'hC, 2'd1, 2'd0)); poke(8'h03, 8'h03); // mov $03,%r1
        poke(8'h04, enc(4'h5, 2'd0, 2'd1));                     // shl %r1,%r0
        do_reset; run_n(3);
        check("shl %r1,%r0 (1<<3)", reg_val(0), 8'h08);

        clear_memory;
        poke(8'h00, enc(4'hC, 2'd0, 2'd0)); poke(8'h01, 8'h01); // mov $01,%r0
        poke(8'h02, enc(4'hC, 2'd1, 2'd0)); poke(8'h03, 8'h09); // mov $09,%r1 (masks to 1)
        poke(8'h04, enc(4'h5, 2'd0, 2'd1));                     // shl %r1,%r0
        do_reset; run_n(3);
        check("shl shift-amt masked (9&7=1)", reg_val(0), 8'h02);

        clear_memory;
        poke(8'h00, enc(4'hC, 2'd0, 2'd0)); poke(8'h01, 8'h80); // mov $80,%r0
        poke(8'h02, enc(4'hC, 2'd1, 2'd0)); poke(8'h03, 8'h04); // mov $04,%r1
        poke(8'h04, enc(4'h6, 2'd0, 2'd1));                     // shr %r1,%r0
        do_reset; run_n(3);
        check("shr %r1,%r0 (0x80>>4)", reg_val(0), 8'h08);

        clear_memory;
        poke(8'h00, enc(4'hC, 2'd0, 2'd0)); poke(8'h01, 8'h80); // mov $80,%r0
        poke(8'h02, enc(4'hC, 2'd1, 2'd0)); poke(8'h03, 8'h0B); // mov $0B,%r1 (masks to 3)
        poke(8'h04, enc(4'h6, 2'd0, 2'd1));                     // shr %r1,%r0
        do_reset; run_n(3);
        check("shr shift-amt masked (0x0B&7=3)", reg_val(0), 8'h10);

        clear_memory;
        poke(8'h00, enc(4'hC, 2'd0, 2'd0)); poke(8'h01, 8'hF0); // mov $F0,%r0
        poke(8'h02, enc(4'hC, 2'd1, 2'd0)); poke(8'h03, 8'h3C); // mov $3C,%r1
        poke(8'h04, enc(4'h7, 2'd0, 2'd1));                     // and %r1,%r0
        do_reset; run_n(3);
        check("and %r1,%r0", reg_val(0), 8'h30);

        clear_memory;
        poke(8'h00, enc(4'hC, 2'd0, 2'd0)); poke(8'h01, 8'hF0); // mov $F0,%r0
        poke(8'h02, enc(4'hC, 2'd1, 2'd0)); poke(8'h03, 8'h0F); // mov $0F,%r1
        poke(8'h04, enc(4'h8, 2'd0, 2'd1));                     // or %r1,%r0
        do_reset; run_n(3);
        check("or %r1,%r0", reg_val(0), 8'hFF);

        clear_memory;
        poke(8'h00, enc(4'hC, 2'd0, 2'd0)); poke(8'h01, 8'hFF); // mov $FF,%r0
        poke(8'h02, enc(4'hC, 2'd1, 2'd0)); poke(8'h03, 8'h0F); // mov $0F,%r1
        poke(8'h04, enc(4'h9, 2'd0, 2'd1));                     // xor %r1,%r0
        do_reset; run_n(3);
        check("xor %r1,%r0", reg_val(0), 8'hF0);

        // -------------------------------------------------------
        // GROUP D: icode 0xA / 0xB (reg-indirect memory move)
        // -------------------------------------------------------
        $display("\n=== GROUP D: reg-indirect memory (icode 0xA/0xB) ===");

        clear_memory;
        poke(8'h00, enc(4'hC, 2'd1, 2'd0)); poke(8'h01, 8'h50); // mov $50,%r1 (address)
        poke(8'h02, enc(4'hC, 2'd0, 2'd0)); poke(8'h03, 8'h99); // mov $99,%r0 (data)
        poke(8'h04, enc(4'hB, 2'd0, 2'd1));                     // mov %r0,(%r1)
        poke(8'h05, enc(4'hA, 2'd2, 2'd1));                     // mov (%r1),%r2
        do_reset; run_n(4);
        check("mem[0x50] after store", mem_val(8'h50), 8'h99);
        check("mov (%r1),%r2 load-back", reg_val(2), 8'h99);

        // -------------------------------------------------------
        // GROUP E: icode 0xC (immediate group)
        // -------------------------------------------------------
        $display("\n=== GROUP E: immediate group (icode 0xC) ===");

        clear_memory;
        poke(8'h00, enc(4'hC, 2'd0, 2'd0)); poke(8'h01, 8'h7A); // mov $7A,%r0
        do_reset; run_n(1);
        check("mov $7A,%r0", reg_val(0), 8'h7A);
        check("pc advances by 2 for imm instr", pc_val(), 8'h02);

        clear_memory;
        poke(8'h00, enc(4'hC, 2'd0, 2'd0)); poke(8'h01, 8'h10); // mov $10,%r0
        poke(8'h02, enc(4'hC, 2'd0, 2'd1)); poke(8'h03, 8'h05); // add $05,%r0
        do_reset; run_n(2);
        check("add $05,%r0", reg_val(0), 8'h15);

        clear_memory;
        poke(8'h00, enc(4'hC, 2'd1, 2'd0)); poke(8'h01, 8'h60); // mov $60,%r1 (address)
        poke(8'h02, enc(4'hC, 2'd1, 2'd2)); poke(8'h03, 8'h77); // mov $77,(%r1)
        poke(8'h04, enc(4'hC, 2'd2, 2'd3)); poke(8'h05, 8'h60); // mov ($60),%r2
        do_reset; run_n(3);
        check("mem[0x60] after mov $77,(%r1)", mem_val(8'h60), 8'h77);
        check("mov ($60),%r2 indirect load", reg_val(2), 8'h77);

        // -------------------------------------------------------
        // GROUP F: icode 0xD (branches) - taken and not-taken
        // -------------------------------------------------------
        $display("\n=== GROUP F: branches (icode 0xD) ===");

        // jgt taken (r0 > 0)
        clear_memory;
        poke(8'h00, enc(4'hC, 2'd0, 2'd0)); poke(8'h01, 8'h01); // mov $01,%r0
        poke(8'h02, enc(4'hD, 2'd0, 2'd0)); poke(8'h03, 8'h10); // jgt %r0,$10
        poke(8'h04, enc(4'hC, 2'd3, 2'd0)); poke(8'h05, 8'hBB); // (skip) mov $BB,%r3
        poke(8'h10, enc(4'hC, 2'd3, 2'd0)); poke(8'h11, 8'hAA); // (target) mov $AA,%r3
        do_reset; run_n(3);
        check("jgt taken -> lands at target", reg_val(3), 8'hAA);
        check("jgt taken -> pc after landed instr", pc_val(), 8'h12);

        // jgt not taken (r0 == 0)
        clear_memory;
        poke(8'h00, enc(4'hC, 2'd0, 2'd0)); poke(8'h01, 8'h00); // mov $00,%r0
        poke(8'h02, enc(4'hD, 2'd0, 2'd0)); poke(8'h03, 8'h10); // jgt %r0,$10
        poke(8'h04, enc(4'hC, 2'd3, 2'd0)); poke(8'h05, 8'hBB); // (fallthrough) mov $BB,%r3
        poke(8'h10, enc(4'hC, 2'd3, 2'd0)); poke(8'h11, 8'hAA); // (not reached)
        do_reset; run_n(3);
        check("jgt not taken -> falls through", reg_val(3), 8'hBB);

        // jlt taken (r0 negative, e.g. 0xFF = -1)
        clear_memory;
        poke(8'h00, enc(4'hC, 2'd0, 2'd0)); poke(8'h01, 8'hFF); // mov $FF,%r0
        poke(8'h02, enc(4'hD, 2'd0, 2'd1)); poke(8'h03, 8'h10); // jlt %r0,$10
        poke(8'h04, enc(4'hC, 2'd3, 2'd0)); poke(8'h05, 8'hBB);
        poke(8'h10, enc(4'hC, 2'd3, 2'd0)); poke(8'h11, 8'hAA);
        do_reset; run_n(3);
        check("jlt taken (negative rA)", reg_val(3), 8'hAA);

        // jlt not taken (r0 positive)
        clear_memory;
        poke(8'h00, enc(4'hC, 2'd0, 2'd0)); poke(8'h01, 8'h01); // mov $01,%r0
        poke(8'h02, enc(4'hD, 2'd0, 2'd1)); poke(8'h03, 8'h10); // jlt %r0,$10
        poke(8'h04, enc(4'hC, 2'd3, 2'd0)); poke(8'h05, 8'hBB);
        poke(8'h10, enc(4'hC, 2'd3, 2'd0)); poke(8'h11, 8'hAA);
        do_reset; run_n(3);
        check("jlt not taken (positive rA)", reg_val(3), 8'hBB);

        // je taken (r0 == 0)
        clear_memory;
        poke(8'h00, enc(4'hC, 2'd0, 2'd0)); poke(8'h01, 8'h00); // mov $00,%r0
        poke(8'h02, enc(4'hD, 2'd0, 2'd2)); poke(8'h03, 8'h10); // je %r0,$10
        poke(8'h04, enc(4'hC, 2'd3, 2'd0)); poke(8'h05, 8'hBB);
        poke(8'h10, enc(4'hC, 2'd3, 2'd0)); poke(8'h11, 8'hAA);
        do_reset; run_n(3);
        check("je taken (rA==0)", reg_val(3), 8'hAA);

        // je not taken (r0 != 0)
        clear_memory;
        poke(8'h00, enc(4'hC, 2'd0, 2'd0)); poke(8'h01, 8'h05); // mov $05,%r0
        poke(8'h02, enc(4'hD, 2'd0, 2'd2)); poke(8'h03, 8'h10); // je %r0,$10
        poke(8'h04, enc(4'hC, 2'd3, 2'd0)); poke(8'h05, 8'hBB);
        poke(8'h10, enc(4'hC, 2'd3, 2'd0)); poke(8'h11, 8'hAA);
        do_reset; run_n(3);
        check("je not taken (rA!=0)", reg_val(3), 8'hBB);

        // jne taken (r0 != 0)
        clear_memory;
        poke(8'h00, enc(4'hC, 2'd0, 2'd0)); poke(8'h01, 8'h05); // mov $05,%r0
        poke(8'h02, enc(4'hD, 2'd0, 2'd3)); poke(8'h03, 8'h10); // jne %r0,$10
        poke(8'h04, enc(4'hC, 2'd3, 2'd0)); poke(8'h05, 8'hBB);
        poke(8'h10, enc(4'hC, 2'd3, 2'd0)); poke(8'h11, 8'hAA);
        do_reset; run_n(3);
        check("jne taken (rA!=0)", reg_val(3), 8'hAA);

        // jne not taken (r0 == 0)
        clear_memory;
        poke(8'h00, enc(4'hC, 2'd0, 2'd0)); poke(8'h01, 8'h00); // mov $00,%r0
        poke(8'h02, enc(4'hD, 2'd0, 2'd3)); poke(8'h03, 8'h10); // jne %r0,$10
        poke(8'h04, enc(4'hC, 2'd3, 2'd0)); poke(8'h05, 8'hBB);
        poke(8'h10, enc(4'hC, 2'd3, 2'd0)); poke(8'h11, 8'hAA);
        do_reset; run_n(3);
        check("jne not taken (rA==0)", reg_val(3), 8'hBB);

        // -------------------------------------------------------
        // GROUP G: icode 0xE (stack ops)
        // -------------------------------------------------------
        $display("\n=== GROUP G: stack ops (icode 0xE) ===");

        // push reg / pop reg round trip
        clear_memory;
        poke(8'h00, enc(4'hC, 2'd0, 2'd0)); poke(8'h01, 8'hAB); // mov $AB,%r0
        poke(8'h02, enc(4'hE, 2'd0, 2'd0));                     // push %r0
        poke(8'h03, enc(4'hC, 2'd0, 2'd0)); poke(8'h04, 8'h00); // mov $00,%r0 (clear it)
        poke(8'h05, enc(4'hE, 2'd0, 2'd2));                     // pop %r0
        do_reset; run_n(4);
        check("push/pop round trip", reg_val(0), 8'hAB);
        check("rsp restored after push+pop", rsp_val(), 8'hFF);
        check("mem[0xFE] holds pushed byte", mem_val(8'hFE), 8'hAB);

        // push immediate / pop
        clear_memory;
        poke(8'h00, enc(4'hE, 2'd0, 2'd1)); poke(8'h01, 8'h5C); // push $5C
        poke(8'h02, enc(4'hE, 2'd1, 2'd2));                     // pop %r1
        do_reset; run_n(2);
        check("push $imm / pop %r1", reg_val(1), 8'h5C);
        check("rsp restored after push-imm+pop", rsp_val(), 8'hFF);

        // mov rsp,%rA
        clear_memory;
        poke(8'h00, enc(4'hE, 2'd0, 2'd1)); poke(8'h01, 8'h01); // push $01 (rsp -> 0xFE)
        poke(8'h02, enc(4'hE, 2'd2, 2'd3));                     // mov rsp,%r2
        do_reset; run_n(2);
        check("mov rsp,%r2 after one push", reg_val(2), 8'hFE);

        // -------------------------------------------------------
        // GROUP H: icode 0xF (jmp / call / ret / halt)
        // -------------------------------------------------------
        $display("\n=== GROUP H: control flow (icode 0xF) ===");

        // jmp
        clear_memory;
        poke(8'h00, enc(4'hF, 2'd0, 2'd0)); poke(8'h01, 8'h10); // jmp $10
        poke(8'h02, enc(4'hC, 2'd0, 2'd0)); poke(8'h03, 8'hBB); // (skipped) mov $BB,%r0
        poke(8'h10, enc(4'hC, 2'd0, 2'd0)); poke(8'h11, 8'hAA); // (target) mov $AA,%r0
        do_reset; run_n(2);
        check("jmp lands at target", reg_val(0), 8'hAA);
        check("pc after landed instr", pc_val(), 8'h12);

        // call / ret
        clear_memory;
        poke(8'h00, enc(4'hF, 2'd0, 2'd1)); poke(8'h01, 8'h10); // call $10  (return addr = 0x02)
        poke(8'h02, enc(4'hF, 2'd0, 2'd3));                     // halt (landing pad after ret)
        poke(8'h10, enc(4'hC, 2'd0, 2'd0)); poke(8'h11, 8'hCC); // mov $CC,%r0
        poke(8'h12, enc(4'hF, 2'd0, 2'd2));                     // ret
        do_reset;
        run_one; // call
        check("call: return addr pushed", mem_val(8'hFE), 8'h02);
        check("call: rsp decremented", rsp_val(), 8'hFE);
        check("call: pc jumped to function", pc_val(), 8'h10);
        run_one; // mov $CC,%r0
        check("function body executed", reg_val(0), 8'hCC);
        run_one; // ret
        check("ret: pc restored", pc_val(), 8'h02);
        check("ret: rsp restored", rsp_val(), 8'hFF);

        // halt - KNOWN LIMITATION, not a pass/fail assertion
        clear_memory;
        poke(8'h00, enc(4'hF, 2'd0, 2'd3)); // halt
        do_reset; run_one;
        note("halt currently just increments pc (pc_ena gating for halt is");
        note("commented out in control_unit.v) - self-loop FSM state not yet");
        note("implemented. Observed pc after 'halt':");
        $display("        pc = 0x%02h (expected to stay at 0x00 once halt is implemented)", pc_val());

        // -------------------------------------------------------
        // GROUP I: edge cases
        // -------------------------------------------------------
        $display("\n=== GROUP I: edge cases ===");

        // rsp underflow: force rsp to 0x00, push should wrap to 0xFF
        clear_memory;
        poke(8'h00, enc(4'hC, 2'd0, 2'd0)); poke(8'h01, 8'h11); // mov $11,%r0
        poke(8'h02, enc(4'hE, 2'd0, 2'd0));                     // push %r0
        do_reset;
        run_one; // mov $11,%r0
        dut.control_registers.rsp = 8'h00; // force rsp to boundary for this test
        run_one; // push %r0
        check("rsp wraps 0x00 -> 0xFF on push", rsp_val(), 8'hFF);
        check("pushed value lands at wrapped addr", mem_val(8'hFF), 8'h11);

        // rsp overflow: default reset rsp=0xFF, pop with no prior push wraps to 0x00
        clear_memory;
        poke(8'h00, enc(4'hE, 2'd0, 2'd2)); // pop %r0
        do_reset; run_n(1);
        check("rsp wraps 0xFF -> 0x00 on pop", rsp_val(), 8'h00);

        // pc wraparound: jmp to 0xFF, execute a 1-byte instr there, pc should wrap to 0x00
        clear_memory;
        poke(8'h00, enc(4'hF, 2'd0, 2'd0)); poke(8'h01, 8'hFF); // jmp $FF
        poke(8'hFF, enc(4'h1, 2'd1, 2'd0));                     // mov %r0,%r1 (1-byte instr)
        do_reset;
        run_one; // jmp
        check("jmp to 0xFF", pc_val(), 8'hFF);
        run_one; // mov %r0,%r1 at 0xFF
        check("pc wraps 0xFF -> 0x00", pc_val(), 8'h00);

        // -------------------------------------------------------
        // SUMMARY
        // -------------------------------------------------------
        $display("\n=========================================");
        $display("RESULTS: %0d passed, %0d failed", pass_count, fail_count);
        $display("=========================================\n");

        $finish;
    end

endmodule
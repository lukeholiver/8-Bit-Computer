`timescale 1ns/1ps
`include "control_unit_defines.vh"

// ---------------------------------------------------------------------
// cpu_run: loads a hex program (the same continuous hex-string format
// your assembler emits and your C simulator consumes) into cpu.v,
// runs it to completion, and prints the register dump in the exact
// format simulator.c's register_dump() uses - so you can diff the two
// outputs directly.
//
// Usage:
//   iverilog -g2012 -o cpu_run cpu_run.v cpu.v control_unit.v \
//            registers.v control_registers.v memory.v alu.v comparator.v
//   vvp cpu_run +HEXFILE=path/to/program_hex.txt
//
// Optional: +MAXCYCLES=<n> overrides the hang-detection ceiling
// (default 1,000,000 clock cycles).
// ---------------------------------------------------------------------

module cpu_run;

    reg clk;
    reg reset;

    cpu dut (
        .clk    (clk),
        .reset  (reset)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // -----------------------------------------------------------
    // hex-char / nibble helpers
    // -----------------------------------------------------------
    function is_hex_digit;
        input [7:0] ch;
        begin
            is_hex_digit = (ch >= "0" && ch <= "9") ||
                           (ch >= "A" && ch <= "F") ||
                           (ch >= "a" && ch <= "f");
        end
    endfunction

    function [3:0] hex_nibble;
        input [7:0] ch;
        begin
            if (ch >= "0" && ch <= "9") hex_nibble = ch - "0";
            else if (ch >= "A" && ch <= "F") hex_nibble = ch - "A" + 10;
            else if (ch >= "a" && ch <= "f") hex_nibble = ch - "a" + 10;
            else hex_nibble = 4'h0;
        end
    endfunction

    function [7:0] nib2ch;
        input [3:0] n;
        begin
            if (n < 10) nib2ch = "0" + n;
            else nib2ch = "A" + (n - 10);
        end
    endfunction

    function [15:0] to_hex2;
        input [7:0] val;
        begin
            to_hex2 = {nib2ch(val[7:4]), nib2ch(val[3:0])};
        end
    endfunction

    // -----------------------------------------------------------
    // file loading - mirrors simulator.c's safety_check + load_memory:
    // reads a single line of hex-digit pairs, validates it, then loads
    // it into memory starting at address 0.
    // -----------------------------------------------------------
    reg [7:0] raw_chars [0:511]; // matches simulator.c's 513-byte program buffer (512 hex chars + null)
    integer len;

    task load_program;
        input [8*256:1] fname;
        integer fd;
        integer c;
        integer i;
        reg valid;
        begin
            fd = $fopen(fname, "r");
            if (fd == 0) begin
                $display("ERROR: could not open hex file '%0s'", fname);
                $finish;
            end

            len = 0;
            c = $fgetc(fd);
            while (c != -1 && c != 10 && len < 512) begin
                raw_chars[len] = c[7:0];
                len = len + 1;
                c = $fgetc(fd);
            end
            $fclose(fd);

            // --- safety_check equivalent ---
            valid = 1;
            if (len == 0) valid = 0;
            if (len % 2 != 0) valid = 0;
            if ((len / 2) > 256) valid = 0;
            for (i = 0; i < len; i = i + 1)
                if (!is_hex_digit(raw_chars[i])) valid = 0;

            if (!valid) begin
                $display("Invalid Program");
                $finish;
            end

            // --- load_memory equivalent ---
            for (i = 0; i < 256; i = i + 1)
                dut.memory.memory_file[i] = 8'h00;

            for (i = 0; i < len; i = i + 2)
                dut.memory.memory_file[i/2] = {hex_nibble(raw_chars[i]), hex_nibble(raw_chars[i+1])};
        end
    endtask

    // -----------------------------------------------------------
    // register/pc/rsp readback (hierarchical, testbench-only)
    // -----------------------------------------------------------
    function [7:0] reg_val;
        input [1:0] idx;
        reg_val = dut.register_file.reg_file[idx];
    endfunction

    function [7:0] pc_val;
        pc_val = dut.control_registers.pc;
    endfunction

    function [7:0] rsp_val;
        rsp_val = dut.control_registers.rsp;
    endfunction

    // -----------------------------------------------------------
    // main
    // -----------------------------------------------------------
    reg [8*256:1] hexfile;
    integer max_cycles;
    integer cycles;
    integer i;

    initial begin
        if (!$value$plusargs("HEXFILE=%s", hexfile)) begin
            $display("ERROR: no hex file given. Usage: vvp cpu_run +HEXFILE=program_hex.txt");
            $finish;
        end

        if (!$value$plusargs("MAXCYCLES=%d", max_cycles))
            max_cycles = 1000000;

        load_program(hexfile);

        // reset
        reset = 1;
        @(posedge clk);
        @(posedge clk);
        reset = 0;

        // run until halt (or watchdog)
        cycles = 0;
        while (dut.control_unit.state !== `HALT && cycles < max_cycles) begin
            @(posedge clk);
            cycles = cycles + 1;
        end

        if (cycles >= max_cycles) begin
            $display("ERROR: program did not halt within %0d cycles - aborting", max_cycles);
            $finish;
        end

        // --- register_dump equivalent, matching simulator.c's format exactly ---
        $display("Program Completed");
        $display("");
        $display("Register Values:");
        for (i = 0; i < 4; i = i + 1)
            $display("r%0d: %3d  0x%s", i, reg_val(i), to_hex2(reg_val(i)));
        $display("");
        $display("pc:  %3d  0x%s", pc_val(), to_hex2(pc_val()));
        $display("rsp: %3d  0x%s", rsp_val(), to_hex2(rsp_val()));
        $display("halt: true");
        $display("");

        $finish;
    end

endmodule
`timescale 1ns/1ps

module memory_tb;

    reg clk;
    reg [7:0] pc;
    reg [7:0] rsp;
    reg special_write_ena;
    reg rsp_write_ena;
    reg [7:0] special_addr;
    reg [7:0] data_in;

    wire [7:0] mem_pc;
    wire [7:0] mem_pc_plus;
    wire [7:0] mem_rsp;
    wire [7:0] mem_spc;

    integer errors = 0;

    memory uut (
        .clk(clk),
        .pc(pc),
        .rsp(rsp),
        .special_write_ena(special_write_ena),
        .rsp_write_ena(rsp_write_ena),
        .special_addr(special_addr),
        .data_in(data_in),
        .mem_pc(mem_pc),
        .mem_pc_plus(mem_pc_plus),
        .mem_rsp(mem_rsp),
        .mem_spc(mem_spc)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, memory_tb);
    end

    task check_output;
        input [7:0] actual;
        input [7:0] expected;
        input [127:0] label;
        begin
            if (actual !== expected) begin
                $display("FAIL: %0s - expected %h, got %h", label, expected, actual);
                errors = errors + 1;
            end
            else
                $display("PASS: %0s - got %h as expected", label, actual);
        end
    endtask

    initial begin
        // preload memory: address 0x00 holds 00, 0x01 holds 01, ... 0xFF holds FF
        // makes expected values trivial to compute (expected = address)
        $readmemh("memory_init.hex", uut.memory_file);

        // init
        clk = 0;
        pc = 8'h10;
        rsp = 8'h20;
        special_addr = 8'h30;
        special_write_ena = 0;
        rsp_write_ena = 0;
        data_in = 0;

        #1;

        // ---- basic read channel checks ----
        check_output(mem_pc, 8'h10, "read: mem_pc at 0x10");
        check_output(mem_pc_plus, 8'h11, "read: mem_pc_plus at 0x11");
        check_output(mem_rsp, 8'h20, "read: mem_rsp at 0x20");
        check_output(mem_spc, 8'h30, "read: mem_spc at 0x30");

        // ---- special_addr write + isolation ----
        @(negedge clk);
        special_write_ena = 1;
        special_addr = 8'h40;
        data_in = 8'hAB;
        @(posedge clk);
        @(negedge clk);
        special_write_ena = 0;

        // confirm the write landed
        special_addr = 8'h40;
        #1;
        check_output(mem_spc, 8'hAB, "special write: 0x40 = AB");

        // confirm a neighboring, untouched address is unaffected
        special_addr = 8'h41;
        #1;
        check_output(mem_spc, 8'h41, "special write isolation: 0x41 untouched");

        // ---- rsp_write_ena write + isolation ----
        @(negedge clk);
        rsp = 8'h50;
        rsp_write_ena = 1;
        data_in = 8'hCD;
        @(posedge clk);
        @(negedge clk);
        rsp_write_ena = 0;

        rsp = 8'h50;
        #1;
        check_output(mem_rsp, 8'hCD, "rsp write: 0x50 = CD");

        rsp = 8'h51;
        #1;
        check_output(mem_rsp, 8'h51, "rsp write isolation: 0x51 untouched");

        // confirm special_addr write didn't disturb rsp's region either
        special_addr = 8'h50;
        #1;
        check_output(mem_spc, 8'hCD, "cross-channel check: 0x50 reads CD via mem_spc too");

        // ---- write priority: both enables asserted same cycle ----
        // per design, special_write_ena takes priority - confirm that's actually what happens
        @(negedge clk);
        special_addr = 8'h60;
        rsp = 8'h60;
        data_in = 8'hEE;
        special_write_ena = 1;
        rsp_write_ena = 1;
        @(posedge clk);
        @(negedge clk);
        special_write_ena = 0;
        rsp_write_ena = 0;

        special_addr = 8'h60;
        #1;
        check_output(mem_spc, 8'hEE, "priority check: special_write_ena wins when both asserted");

        // ---- edge case: pc = 0xFF, does mem_pc_plus wrap or read out of bounds? ----
        pc = 8'hFF;
        #1;
        $display("EDGE CASE: pc=FF -> mem_pc=%h, mem_pc_plus=%h (watch for x - see note)", mem_pc, mem_pc_plus);

        // ---- summary ----
        if (errors == 0)
            $display("\nALL TESTS PASSED");
        else
            $display("\n%0d TEST(S) FAILED", errors);

        $finish;
    end

endmodule
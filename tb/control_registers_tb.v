`timescale 1ns/1ps

module control_registers_tb;

    reg clk;
    reg reset;
    reg pc_ena;
    reg [7:0] pc_in;
    reg rsp_inc;
    reg rsp_dec;

    wire [7:0] pc_out;
    wire [7:0] pc_1_out;
    wire [7:0] pc_2_out;
    wire [7:0] rsp_out;

    integer errors = 0;

    control_registers uut (
        .clk(clk),
        .reset(reset),
        .pc_ena(pc_ena),
        .pc_in(pc_in),
        .rsp_inc(rsp_inc),
        .rsp_dec(rsp_dec),
        .pc_out(pc_out),
        .pc_1_out(pc_1_out),
        .pc_2_out(pc_2_out),
        .rsp_out(rsp_out)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, control_registers_tb);
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
        // init
        clk = 0;
        reset = 1;
        pc_ena = 0;
        pc_in = 0;
        rsp_inc = 0;
        rsp_dec = 0;

        @(posedge clk);
        @(negedge clk);
        reset = 0;

        // ---- reset values ----
        #1;
        check_output(pc_out, 8'h00, "reset: pc = 00");
        check_output(rsp_out, 8'hFF, "reset: rsp = FF");

        // ---- pc load + combinational pc+1/pc+2 ----
        @(negedge clk);
        pc_ena = 1;
        pc_in = 8'h10;
        @(posedge clk);
        @(negedge clk);
        pc_ena = 0;

        #1;
        check_output(pc_out, 8'h10, "pc load: pc = 10");
        check_output(pc_1_out, 8'h11, "pc load: pc+1 = 11");
        check_output(pc_2_out, 8'h12, "pc load: pc+2 = 12");

        // ---- pc overflow wraparound ----
        @(negedge clk);
        pc_ena = 1;
        pc_in = 8'hFF;
        @(posedge clk);
        @(negedge clk);
        pc_ena = 0;

        #1;
        check_output(pc_out, 8'hFF, "pc overflow: pc = FF");
        check_output(pc_1_out, 8'h00, "pc overflow: pc+1 wraps to 00");
        check_output(pc_2_out, 8'h01, "pc overflow: pc+2 wraps to 01");

        // ---- rsp decrement (push behavior) ----
        @(negedge clk);
        rsp_dec = 1;
        @(posedge clk);
        @(negedge clk);
        rsp_dec = 0;

        #1;
        check_output(rsp_out, 8'hFE, "rsp dec: rsp = FE");

        // ---- rsp increment (pop behavior) ----
        @(negedge clk);
        rsp_inc = 1;
        @(posedge clk);
        @(negedge clk);
        rsp_inc = 0;

        #1;
        check_output(rsp_out, 8'hFF, "rsp inc: rsp back to FF");

        // ---- rsp underflow: push past 0x00 ----
        // drive rsp down to 0x00 first
        repeat (255) begin
            @(negedge clk);
            rsp_dec = 1;
            @(posedge clk);
        end
        @(negedge clk);
        rsp_dec = 0;

        #1;
        check_output(rsp_out, 8'h00, "rsp underflow setup: rsp = 00");

        // one more decrement should wrap to FF
        @(negedge clk);
        rsp_dec = 1;
        @(posedge clk);
        @(negedge clk);
        rsp_dec = 0;

        #1;
        check_output(rsp_out, 8'hFF, "rsp underflow: wraps to FF");

        // ---- mid-simulation reset ----
        @(negedge clk);
        pc_ena = 1;
        pc_in = 8'h55;
        @(posedge clk);
        @(negedge clk);
        pc_ena = 0;

        @(negedge clk);
        reset = 1;
        @(posedge clk);
        @(negedge clk);
        reset = 0;

        #1;
        check_output(pc_out, 8'h00, "mid-sim reset: pc back to 00");
        check_output(rsp_out, 8'hFF, "mid-sim reset: rsp back to FF");

        // ---- summary ----
        if (errors == 0)
            $display("\nALL TESTS PASSED");
        else
            $display("\n%0d TEST(S) FAILED", errors);

        $finish;
    end

endmodule
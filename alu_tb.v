`timescale 1ns/1ps

module alu_tb;

    reg [3:0] sel;
    reg [7:0] rA;
    reg [7:0] rB;

    wire [7:0] result;

    integer errors = 0;

    alu uut (
        .sel(sel),
        .rA(rA),
        .rB(rB),
        .result(result)
    );

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, alu_tb);
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

        // ---- neg ----
        sel = 4'h0; rA = 8'h01; rB = 8'h00;
        #1; check_output(result, 8'hFF, "neg: -1 wraps to FF");

        sel = 4'h0; rA = 8'h00; rB = 8'h00;
        #1; check_output(result, 8'h00, "neg: -0 = 0");

        // ---- bnot ----
        sel = 4'h1; rA = 8'hF0; rB = 8'h00;
        #1; check_output(result, 8'h0F, "bnot: ~F0 = 0F");

        // ---- lnot ----
        sel = 4'h2; rA = 8'h00; rB = 8'h00;
        #1; check_output(result, 8'h01, "lnot: !0 = 1");

        sel = 4'h2; rA = 8'h5A; rB = 8'h00;
        #1; check_output(result, 8'h00, "lnot: !nonzero = 0");

        // ---- add, with overflow ----
        sel = 4'h3; rA = 8'h05; rB = 8'h03;
        #1; check_output(result, 8'h08, "add: 5 + 3 = 8");

        sel = 4'h3; rA = 8'hFF; rB = 8'h02;
        #1; check_output(result, 8'h01, "add: FF + 2 wraps to 01");

        // ---- sub, with underflow ----
        sel = 4'h4; rA = 8'h05; rB = 8'h03;
        #1; check_output(result, 8'h02, "sub: 5 - 3 = 2");

        sel = 4'h4; rA = 8'h00; rB = 8'h01;
        #1; check_output(result, 8'hFF, "sub: 0 - 1 wraps to FF");

        // ---- mul, with overflow ----
        sel = 4'h5; rA = 8'h04; rB = 8'h03;
        #1; check_output(result, 8'h0C, "mul: 4 * 3 = 12");

        sel = 4'h5; rA = 8'h10; rB = 8'h10;
        #1; check_output(result, 8'h00, "mul: 16 * 16 = 256 wraps to 00");

        // ---- shl, with shift-amount masking ----
        sel = 4'h6; rA = 8'h01; rB = 8'h03;
        #1; check_output(result, 8'h08, "shl: 1 << 3 = 8");

        sel = 4'h6; rA = 8'h01; rB = 8'hFF;
        #1; check_output(result, 8'h80, "shl: shift amount masked to lower 3 bits (FF & 07 = 7)");

        // ---- shr, with shift-amount masking ----
        sel = 4'h7; rA = 8'h80; rB = 8'h03;
        #1; check_output(result, 8'h10, "shr: 80 >> 3 = 10");

        sel = 4'h7; rA = 8'h80; rB = 8'h08;
        #1; check_output(result, 8'h80, "shr: shift amount masked (08 & 07 = 0, no shift)");

        // ---- and ----
        sel = 4'h8; rA = 8'hF0; rB = 8'h3C;
        #1; check_output(result, 8'h30, "and: F0 & 3C = 30");

        // ---- or ----
        sel = 4'h9; rA = 8'hF0; rB = 8'h0F;
        #1; check_output(result, 8'hFF, "or: F0 | 0F = FF");

        // ---- xor ----
        sel = 4'hA; rA = 8'hFF; rB = 8'h0F;
        #1; check_output(result, 8'hF0, "xor: FF ^ 0F = F0");

        // ---- default case: unused sel values ----
        sel = 4'hB; rA = 8'hAA; rB = 8'hBB;
        #1; check_output(result, 8'h00, "default: sel=B reads 00");

        sel = 4'hF; rA = 8'hAA; rB = 8'hBB;
        #1; check_output(result, 8'h00, "default: sel=F reads 00");

        // ---- summary ----
        if (errors == 0)
            $display("\nALL TESTS PASSED");
        else
            $display("\n%0d TEST(S) FAILED", errors);

        $finish;
    end

endmodule
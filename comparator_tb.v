`timescale 1ns/1ps

module comparator_tb;

    reg [7:0] comp_in;
    reg [1:0] sel;

    wire comp_out;

    integer errors = 0;

    comparator uut (
        .comp_in(comp_in),
        .sel(sel),
        .comp_out(comp_out)
    );

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, comparator_tb);
    end

    task check_output;
        input actual;
        input expected;
        input [127:0] label;
        begin
            if (actual !== expected) begin
                $display("FAIL: %0s - expected %b, got %b", label, expected, actual);
                errors = errors + 1;
            end
            else
                $display("PASS: %0s - got %b as expected", label, actual);
        end
    endtask

    initial begin

        // ---- jgt (sel = 00): true only for positive, nonzero values ----
        sel = 2'b00; comp_in = 8'h05; // +5
        #1; check_output(comp_out, 1'b1, "jgt: +5 is > 0");

        sel = 2'b00; comp_in = 8'h00; // 0
        #1; check_output(comp_out, 1'b0, "jgt: 0 is not > 0");

        sel = 2'b00; comp_in = 8'hFF; // -1
        #1; check_output(comp_out, 1'b0, "jgt: -1 is not > 0");

        sel = 2'b00; comp_in = 8'h7F; // +127, largest positive
        #1; check_output(comp_out, 1'b1, "jgt: +127 is > 0");

        // ---- jlt (sel = 01): true only for negative values ----
        sel = 2'b01; comp_in = 8'hFF; // -1
        #1; check_output(comp_out, 1'b1, "jlt: -1 is < 0");

        sel = 2'b01; comp_in = 8'h80; // -128, most negative
        #1; check_output(comp_out, 1'b1, "jlt: -128 is < 0");

        sel = 2'b01; comp_in = 8'h00; // 0
        #1; check_output(comp_out, 1'b0, "jlt: 0 is not < 0");

        sel = 2'b01; comp_in = 8'h01; // +1
        #1; check_output(comp_out, 1'b0, "jlt: +1 is not < 0");

        // ---- je (sel = 10): true only for exactly zero ----
        sel = 2'b10; comp_in = 8'h00;
        #1; check_output(comp_out, 1'b1, "je: 0 == 0");

        sel = 2'b10; comp_in = 8'h01;
        #1; check_output(comp_out, 1'b0, "je: +1 != 0");

        sel = 2'b10; comp_in = 8'hFF;
        #1; check_output(comp_out, 1'b0, "je: -1 != 0");

        // ---- jne (sel = 11): true for anything except zero ----
        sel = 2'b11; comp_in = 8'h00;
        #1; check_output(comp_out, 1'b0, "jne: 0 == 0, not taken");

        sel = 2'b11; comp_in = 8'h01;
        #1; check_output(comp_out, 1'b1, "jne: +1 != 0, taken");

        sel = 2'b11; comp_in = 8'hFF;
        #1; check_output(comp_out, 1'b1, "jne: -1 != 0, taken");

        // ---- summary ----
        if (errors == 0)
            $display("\nALL TESTS PASSED");
        else
            $display("\n%0d TEST(S) FAILED", errors);

        $finish;
    end

endmodule
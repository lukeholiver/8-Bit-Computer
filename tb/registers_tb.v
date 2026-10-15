`timescale 1ns/1ps

module registers_tb;

    // testbench signals - reg for things you drive, wire for things you observe
    reg clk;
    reg reset;
    reg [1:0] r1_addr;
    reg [1:0] r2_addr;
    reg write_ena;
    reg [1:0] write_addr;
    reg [7:0] data_in;

    wire [7:0] data_out_1;
    wire [7:0] data_out_2;

    integer errors = 0;

    // instantiate the module under test
    registers uut (
        .clk(clk),
        .reset(reset),
        .r1_addr(r1_addr),
        .r2_addr(r2_addr),
        .write_ena(write_ena),
        .write_addr(write_addr),
        .data_in(data_in),
        .data_out_1(data_out_1),
        .data_out_2(data_out_2)
    );

    // clock generation - toggle every 5ns = 10ns period
    always #5 clk = ~clk;

    // dump waveform for gtkwave
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, registers_tb);
    end

    // reusable check task
    task check_output;
        input [7:0] actual;
        input [7:0] expected;
        input [127:0] label; // string for message
        begin
            if (actual !== expected)
                begin
                    $display("FAIL: %0s - expected %h, got %h", label, expected, actual);
                    errors = errors + 1;
                end
            else
                $display("PASS: %0s - got %h as expected", label, actual);
        end
    endtask

    // test sequence
    initial begin
        // init
        clk = 0;
        reset = 1;
        write_ena = 0;
        write_addr = 0;
        data_in = 0;
        r1_addr = 0;
        r2_addr = 0;

        @(posedge clk); // let reset take effect on first edge
        @(negedge clk);
        reset = 0;

        // ---- write different values to each register ----
        // r0 = AA
        @(negedge clk);
        write_ena = 1;
        write_addr = 2'd0;
        data_in = 8'hAA;
        @(posedge clk);
        @(negedge clk);
        write_ena = 0;

        // r1 = BB
        @(negedge clk);
        write_ena = 1;
        write_addr = 2'd1;
        data_in = 8'hBB;
        @(posedge clk);
        @(negedge clk);
        write_ena = 0;

        // r2 = CC
        @(negedge clk);
        write_ena = 1;
        write_addr = 2'd2;
        data_in = 8'hCC;
        @(posedge clk);
        @(negedge clk);
        write_ena = 0;

        // r3 = DD
        @(negedge clk);
        write_ena = 1;
        write_addr = 2'd3;
        data_in = 8'hDD;
        @(posedge clk);
        @(negedge clk);
        write_ena = 0;

        // ---- independent dual-port read check ----
        // read r0 on port 1, r2 on port 2 simultaneously
        r1_addr = 2'd0;
        r2_addr = 2'd2;
        #1;
        check_output(data_out_1, 8'hAA, "dual-port read: port1=r0");
        check_output(data_out_2, 8'hCC, "dual-port read: port2=r2");

        // read r1 on port 1, r3 on port 2 simultaneously - confirms ports are truly independent
        r1_addr = 2'd1;
        r2_addr = 2'd3;
        #1;
        check_output(data_out_1, 8'hBB, "dual-port read: port1=r1");
        check_output(data_out_2, 8'hDD, "dual-port read: port2=r3");

        // ---- write isolation check ----
        // confirm writing to r1 doesn't disturb r0, r2, r3
        @(negedge clk);
        write_ena = 1;
        write_addr = 2'd1;
        data_in = 8'hFF;
        @(posedge clk);
        @(negedge clk);
        write_ena = 0;

        r1_addr = 2'd0;
        r2_addr = 2'd1;
        #1;
        check_output(data_out_1, 8'hAA, "write isolation: r0 undisturbed");
        check_output(data_out_2, 8'hFF, "write isolation: r1 updated");

        r1_addr = 2'd2;
        r2_addr = 2'd3;
        #1;
        check_output(data_out_1, 8'hCC, "write isolation: r2 undisturbed");
        check_output(data_out_2, 8'hDD, "write isolation: r3 undisturbed");

        // ---- mid-simulation reset check ----
        // registers currently hold nonzero, "dirty" values - confirm reset actually clears them
        @(negedge clk);
        reset = 1;
        @(posedge clk); // reset takes effect here
        @(negedge clk);
        reset = 0;

        r1_addr = 2'd0;
        r2_addr = 2'd1;
        #1;
        check_output(data_out_1, 8'h00, "mid-sim reset: r0 cleared");
        check_output(data_out_2, 8'h00, "mid-sim reset: r1 cleared");

        r1_addr = 2'd2;
        r2_addr = 2'd3;
        #1;
        check_output(data_out_1, 8'h00, "mid-sim reset: r2 cleared");
        check_output(data_out_2, 8'h00, "mid-sim reset: r3 cleared");

        // ---- summary ----
        if (errors == 0)
            $display("\nALL TESTS PASSED");
        else
            $display("\n%0d TEST(S) FAILED", errors);

        $finish;
    end

endmodule
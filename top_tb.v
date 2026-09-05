`timescale 1ns/1ps

module top_tb;

    reg clk;
    reg reset;
    reg rx;

    localparam CLK_PERIOD    = 10;                          // 100MHz
    localparam TICKS_PER_BIT = 10417;
    localparam BIT_PERIOD    = TICKS_PER_BIT * CLK_PERIOD;   // one UART bit period, in ns

    integer errors;
    integer i;

    reg [7:0] byte_stream [0:255];  // assembled exponent program, zero-padded to 256 bytes

    // instantiate the full system
    top dut (
        .clk    (clk),
        .reset  (reset),
        .rx     (rx)
    );

    // clock generation
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // drives one byte onto rx, LSB first, standard 8N1 framing
    task send_byte(input [7:0] data);
        integer b;
        begin
            rx = 0;                        // start bit
            #(BIT_PERIOD);
            for (b = 0; b < 8; b = b + 1) begin
                rx = data[b];
                #(BIT_PERIOD);
            end
            rx = 1;                        // stop bit
            #(BIT_PERIOD);
        end
    endtask

    // reads register r<addr> out through cpu's existing reg_addr_a / data_out_1
    // read port, checked against expected - only valid while the CPU is halted
    task check_register(input [1:0] addr, input [7:0] expected);
        begin
            force dut.cpu.reg_addr_a = addr;
            #1;
            if (dut.cpu.data_out_1 !== expected) begin
                $display("ERROR: r%0d = %0d, expected %0d", addr, dut.cpu.data_out_1, expected);
                errors = errors + 1;
            end
            else begin
                $display("r%0d = %0d - correct", addr, dut.cpu.data_out_1);
            end
            release dut.cpu.reg_addr_a;
        end
    endtask

    initial begin
        $dumpfile("top_tb.vcd");
        $dumpvars(0, top_tb);

        errors = 0;

        // real assembled bytes for exponent_program.txt, generated from the
        // actual assembler, followed by zero padding out to 256 bytes total
        byte_stream[0]  = 8'hC0; byte_stream[1]  = 8'h05; byte_stream[2]  = 8'hC4; byte_stream[3]  = 8'h03;
        byte_stream[4]  = 8'hCC; byte_stream[5]  = 8'h38; byte_stream[6]  = 8'hF1; byte_stream[7]  = 8'h09;
        byte_stream[8]  = 8'hFF; byte_stream[9]  = 8'hD6; byte_stream[10] = 8'h18; byte_stream[11] = 8'hEC;
        byte_stream[12] = 8'h1C; byte_stream[13] = 8'hC5; byte_stream[14] = 8'hFF; byte_stream[15] = 8'hD4;
        byte_stream[16] = 8'h13; byte_stream[17] = 8'hEE; byte_stream[18] = 8'hFE; byte_stream[19] = 8'h43;
        byte_stream[20] = 8'hC5; byte_stream[21] = 8'hFF; byte_stream[22] = 8'hF0; byte_stream[23] = 8'h0F;
        byte_stream[24] = 8'hC0; byte_stream[25] = 8'h01; byte_stream[26] = 8'hFE;
        for (i = 27; i < 256; i = i + 1)
            byte_stream[i] = 8'h00;

        rx = 1;             // idle high
        reset = 1;

        repeat (5) @(negedge clk);
        reset = 0;
        repeat (5) @(negedge clk);

        $display("sending 256 bytes...");
        for (i = 0; i < 256; i = i + 1)
            send_byte(byte_stream[i]);

        $display("load complete, waiting for dut.done...");
        wait (dut.done === 1'b1);
        $display("dut.done asserted at time %0t, letting the CPU run...", $time);

        // generous room for a ~27-byte program to finish executing
        repeat (500) @(posedge clk);

        // pc_out / rsp_out are real named ports on control_registers already,
        // so these are plain hierarchical reads - no forcing needed
        if (dut.cpu.control_registers.pc_out !== 8'd8) begin
            $display("ERROR: pc = %0d, expected 8", dut.cpu.control_registers.pc_out);
            errors = errors + 1;
        end
        else
            $display("pc = %0d - correct", dut.cpu.control_registers.pc_out);

        if (dut.cpu.control_registers.rsp_out !== 8'd255) begin
            $display("ERROR: rsp = %0d, expected 255", dut.cpu.control_registers.rsp_out);
            errors = errors + 1;
        end
        else
            $display("rsp = %0d - correct", dut.cpu.control_registers.rsp_out);

        check_register(0, 8'd125);
        check_register(1, 8'd0);
        check_register(2, 8'd0);
        check_register(3, 8'd56);

        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("%0d TEST(S) FAILED", errors);

        $finish;
    end

endmodule
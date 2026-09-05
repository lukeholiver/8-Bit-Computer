`timescale 1ns/1ps

module uart_rx_tb;

    reg clk;
    reg reset;
    reg rx;
    wire [7:0] data_out;
    wire data_valid;

    localparam CLK_PERIOD    = 10;                          // 100MHz
    localparam TICKS_PER_BIT = 10417;
    localparam BIT_PERIOD    = TICKS_PER_BIT * CLK_PERIOD;   // one UART bit period, in ns

    integer errors;
    reg [7:0] captured_byte;
    reg       byte_received;

    // instantiate DUT
    uart_rx dut (
        .clk(clk),
        .reset(reset),
        .rx(rx),
        .data_out(data_out),
        .data_valid(data_valid)
    );

    // clock generation
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // background capture: latches whatever data_valid pulses out, whenever it happens,
    // regardless of what the sequential test code below is doing at the time
    always @(posedge clk) begin
        if (data_valid) begin
            captured_byte <= data_out;
            byte_received <= 1;
        end
    end

    // drives one byte onto rx, LSB first, standard 8N1 framing
    task send_byte(input [7:0] data);
        integer i;
        begin
            rx = 0;                        // start bit
            #(BIT_PERIOD);
            for (i = 0; i < 8; i = i + 1) begin
                rx = data[i];
                #(BIT_PERIOD);
            end
            rx = 1;                        // stop bit
            #(BIT_PERIOD);
        end
    endtask

    // checks the most recently captured byte against what's expected
    task check_byte(input [7:0] expected);
        begin
            if (!byte_received) begin
                $display("ERROR: data_valid never asserted, expected byte 0x%02X", expected);
                errors = errors + 1;
            end
            else if (captured_byte !== expected) begin
                $display("ERROR: received 0x%02X, expected 0x%02X", captured_byte, expected);
                errors = errors + 1;
            end
            else begin
                $display("received 0x%02X - correct", captured_byte);
            end
            byte_received = 0;
        end
    endtask

    initial begin
        $dumpfile("uart_rx_tb.vcd");
        $dumpvars(0, uart_rx_tb);

        errors = 0;
        byte_received = 0;
        rx = 1;             // idle high
        reset = 1;

        repeat (5) @(negedge clk);
        reset = 0;
        repeat (5) @(negedge clk);

        // test 1: single byte
        send_byte(8'hA5);
        #(BIT_PERIOD);
        check_byte(8'hA5);

        #(2 * BIT_PERIOD);   // idle gap between frames

        // test 2: back-to-back bytes
        send_byte(8'h00);
        #(BIT_PERIOD);
        check_byte(8'h00);

        send_byte(8'hFF);
        #(BIT_PERIOD);
        check_byte(8'hFF);

        #(2 * BIT_PERIOD);

        // test 3: false start - a brief glitch, well short of the half-bit
        // confirmation window, should never turn into a byte
        rx = 0;
        #(BIT_PERIOD / 4);
        rx = 1;

        #(2 * BIT_PERIOD);
        if (byte_received) begin
            $display("ERROR: false start incorrectly produced a byte (0x%02X)", captured_byte);
            errors = errors + 1;
        end
        else begin
            $display("false start correctly ignored");
        end
        byte_received = 0;

        // confirm the receiver still works normally after the false start
        send_byte(8'h3C);
        #(BIT_PERIOD);
        check_byte(8'h3C);

        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("%0d TEST(S) FAILED", errors);

        $finish;
    end

endmodule
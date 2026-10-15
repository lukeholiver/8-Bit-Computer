`timescale 1ns/1ps

module baud_tick_generator_tb;

    reg clk;
    reg reset;
    reg restart;
    wire tick;

    real last_tick_time;
    real gap;
    integer gap_cycles;
    integer tick_count;
    integer errors;

    localparam CLK_PERIOD          = 10;     // 10ns period -> 100MHz
    localparam EXPECTED_TICKS_PER_BIT = 10417;

    // instantiate DUT
    baud_tick_generator dut (
        .clk(clk),
        .reset(reset),
        .restart(restart),
        .tick(tick)
    );

    // clock generation
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    initial begin
        $dumpfile("baud_tick_generator_tb.vcd");
        $dumpvars(0, baud_tick_generator_tb);

        errors = 0;
        tick_count = 0;

        // apply reset, confirm tick stays low
        reset = 1;
        restart = 0;
        @(negedge clk);
        @(negedge clk);

        if (tick !== 0) begin
            $display("ERROR: tick asserted during reset");
            errors = errors + 1;
        end

        reset = 0;
        @(negedge clk);

        // kick off counting
        restart = 1;
        @(negedge clk);
        restart = 0;

        last_tick_time = $time;

        // check several ticks land exactly one bit period apart
        repeat (5) begin
            @(posedge tick);
            gap = $time - last_tick_time;
            gap_cycles = gap / CLK_PERIOD;
            tick_count = tick_count + 1;

            if (gap_cycles != EXPECTED_TICKS_PER_BIT) begin
                $display("ERROR: tick #%0d arrived after %0d cycles, expected %0d",
                          tick_count, gap_cycles, EXPECTED_TICKS_PER_BIT);
                errors = errors + 1;
            end
            else begin
                $display("tick #%0d arrived after %0d cycles - correct", tick_count, gap_cycles);
            end

            last_tick_time = $time;
        end

        // restart partway through a count, confirm it realigns rather than
        // just letting the in-progress count finish
        repeat (100) @(posedge clk);
        @(negedge clk);
        restart = 1;
        @(negedge clk);
        restart = 0;

        last_tick_time = $time;

        @(posedge tick);
        gap = $time - last_tick_time;
        gap_cycles = gap / CLK_PERIOD;

        if (gap_cycles != EXPECTED_TICKS_PER_BIT) begin
            $display("ERROR: restart mid-count did not realign timing, got %0d cycles", gap_cycles);
            errors = errors + 1;
        end
        else begin
            $display("restart mid-count correctly realigned timing");
        end

        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("%0d TEST(S) FAILED", errors);

        $finish;
    end

endmodule
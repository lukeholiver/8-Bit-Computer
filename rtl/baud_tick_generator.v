module baud_tick_generator (
    input clk,
    input reset,
    input restart,   // pulsed by the FSM: zero the counter, start counting
    output reg  tick        // one-cycle pulse once per bit period
);

    /*
    Target cycle number is 10,417
    100Mhz / 9600 (baud rate) = 10,417
    */

    localparam TICKS_PER_BIT = 10417;

    reg [13:0] counter; // need 14 bits to hold 10,417

    always @(posedge clk) begin
        if(reset || restart) begin
            tick <= 0;
            counter <= 0;
        end
        else if(counter == TICKS_PER_BIT - 1) begin // start counting from 0
            tick <= 1;
            counter <= 0;
        end
        else begin
            tick <= 0;
            counter <= counter + 1;
        end
    end
endmodule
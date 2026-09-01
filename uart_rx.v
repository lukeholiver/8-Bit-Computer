module uart_rx (
    input clk,
    input reset,
    input rx,                   // 1 bit
    output reg [7:0] data_out,  // byte
    output reg data_valid
);

    // two flip-flop synchronization

    reg sync_ff_1;
    reg sync_ff_2;

    always @(posedge clk) begin
        if(reset) begin
            sync_ff_1 <= 1; // UART idle state is 1
            sync_ff_2 <= 1;
        end
        else begin
            sync_ff_1 <= rx;        // recives asynch in
            sync_ff_2 <= sync_ff_1; // recives synch in
        end
    end


endmodule

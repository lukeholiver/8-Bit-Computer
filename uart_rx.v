
`define IDLE        2'b00
`define START       2'b01
`define RECIEVE     2'b10
`define STOP        2'b11

module uart_rx (
    input clk,
    input reset,
    input rx,                   // 1 bit
    output reg [7:0] data_out,  // byte
    output reg data_valid
);

    localparam TICKS_PER_BIT = 10417;

    // wires and regs
    reg [1:0] state;
    reg [12:0] half_cycle_count;
    reg restart;
    wire tick;
    reg [3:0] byte_count;
    
    reg sync_ff_1;
    reg sync_ff_2;

    always @(posedge clk) begin  

        // two flip-flop synchronization
        if(reset) begin
            sync_ff_1 <= 1; // UART idle state is 1
            sync_ff_2 <= 1;
            state <= `IDLE;
            byte_count <= 0;
            half_cycle_count <= 0;
            data_out <= 0;
        end
        else begin
            sync_ff_1 <= rx;        // recives asynch in
            sync_ff_2 <= sync_ff_1; // recives synch in
        end

        // defaults
        restart <= 0;
        data_valid <= 0;

        // 4 state FSM
        case(state)

            // detect change from 1 (idle) to 0 (start bit)
            `IDLE: begin
                if(sync_ff_2 && !sync_ff_1)
                    state <= `START; // start bit detected
                else
                    state <= `IDLE;
            end

            // detected bit change, wait half bit cycle
            `START: begin
                // we need to wait for 5209 cycles
                if(half_cycle_count < ((TICKS_PER_BIT - 1) / 2)) begin
                    state <= `START;
                    half_cycle_count <= half_cycle_count + 1;
                end

                else begin
                    if(!sync_ff_2) begin
                        state <= `RECIEVE;
                        half_cycle_count <= 0;
                        restart <= 1;
                    end
                    else begin
                        state <= `IDLE;
                    end
                end

            end

            // read 8 bits from sync_ff_2
            `RECIEVE: begin

                if(tick) begin

                    if(byte_count < 8) begin
                        data_out[byte_count] <= sync_ff_2;
                        byte_count <= byte_count + 1;

                        if(byte_count == 7) begin
                            state <= `STOP;
                            byte_count <= 0;
                        end
                         
                    end
                end

                else begin
                    state <= `RECIEVE;
                end
            end

            // Detect stop bit and send byte
            `STOP: begin
                if(tick && sync_ff_2) begin
                    state <= `IDLE;
                    data_valid <= 1;
                end
                else    // could enter a loop if stop bit is never detected
                    state <= `STOP;
            end
        endcase
    end

    // module instantiations
    baud_tick_generator baud_tick_generator(
        .clk        (clk),
        .reset      (reset),
        .restart    (restart),
        .tick       (tick)
    );

endmodule
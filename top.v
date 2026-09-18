module top (
    input clk,
    input reset,
    input rx,
    input [2:0] sw,

    output [6:0] seg,
    output [3:0] an
);

// wires and regs
wire data_valid;
wire [7:0] data_bus;

wire done;
wire load_ena;
wire [7:0] load_addr;
wire [7:0] data_byte;
wire [7:0] debug_out;

// module instantiations

    uart_rx uart_rx(
        .clk        (clk),
        .reset      (reset),
        .rx         (rx),

        .data_out   (data_bus),
        .data_valid (data_valid)
    );

    loader loader(
        .clk        (clk),
        .reset      (reset),
        .data_valid (data_valid),
        .data_in    (data_bus),

        .load_ena   (load_ena),
        .load_addr  (load_addr),
        .data_byte  (data_byte),
        .done       (done)
    );

    cpu cpu(
        .clk        (clk),
        .reset      (reset || !done),

        .load_ena   (load_ena),
        .load_addr  (load_addr),
        .load_data  (data_byte),
        
        .debug_sel  (sw),
        .debug_out  (debug_out)
    );

    display_mux display_mux(
        .clk        (clk),
        .reset      (reset || !done),
        .debug_out  (debug_out),
        .reg_sel    (sw),

        .seg        (seg),
        .an         (an)
    );

endmodule
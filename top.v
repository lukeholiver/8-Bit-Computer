module top (
    input clk,
    input reset,
    input rx
);

// wires and regs
wire cpu_reset;
wire data_valid;
wire [7:0] data_bus;

wire done;
wire load_ena;
wire [7:0] load_addr;
wire [7:0] data_byte;

// module instantiations

    uart_rx uart_rx(
        .clk        (clk),
        .reset      (reset),
        .rx         (rx),       // will map to micro-usb port on board

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
        .load_data  (data_byte)
    );

endmodule
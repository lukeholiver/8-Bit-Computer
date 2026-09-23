module io_tb(
    input clk,
    input reset,

    output reg [6:0] seg,
    output [3:0] an
);

// Counter on 7 seg display

// first display
assign an = 4'b1110;
reg [25:0] clk_counter;
reg [3:0] nibble;
wire [6:0] decoded_seg;

always @(posedge clk) begin

        if(reset) begin
            clk_counter <= 0;
            seg <= 7'b0111111;
            nibble <= 0; 
        end
        else begin
            clk_counter <= clk_counter + 1;
            if(clk_counter == 26'd50000000) begin
                nibble <= nibble + 1;
                seg <= decoded_seg;
            end
        end 
end

    // segment decoder module
        segment_decoder segment_decoder(
        .nibble     (nibble),
        .seg        (decoded_seg)
    );

endmodule
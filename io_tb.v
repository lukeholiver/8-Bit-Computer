module io_tb(
    input clk,
    input reset,
    input rx,
    input [2:0] sw,

    output [6:0] seg,
    output [3:0] an
);



/*
What do we want to test?
- LEDs and switches - all 16
- Count to F on 7 seg display
- 


*/

// Counter on 7 seg display

// first display
assign an <= 4'b1110;

reg [15:0] clk_counter;
reg [3:0] nibble;
wire [6:0] decoded_seg;


always @(posedge clk) begin

        if(reset) begin
            clk_counter <= 0;
            seg <= 7'b0111111; 
        end
        else begin
            clk_counter <= clk_counter + 1;
            if()

        end 

end

        segment_decoder segment_decoder(
        .nibble     (nibble),
        .seg        (decoded_seg)
    );



endmodule




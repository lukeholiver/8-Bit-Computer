`include "control_unit_defines.vh"

module display_mux(
    input clk,
    input reset, // open

    input [7:0] debug_out,
    input [2:0] reg_sel, // selects which register to display

    output reg [6:0] seg,
    output reg [3:0] an // which part of display to access
);

    reg [16:0] clk_counter;  
    reg [3:0] nibble;
    wire [6:0] decoded_seg;

    wire [1:0] digit_sel = clk_counter[16:15];

    // sequential 
    always @(posedge clk) begin

        if(reset) begin
            clk_counter <= 0;
            seg <= 7'b0111111;
            an <= 4'b1110; 
        end

        else begin
            clk_counter <= clk_counter + 1;
            // an is active low
            case(digit_sel)
                2'b00: begin seg <= decoded_seg; an <= 4'b1110; end // digit 1 (low 4 bits)
                2'b01: begin seg <= decoded_seg; an <= 4'b1101; end // digit 2 (high 4 bits)
                2'b10: begin seg <= 7'b0111111; an <= 4'b1011; end // digit 3 (dash)
                2'b11: begin seg <= decoded_seg; an <= 4'b0111; end // digit 4 (register index)
            endcase
        end
    end

    // nibble mux
    always @(*) begin
        case(digit_sel)
            2'b00: nibble = debug_out[3:0];
            2'b01: nibble = debug_out[7:4];
            2'b10: nibble = 4'h0; // won't matter
            2'b11: begin 
                case(reg_sel)
                    `REGISTER_0:    nibble = 4'h0;
                    `REGISTER_1:    nibble = 4'h1;
                    `REGISTER_2:    nibble = 4'h2;
                    `REGISTER_3:    nibble = 4'h3;
                    `REGISTER_PC:   nibble = 4'h4;
                    `REGISTER_RSP:  nibble = 4'h5;
                    default:        nibble = 4'h0;
                endcase
            end
        endcase
    end

    // instantiate segment_decoder
    segment_decoder segment_decoder(
        .nibble     (nibble),
        .seg        (decoded_seg)
    );

endmodule
module comparator (

    input [7:0] comp_in,
    input [1:0] sel,

    output reg comp_out

);

    always @(*) begin
        case(sel)
            2'b00: comp_out <= (comp_in !=0 && comp_in[7] == 1'b0);  // jgt
            2'b01: comp_out <= (comp_in[7] == 1'b1);                 // jlt
            2'b10: comp_out <= (comp_in == 0);                       // je
            2'b11: comp_out <= (comp_in != 0);                       // jne
            default: comp_out <= 0;
        endcase
    end

endmodule
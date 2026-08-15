module alu (

    input [3:0] sel,

    input [7:0] rA,
    input [7:0] rB,

    output reg [7:0] result

);

    /*
    rA and rB mean operand A and operand B
    ALU treats these values identically regardless origin
    */

    always @(*) begin
        case(sel)
        
            4'h0: result = -rA;
            4'h1: result = ~rA;
            4'h2: result = !rA;

            4'h3: result = rA + rB;
            4'h4: result = rA - rB;
            4'h5: result = rA * rB;
            4'h6: result = rA << (rB & 8'h07);
            4'h7: result = rA >> (rB & 8'h07);
            4'h8: result = rA & rB;
            4'h9: result = rA | rB;
            4'hA: result = rA ^ rB;

            default: result = 8'h00;

        endcase
    end

endmodule
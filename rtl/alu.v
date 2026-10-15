`include "control_unit_defines.vh"

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
        
            `NEG: result = -rA;
            `BNOT: result = ~rA;
            `LNOT: result = !rA;
            `ADD: result = rA + rB;
            `SUB: result = rA - rB;
            `MUL: result = rA * rB;
            `SHL: result = rA << (rB & 8'h07);
            `SHR: result = rA >> (rB & 8'h07);
            `AND: result = rA & rB;
            `OR: result = rA | rB;
            `XOR: result = rA ^ rB;

            default: result = 8'h00;

        endcase
    end

endmodule
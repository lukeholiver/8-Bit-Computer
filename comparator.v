`include "control_unit_defines.vh"

module comparator (

    input [7:0] comp_in,
    input [1:0] sel,

    output reg comp_out

);

    always @(*) begin
        case(sel)
            `JGT: comp_out = (comp_in !=0 && comp_in[7] == 1'b0);
            `JLT: comp_out = (comp_in[7] == 1'b1);
            `JE: comp_out = (comp_in == 0);
            `JNE: comp_out = (comp_in != 0);
            default: comp_out = 0;
        endcase
    end

endmodule
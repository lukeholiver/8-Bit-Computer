`include "control_unit_defines.vh"

module control_unit (

    input clk,
    input reset,

    output reg [3:0] alu_sel,
    output reg [1:0] comp_sel,
    output reg [1:0] wtb_sm_sel,
    output reg [1:0] pc_inc_sel

);

    reg [5:0] state;
    reg [3:0] data_path;


    reg [7:0] ir;

    // state transistion logic
    always @(posedge clk) begin

    
        case(state)

            `FETCH:
                ir <= mem_pc;

            `DECODE:

            `EXECUTE:

            `MEM1:

            `MEM2:

            `WRITEBACK:

        endcase

        // look at state and datapath rather than state and icoe

    end

    // instruction decoding and output/control logic
    always @(*) begin

        // defaults
        data_path = `REG_ONLY;
        alu_sel = `NEG;
        comp_sel = `JNE;
        wtb_sm_sel = `SEL_NONE;
        pc_inc_sel = `PC_SEL_1;

        case(ir[7:4])

            4'h0: begin
                case(ir[1:0])
                    2'b00: begin data_path = `REG_ONLY; alu_sel = `NEG; end
                    2'b01: begin data_path = `REG_ONLY; alu_sel = `BNOT; end
                    2'b10: begin data_path = `REG_ONLY; alu_sel = `LNOT; end
                    2'b11: begin data_path = `SMP_MOVE; wtb_sm_sel = `SEL_PC; end
                endcase
            end

            4'h1: begin data_path = `SMP_MOVE; wtb_sm_sel = `SEL_REG; end
            4'h2: begin data_path = `REG_ONLY; alu_sel = `ADD; end
            4'h3: begin data_path = `REG_ONLY; alu_sel = `SUB; end    
            4'h4: begin data_path = `REG_ONLY; alu_sel = `MUL; end
            4'h5: begin data_path = `REG_ONLY; alu_sel = `SHL; end
            4'h6: begin data_path = `REG_ONLY; alu_sel = `SHR; end
            4'h7: begin data_path = `REG_ONLY; alu_sel = `AND; end
            4'h8: begin data_path = `REG_ONLY; alu_sel = `OR;  end
            4'h9: begin data_path = `REG_ONLY; alu_sel = `XOR; end

            4'hA: data_path = `MEM_MOVE;
            4'hB: data_path = `MEM_MOVE;

            4'hC: begin
                case(ir[1:0])
                    2'b00: begin data_path = `MEM_MOVE; pc_inc_sel = `PC_SEL_2 end
                    2'b01: begin data_path = `IMM_OP; alu_sel = `ADD; pc_inc_sel = `PC_SEL_2 end
                    2'b10: begin data_path = `DBL_MEM; pc_inc_sel = `PC_SEL_2 end
                    2'b11: begin data_path = `DBL_MEM; pc_inc_sel = `PC_SEL_2 end
                endcase
            end

            4'hD: begin
                case(ir[1:0])
                    2'b00: begin data_path = `IMM_OP; comp_sel = `JGT; pc_inc_sel = `PC_SEL_IMM end
                    2'b01: begin data_path = `IMM_OP; comp_sel = `JLT; pc_inc_sel = `PC_SEL_IMM end
                    2'b10: begin data_path = `IMM_OP; comp_sel = `JE;  pc_inc_sel = `PC_SEL_IMM end
                    2'b11: begin data_path = `IMM_OP; comp_sel = `JNE; pc_inc_sel = `PC_SEL_IMM end
                endcase
            end

            4'hE: begin
                case(ir[1:0])
                    2'b00: begin data_path = `MEM_MOVE; end
                    2'b01: begin data_path = `DBL_MEM; pc_inc_sel = `PC_SEL_2 end
                    2'b10: begin data_path = `MEM_MOVE; pc_inc_sel = `PC_SEL_RSP end
                    2'b11: begin data_path = `SMP_MOVE; wtb_sm_sel = `SEL_RSP; end
                endcase
            end

            4'hF: begin
                case(ir[1:0])
                    2'b00: data_path = `MEM_MOVE;
                    2'b01: data_path = `DBL_MEM;
                    2'b10: data_path = `MEM_MOVE;
                    2'b11: begin data_path = `SMP_MOVE; wtb_sm_sel = `SEL_NONE; end
                endcase
            end

            default: data_path = `REG_ONLY;

        endcase
    end


endmodule
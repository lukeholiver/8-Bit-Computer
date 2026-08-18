`include "control_unit_defines.vh"

module control_unit (

    input clk,
    input reset,

    output reg [3:0] alu_sel,
    output reg [1:0] comp_sel,

    output reg [2:0] reg_data_sel,
    output reg [1:0] mem_data_sel,
    output reg [1:0] pc_inc_sel,

    output reg branch_gate_ena,

    output reg rsp_inc,
    output reg rsp_dec,

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
        reg_data_sel = `REG_SEL_NONE;
        mem_data_sel = `MEM_SEL_NONE;
        pc_inc_sel = `PC_SEL_1;
        branch_gate_ena = 0;
        rsp_dec = 0;
        rsp_inc = 0;

        case(ir[7:4])

            4'h0: begin
                case(ir[1:0])
                    2'b00: begin data_path = `REG_ONLY; alu_sel = `NEG; reg_data_sel = `REG_SEL_ALU; end
                    2'b01: begin data_path = `REG_ONLY; alu_sel = `BNOT; reg_data_sel = `REG_SEL_ALU; end
                    2'b10: begin data_path = `REG_ONLY; alu_sel = `LNOT; reg_data_sel = `REG_SEL_ALU; end
                    2'b11: begin data_path = `SMP_MOVE; reg_data_sel = `REG_SEL_PC; end
                endcase
            end

            4'h1: begin data_path = `SMP_MOVE; reg_data_sel = `REG_SEL_REG; end
            4'h2: begin data_path = `REG_ONLY; alu_sel = `ADD; reg_data_sel = `REG_SEL_ALU; end
            4'h3: begin data_path = `REG_ONLY; alu_sel = `SUB; reg_data_sel = `REG_SEL_ALU; end    
            4'h4: begin data_path = `REG_ONLY; alu_sel = `MUL; reg_data_sel = `REG_SEL_ALU; end
            4'h5: begin data_path = `REG_ONLY; alu_sel = `SHL; reg_data_sel = `REG_SEL_ALU; end
            4'h6: begin data_path = `REG_ONLY; alu_sel = `SHR; reg_data_sel = `REG_SEL_ALU; end
            4'h7: begin data_path = `REG_ONLY; alu_sel = `AND; reg_data_sel = `REG_SEL_ALU; end
            4'h8: begin data_path = `REG_ONLY; alu_sel = `OR;  reg_data_sel = `REG_SEL_ALU; end
            4'h9: begin data_path = `REG_ONLY; alu_sel = `XOR; reg_data_sel = `REG_SEL_ALU; end

            4'hA: begin data_path = `MEM_MOVE; reg_data_sel = `REG_SEL_MEM_SPC; end
            4'hB: begin data_path = `MEM_MOVE; mem_data_sel = `MEM_SEL_REG; end

            4'hC: begin
                case(ir[1:0])
                    2'b00: begin data_path = `MEM_MOVE; pc_inc_sel = `PC_SEL_2; reg_data_sel = `REG_SEL_MEM_IMM; end
                    2'b01: begin data_path = `IMM_OP; alu_sel = `ADD; pc_inc_sel = `PC_SEL_2; reg_data_sel = `REG_SEL_ALU; end
                    2'b10: begin data_path = `DBL_MEM; pc_inc_sel = `PC_SEL_2; mem_data_sel = `MEM_SEL_IMM; end
                    2'b11: begin data_path = `DBL_MEM; pc_inc_sel = `PC_SEL_2; reg_data_sel = `REG_SEL_MEM_SPC; end
                endcase
            end

            // default to PC = immediate, if condition is false, set pc = pc + 2
            4'hD: begin
                case(ir[1:0])
                    2'b00: begin data_path = `IMM_OP; comp_sel = `JGT; pc_inc_sel = `PC_SEL_IMM; branch_gate_ena = 1; end
                    2'b01: begin data_path = `IMM_OP; comp_sel = `JLT; pc_inc_sel = `PC_SEL_IMM; branch_gate_ena = 1; end
                    2'b10: begin data_path = `IMM_OP; comp_sel = `JE;  pc_inc_sel = `PC_SEL_IMM; branch_gate_ena = 1; end
                    2'b11: begin data_path = `IMM_OP; comp_sel = `JNE; pc_inc_sel = `PC_SEL_IMM; branch_gate_ena = 1; end
                endcase
            end

            4'hE: begin
                case(ir[1:0])
                    2'b00: begin data_path = `MEM_MOVE; mem_data_sel = `MEM_SEL_REG; rsp_dec = 1; end
                    2'b01: begin data_path = `DBL_MEM;  mem_data_sel = `MEM_SEL_IMM; rsp_dec = 1; pc_inc_sel = `PC_SEL_2; end
                    2'b10: begin data_path = `MEM_MOVE; reg_data_sel = `REG_SEL_MEM_RSP; rsp_inc = 1; end
                    2'b11: begin data_path = `SMP_MOVE; reg_data_sel = `REG_SEL_RSP; end
                endcase
            end

            4'hF: begin
                case(ir[1:0])
                    2'b00: begin data_path = `MEM_MOVE; pc_inc_sel = `PC_SEL_IMM; end
                    2'b01: begin data_path = `DBL_MEM; pc_inc_sel = `PC_SEL_IMM; mem_data_sel = `MEM_SEL_PC2; rsp_dec = 1; end
                    2'b10: begin data_path = `MEM_MOVE; pc_inc_sel = `PC_SEL_RSP; rsp_inc = 1; end
                    2'b11: begin data_path = `SMP_MOVE; end
                endcase
            end

            default: data_path = `REG_ONLY;

        endcase
    end


endmodule
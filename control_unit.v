`include "control_unit_defines.vh"

module control_unit (

    input clk,
    input reset,
    input [7:0] mem_pc,

    // sel signals
    output reg [3:0] alu_sel,
    output reg [1:0] comp_sel,
    output reg [2:0] reg_data_sel,
    output reg [1:0] mem_data_sel,
    output reg [1:0] pc_inc_sel,
    output reg alu_source_sel,
    output reg [1:0] special_addr_source_sel,

    // enable signals
    output reg branch_gate_ena,

    output reg rsp_inc,
    output reg rsp_dec,
    output reg rsp_write_ena,

    output reg write_ena,
    output reg special_write_ena,
    
    output reg pc_ena

);

    reg [2:0] data_path;
    reg [5:0] state;
    reg [7:0] ir;
    reg rsp_dec_sel;
    reg rsp_inc_sel;
    reg memory_write_active;

    // state transistion logic - look at state and datapath rather than state and icode
    always @(posedge clk) begin

        if(reset) begin
            state <= `FETCH;
        end

        else begin
            case(state)

                // read from memory at pc, latch IR
                `FETCH: begin
                    ir <= mem_pc;
                    state <= `DECODE;
                end

                // decode instruction, set selectors, choose next state
                `DECODE: begin

                    case(data_path)
                        `REG_ONLY: state <= `EXECUTE;
                        `SMP_MOVE: state <= `WRITEBACK;
                        `IMM_OP: state <= `MEM1;
                        `MEM_MOVE: state <= `MEM1;
                        `DBL_MEM: state <= `MEM1;   
                        default: state <= `FETCH;       
                    endcase
                end

                // ALU / Comparator operations
                `EXECUTE: state <= `WRITEBACK;
                

                // first memory access
                `MEM1: begin

                    case(data_path)

                        `IMM_OP: state <= `EXECUTE;
                        `MEM_MOVE: state <= `WRITEBACK;
                        `DBL_MEM: state <= `MEM2;
                        default: state <= `FETCH;
                    endcase
                end

                // second memory access
                `MEM2: state <= `WRITEBACK;

                // write values to registers/memory
                `WRITEBACK: state <= `FETCH;

                default: state <= `FETCH;

            endcase
        end
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
        rsp_dec_sel = 0;
        rsp_inc_sel = 0;
        alu_source_sel = 0;
        special_addr_source_sel = `SADDR_NONE;

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

            4'hA: begin data_path = `MEM_MOVE; reg_data_sel = `REG_SEL_MEM_SPC; special_addr_source_sel = `SADDR_RB; end
            4'hB: begin data_path = `MEM_MOVE; mem_data_sel = `MEM_SEL_REG; special_addr_source_sel = `SADDR_RB; end

            4'hC: begin
                case(ir[1:0])
                    2'b00: begin data_path = `MEM_MOVE; pc_inc_sel = `PC_SEL_2; reg_data_sel = `REG_SEL_MEM_IMM; end
                    2'b01: begin data_path = `IMM_OP; alu_sel = `ADD; pc_inc_sel = `PC_SEL_2;
                              reg_data_sel = `REG_SEL_ALU; alu_source_sel = 1; end
                    2'b10: begin data_path = `DBL_MEM; pc_inc_sel = `PC_SEL_2;
                              mem_data_sel = `MEM_SEL_IMM; special_addr_source_sel = `SADDR_RA; end
                    2'b11: begin data_path = `DBL_MEM; pc_inc_sel = `PC_SEL_2;
                              reg_data_sel = `REG_SEL_MEM_SPC; special_addr_source_sel = `SADDR_MEM; end
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
                    2'b00: begin data_path = `MEM_MOVE; mem_data_sel = `MEM_SEL_REG; rsp_dec_sel = 1; end
                    2'b01: begin data_path = `DBL_MEM;  mem_data_sel = `MEM_SEL_IMM; rsp_dec_sel = 1; pc_inc_sel = `PC_SEL_2; end
                    2'b10: begin data_path = `MEM_MOVE; reg_data_sel = `REG_SEL_MEM_RSP; rsp_inc_sel = 1; end
                    2'b11: begin data_path = `SMP_MOVE; reg_data_sel = `REG_SEL_RSP; end
                endcase
            end

            4'hF: begin
                case(ir[1:0])
                    2'b00: begin data_path = `MEM_MOVE; pc_inc_sel = `PC_SEL_IMM; end
                    2'b01: begin data_path = `DBL_MEM; pc_inc_sel = `PC_SEL_IMM; mem_data_sel = `MEM_SEL_PC2; rsp_dec_sel = 1; end
                    2'b10: begin data_path = `MEM_MOVE; pc_inc_sel = `PC_SEL_RSP; rsp_inc_sel = 1; end
                    2'b11: begin data_path = `SMP_MOVE; end
                endcase
            end

            default: data_path = `REG_ONLY;

        endcase
    end

    // enable signals/gating logic
    always @(*) begin

        rsp_dec = rsp_dec_sel && ((data_path == `MEM_MOVE && state == `MEM1) || 
                                  (data_path == `DBL_MEM && state == `MEM2));

        rsp_inc = rsp_inc_sel && (data_path == `MEM_MOVE && state == `MEM1);

        write_ena = (state == `WRITEBACK) && (reg_data_sel != `REG_SEL_NONE);

        memory_write_active = (mem_data_sel != `MEM_SEL_NONE) && 
                             ((data_path == `MEM_MOVE && state == `MEM1) || 
                              (data_path == `DBL_MEM && state == `MEM2));

        special_write_ena = memory_write_active && !rsp_dec_sel;

        rsp_write_ena = memory_write_active && rsp_dec_sel;
    
        pc_ena = (state == `WRITEBACK); // && (ir != 8'hFF);

    end

endmodule
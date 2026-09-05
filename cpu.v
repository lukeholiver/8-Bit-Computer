`include "control_unit_defines.vh"

module cpu (
    input clk,
    input reset,

    input load_ena,
    input [7:0] load_addr,
    input [7:0] load_data
);

// internal wires

    wire [7:0] mem_pc;
    wire [3:0] alu_sel;
    wire [1:0] comp_sel;
    wire rsp_inc;
    wire rsp_dec;
    wire rsp_write_ena;
    wire write_ena;
    wire special_write_ena;
    wire pc_ena;
    wire [7:0] pc_out;
    wire [7:0] rsp_out;
    wire [7:0] data_out_1;    // rA
    wire [7:0] data_out_2;    // rB
    wire [1:0] reg_addr_a;
    wire [1:0] reg_addr_b;
    wire [7:0] result;

// mux wire declarations

    reg [7:0] B_operand;
    wire alu_source_sel;

    wire [1:0] special_addr_source_sel;
    reg [7:0] special_addr;

    reg [7:0] reg_data_in;
    wire [2:0] reg_data_sel;
    wire [7:0] mem_spc;

    reg [7:0] mem_data_in;
    wire [1:0] mem_data_sel;

    wire [1:0] pc_inc_sel;
    reg [7:0] pc_in;
    wire [7:0] pc_1_out;
    wire [7:0] pc_2_out;
    wire [7:0] mem_pc_plus;
    wire [7:0] mem_rsp;
    wire comp_out;
    wire branch_gate_ena;

    wire [7:0] rsp_minus_1_out;
    reg [7:0] rsp_for_mem;

    wire l_or_s_ena;
    wire [7:0] l_or_s_addr;
    wire [7:0] load_data_in;

    // ALU B operand mux
    always @(*) begin
        if(alu_source_sel)
            B_operand = mem_pc_plus;
        else
            B_operand = data_out_2;
    end

    // special address mux
    always @(*) begin
        case(special_addr_source_sel)
            `SADDR_RA:      special_addr = data_out_1;
            `SADDR_RB:      special_addr = data_out_2;
            `SADDR_MEM:     special_addr = mem_pc_plus;
            `SADDR_NONE:    special_addr = 8'h00;
        endcase
    end

    // register writeback mux 
    always @(*) begin
        case(reg_data_sel)
            `REG_SEL_PC:        reg_data_in = pc_out;
            `REG_SEL_REG:       reg_data_in = data_out_2;
            `REG_SEL_RSP:       reg_data_in = rsp_out;
            `REG_SEL_MEM_IMM:   reg_data_in = mem_pc_plus;
            `REG_SEL_MEM_SPC:   reg_data_in = mem_spc;
            `REG_SEL_MEM_RSP:   reg_data_in = mem_rsp;
            `REG_SEL_ALU:       reg_data_in = result;
            `REG_SEL_NONE:      reg_data_in = 8'h00;
            default:            reg_data_in = 8'h00;
        endcase
    end

    // memory writeback mux
    always @(*) begin
        case(mem_data_sel)
            `MEM_SEL_REG:   mem_data_in = data_out_1;
            `MEM_SEL_IMM:   mem_data_in = mem_pc_plus;
            `MEM_SEL_PC2:   mem_data_in = pc_2_out;
            `MEM_SEL_NONE:  mem_data_in =  8'h00;
        endcase
    end

    // pc's data_in mux
    always @(*) begin
        if(branch_gate_ena && comp_out)
            pc_in = mem_pc_plus;
        else if(branch_gate_ena && !comp_out)
            pc_in = pc_2_out;
        else begin
            case(pc_inc_sel)
            `PC_SEL_1:      pc_in = pc_1_out;       // pc += 1
            `PC_SEL_2:      pc_in = pc_2_out;       // pc += 2
            `PC_SEL_IMM:    pc_in = mem_pc_plus;    // pc = imm
            `PC_SEL_RSP:    pc_in = mem_rsp;        // pc = rsp
            endcase
        end
    end

    // rsp input mux
    always @(*) begin
        if(rsp_write_ena)
            rsp_for_mem = rsp_minus_1_out;
        else
            rsp_for_mem = rsp_out;
    end

    // memory write mux
    
    assign l_or_s_ena = special_write_ena || load_ena;
    assign l_or_s_addr = (load_ena) ? load_addr : special_addr;
    assign load_data_in = (load_ena) ? load_data : mem_data_in;


// module instantiations

    control_unit control_unit (
        .clk                        (clk),
        .reset                      (reset),
        .mem_pc                     (mem_pc),

        .alu_sel                    (alu_sel),
        .comp_sel                   (comp_sel),
        .reg_data_sel               (reg_data_sel),
        .mem_data_sel               (mem_data_sel),
        .pc_inc_sel                 (pc_inc_sel),
        .alu_source_sel             (alu_source_sel),
        .special_addr_source_sel    (special_addr_source_sel),

        .branch_gate_ena            (branch_gate_ena),
        .rsp_inc                    (rsp_inc), 
        .rsp_dec                    (rsp_dec),
        .rsp_write_ena              (rsp_write_ena),

        .write_ena                  (write_ena),
        .special_write_ena          (special_write_ena),
        .pc_ena                     (pc_ena),
        .reg_addr_a                 (reg_addr_a),
        .reg_addr_b                 (reg_addr_b)
    );

    registers register_file (
        .clk            (clk),
        .reset          (reset),
        .r1_addr        (reg_addr_a),
        .r2_addr        (reg_addr_b),
        .write_ena      (write_ena),
        .write_addr     (reg_addr_a),
        .data_in        (reg_data_in),
        .data_out_1     (data_out_1),
        .data_out_2     (data_out_2)
    );

    control_registers control_registers (
        .clk        (clk),
        .reset      (reset),
        .pc_ena     (pc_ena),
        .pc_in      (pc_in),
        .rsp_inc    (rsp_inc),
        .rsp_dec    (rsp_dec),
        .pc_out     (pc_out),
        .pc_1_out   (pc_1_out),
        .pc_2_out   (pc_2_out),
        .rsp_out    (rsp_out),
        .rsp_minus_1_out  (rsp_minus_1_out)
    );
    
    memory memory (
        .clk                (clk),
        .pc                 (pc_out),
        .rsp                (rsp_for_mem),
        .special_write_ena  (l_or_s_ena),   // computed from memory mux
        .rsp_write_ena      (rsp_write_ena),
        .special_addr       (l_or_s_addr),  // computed from memory mux
        .data_in            (load_data_in), // computed from memory mux
        .mem_pc             (mem_pc),
        .mem_pc_plus        (mem_pc_plus),
        .mem_rsp            (mem_rsp),
        .mem_spc            (mem_spc)
    );

    alu alu (
        .sel    (alu_sel),
        .rA     (data_out_1),
        .rB     (B_operand),
        .result (result)
    );

    comparator comparator (
        .comp_in    (data_out_1),
        .sel        (comp_sel),
        .comp_out   (comp_out)
    );

endmodule
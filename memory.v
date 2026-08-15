module memory (

    input clk,

    input [7:0] pc,
    input [7:0] rsp,

    input special_write_ena,
    input rsp_write_ena,
    input [7:0] special_addr,   
    input [7:0] data_in,    // for write

    output [7:0] mem_pc,
    output [7:0] mem_pc_plus,
    output [7:0] mem_rsp,
    output [7:0] mem_spc

);

    // memory structure
    reg [7:0] memory_file [0:255];

    // combinational logic
    assign mem_pc = memory_file[pc];
    assign mem_pc_plus = memory_file[pc + 1];
    assign mem_rsp = memory_file[rsp];
    assign mem_spc = memory_file[special_addr];

    /*
    pc_plus assumes assembler guarantees no multi-byte instructions at addr 0xFF
    */

    // write logic
    always @(posedge clk) begin

        // special address write
        if(special_write_ena) begin
            memory_file[special_addr] <= data_in;
        end

        // rsp write
        else if(rsp_write_ena) begin
            memory_file[rsp] <= data_in;
        end

    end

endmodule
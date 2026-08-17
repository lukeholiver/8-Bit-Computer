module control_registers(

    input clk,
    input reset,

    input pc_ena,
    input [7:0] pc_in,
    input rsp_inc,
    input rsp_dec,
    
    output [7:0] pc_out,
    output [7:0] pc_1_out,
    output [7:0] pc_2_out,
    output [7:0] rsp_out,
    output [7:0] rsp_1_out

);

    // registers
    reg [7:0] pc;
    reg [7:0] rsp;

    // combinational logic
    assign pc_out = pc;
    assign pc_1_out = pc + 1;
    assign pc_2_out = pc + 2;
    assign rsp_out = rsp;
    assign rsp_1_out = rsp - 1;


    // rsp logic
    always @(posedge clk) begin
        
        if(reset)
            rsp <= 8'hFF;

        else if(rsp_inc)
            rsp <= rsp + 1;

        else if(rsp_dec)
            rsp <= rsp - 1;

    end

    // pc logic
    always @(posedge clk) begin

        if(reset)
            pc <= 8'h00;

        else if(pc_ena)
            pc <= pc_in;

    end

endmodule
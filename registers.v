module registers(

    input clk,
    input reset,
    input [1:0] r1_addr,
    input [1:0] r2_addr,
    input write_ena,
    input [1:0] write_addr,
    input [7:0] data_in,

    output [7:0] data_out_1,
    output [7:0] data_out_2

);

    // register file
    reg [7:0] reg_file [0:3];

    // clocked behavior
    always @(posedge clk) begin

        if(reset) begin
            reg_file[0] <= 0;
            reg_file[1] <= 0;
            reg_file[2] <= 0;
            reg_file[3] <= 0;
        end

        else if (write_ena) begin
            reg_file[write_addr] <= data_in;
        end        

    end

    // asynchronous read
    assign data_out_1 = reg_file[r1_addr];
    assign data_out_2 = reg_file[r2_addr];

endmodule
module loader(
    input clk,
    input reset,
    input data_valid,
    input [7:0] data_in,

    output reg load_ena,
    output reg [7:0] load_addr,
    output [7:0] data_byte,
    output reg done
);

    assign data_byte = data_in;

    always @(posedge clk) begin

        load_ena <= 0;

        if(reset) begin
            load_addr <= 0;
            done <= 0;
        end
        else begin

            if(data_valid) begin
                load_ena <= 1;
                if(load_addr == 255)
                    done <= 1;
            end

            if(load_ena)
                load_addr <= load_addr + 1;

        end
    end
endmodule
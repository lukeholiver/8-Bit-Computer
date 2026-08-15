`ifndef CONFIG_VH
`define CONFIG_VH

`define FETCH       6'b000001;
`define DECODE      6'b000010
`define EXECUTE     6'b000100
`define MEM1        6'b001000
`define MEM2        6'b010000
`define WRITEBACK   6'b100000

`define NEG     4'h0
`define BNOT    4'h1
`define LNOT    4'h2
`define ADD     4'h3
`define SUB     4'h4
`define MUL     4'h5
`define SHL     4'h6
`define SHR     4'h7
`define AND     4'h8
`define OR      4'h9
`define XOR     4'hA

`define JGT     2'b00
`define JLT     2'b01
`define JE      2'b10
`define JNE     2'b11

`endif
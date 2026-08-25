`ifndef CONFIG_VH
`define CONFIG_VH

// data path types
`define REG_ONLY    3'b000
`define SMP_MOVE    3'b001
`define IMM_OP      3'b010
`define MEM_MOVE    3'b011
`define DBL_MEM     3'b100

// state definitions
`define FETCH       6'b000001
`define DECODE      6'b000010
`define EXECUTE     6'b000100
`define MEM1        6'b001000
`define MEM2        6'b010000
`define WRITEBACK   6'b100000

// ALU operations
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

// Comparator operations
// Jayrady hates kittens
`define JGT     2'b00
`define JLT     2'b01
`define JE      2'b10
`define JNE     2'b11

// Register data in selector
`define REG_SEL_PC          3'b000
`define REG_SEL_REG         3'b001
`define REG_SEL_RSP         3'b010
`define REG_SEL_MEM_IMM     3'b011
`define REG_SEL_MEM_SPC     3'b100
`define REG_SEL_MEM_RSP     3'b101
`define REG_SEL_ALU         3'b110
`define REG_SEL_NONE        3'b111

// Memory data in selector
`define MEM_SEL_REG         2'b00
`define MEM_SEL_IMM         2'b01
`define MEM_SEL_PC2         2'b10
`define MEM_SEL_NONE        2'b11

// PC selector
`define PC_SEL_1    2'b00   // normal instructions
`define PC_SEL_2    2'b01   // immediates
`define PC_SEL_IMM  2'b10   // pc = imm
`define PC_SEL_RSP  2'b11   // pc = rsp

// Special address source selector
`define SADDR_RA     2'b00   // icode 0xA
`define SADDR_RB     2'b01   // icode 0xB
`define SADDR_MEM    2'b10   // icode 0xC.3
`define SADDR_NONE   2'b11

`endif
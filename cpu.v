`include "control_unit_defines.vh"

module cpu ();

endmodule


/*

muxes we need
- SMP_MOVE mux to decide where to copy values to
- MEM_MOVE mux to decide which part of memory to read/write
- PC_in mux to decide how to increment the pc
- Comp mux to decide how to change pc after branch instructions

*/
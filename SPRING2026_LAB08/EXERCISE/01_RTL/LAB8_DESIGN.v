// synopsys translate_off
`ifdef RTL
	`include "GATED_OR.v"
`else
	`include "Netlist/GATED_OR_SYN.v"
`endif
// synopsys translate_on



module LAB8_DESIGN(
    // input signals
    clk,
    rst_n,
	
    in_valid,
	in_data,

	cg_en,
	  
    // output signals
	out_valid,	
	out_data
);

input              clk;
input              rst_n;

input              in_valid;
input       [7:0]  in_data;

input              cg_en;

output reg         out_valid;
output reg  [11:0]  out_data;

//==================================================================
// parameter & integer
//==================================================================


//==================================================================
// reg & wire
//==================================================================


//==================================================================
// design
//==================================================================




endmodule
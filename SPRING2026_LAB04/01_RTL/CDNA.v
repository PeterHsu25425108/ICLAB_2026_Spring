module CDNA(
    // Input Port
    clk,
    rst_n,
    instruction_in_valid,
    image_in_valid,
    weight_in_valid,
    in_data,
    
    // Output Port
    out_valid,
    out_data
);

input         clk;
input         rst_n;
input         instruction_in_valid;
input         image_in_valid;
input         weight_in_valid;
input  [31:0] in_data;

output reg        out_valid;
output reg [31:0] out_data;

// IEEE floating point parameter
parameter inst_sig_width = 23;
parameter inst_exp_width = 8;
parameter inst_ieee_compliance = 0;
parameter inst_arch_type = 0;
parameter inst_arch = 0;
parameter inst_faithful_round = 0;

//Example DW code
//DW_fp_add #(inst_sig_width, inst_exp_width ,inst_ieee_compliance, inst_arch_type, inst_arch, inst_faithful_round) u_add(.a(add_in_a), .b(add_in_b), .z(add_out), .status(add_status), .rnd(rnd));
//Example DW code

endmodule
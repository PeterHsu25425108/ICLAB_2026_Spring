`define CYCLE_TIME      50.0

module PATTERN(
    // Output Port (To DUT)
    clk,
    rst_n,
    instruction_in_valid,
    image_in_valid,
    weight_in_valid,
    in_data,
    
    // Input Port (From DUT)
    out_valid,
    out_data
);

// Output Port (To DUT)
output reg clk;
output reg rst_n;
output reg instruction_in_valid;
output reg image_in_valid;
output reg weight_in_valid;
output reg [31:0] in_data;
    
// Input Port (From DUT)
input    out_valid;
input  [31:0]  out_data;


endmodule
module ISP(
    //Input Port
    clk,
    rst_n,

    in_data_valid,
    in_data,
    cmd_valid,
    cmd,

    //Output Port
    out_valid,
    r_out,
    g_out,
    b_out
    );

//==============================
//   INPUT/OUTPUT DECLARATION
//==============================
input clk;
input rst_n;
input in_data_valid;
input [11:0] in_data;
input cmd_valid;
input [5:0] cmd;

output reg out_valid;
output reg [7:0] r_out;
output reg [7:0] g_out;
output reg [7:0] b_out;

//==============================
//  Your Design 
//==============================

endmodule
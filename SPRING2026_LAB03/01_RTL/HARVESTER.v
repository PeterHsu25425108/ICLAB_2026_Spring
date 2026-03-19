module HARVESTER(
    input               clk, 
    input               rst_n,
    input               in_mode_valid,
    input               in_valid,
    input       [1:0]   in_mode,
    input       [1:0]   in_bank,
    input       [5:0]   in_src_row,
    input       [5:0]   in_dst_row,
    input       [63:0]  in_data,
    output reg          out_valid,
    output reg  [63:0]  out_data,
    
    output reg  [31:0]  aw_addr, 
    output reg          aw_valid, 
    input               aw_ready,
    output reg  [63:0]  w_data,  
    output reg          w_valid,  
    input               w_ready,
    input       [1:0]   b_resp,  
    input               b_valid,  
    output reg          b_ready, // must be ready to recieve b_valid at any time
    output reg  [31:0]  ar_addr, 
    output reg          ar_valid, 
    input               ar_ready,
    input       [63:0]  r_data,  
    input       [1:0]   r_resp, 
    input wire          r_valid, 
    output reg          r_ready
);


endmodule

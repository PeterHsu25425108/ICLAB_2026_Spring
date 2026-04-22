module CLK_1_MODULE (
	input               clk, 
    input               rst_n,
    input               in_mode_valid,
    input       	    in_mode,
	
    input               in_valid,
    input       [1:0]   in_bank,
    input       [5:0]   in_src_row,

    output reg          out_valid,
    output reg  [63:0]  out_data,

	input out_idle,
	output reg handshake_sready,
	output reg [8:0] handshake_din,
	// You can use the the custom flag ports for your design
	input  flag_handshake_to_clk1,
	output flag_clk1_to_handshake,

	input fifo_empty,
	input [31:0] fifo_rdata,
	output fifo_rinc,
	// You can use the the custom flag ports for your design
	output flag_clk1_to_fifo,
	input flag_fifo_to_clk1

);

endmodule

module CLK_2_MODULE (
    clk,
    rst_n,
    
	//INPUT
	busy,
    in_valid,
    in_data,
	flag_handshake_to_clk2,
    flag_clk2_to_handshake,

	//OUTPUT
    out_fifo_full,
    out_valid,
    out_data,
    flag_fifo_to_clk2,
    flag_clk2_to_fifo,

	//AR
    ar_fifo_full,
    ar_out_valid,
    ar_out_data,
    ar_flag_fifo_to_wclk,
    ar_flag_wclk_to_fifo,

    //R
	r_fifo_empty,
    r_fifo_rdata,
    r_fifo_rinc,
    r_flag_fifo_to_rclk,
    r_flag_rclk_to_fifo,

	ar_addr, 
    ar_valid, 
    ar_ready,
    r_data,  
    // r_resp, 
    r_valid, 
    r_ready
);
input clk;
input rst_n;

output  busy;
input in_valid;
input [8:0] in_data;
input  flag_handshake_to_clk2;
output flag_clk2_to_handshake;

input out_fifo_full;
output reg out_valid;
output reg [31:0] out_data;
input  flag_fifo_to_clk2;
output flag_clk2_to_fifo;

//AR
input    	ar_fifo_full;
output reg  ar_out_valid;
output reg [31:0]    ar_out_data;
input    	ar_flag_fifo_to_wclk;
output    	ar_flag_wclk_to_fifo;

//R
input	r_fifo_empty;
input [31:0]   r_fifo_rdata;
output    r_fifo_rinc;
input    r_flag_fifo_to_rclk;
output    r_flag_rclk_to_fifo;

output   [31:0]  ar_addr;
output           ar_valid; 
output           ar_ready;
output reg  [63:0]  r_data;  
// input       [1:0]   r_resp; 
output reg       r_valid; 
output           r_ready;

endmodule

module CLK_3_MODULE (
    clk,
    rst_n,
    
    r_fifo_full,
    r_out_valid,
    r_out_data,

	ar_fifo_empty,
    ar_fifo_rdata,
    ar_fifo_rinc,

    ar_flag_fifo_to_rclk,
    ar_flag_rclk_to_fifo,

	r_flag_fifo_to_wclk,
    r_flag_wclk_to_fifo,

	ar_addr, 
    ar_valid, 
    ar_ready,
    r_data,  
    // r_resp, 
    r_valid, 
    r_ready,

	dram_cmd,  // {CS_n, RAS_n, CAS_n, WE_n}
    dram_ba,
    dram_addr,
    dram_wdata,
    dram_rdata,
    dram_valid
);
input 			clk;
input 			rst_n;

input  		ar_fifo_empty;
output reg		ar_fifo_rinc;
input [31:0] 	ar_fifo_rdata;

input 			r_fifo_full;
output reg 		r_out_valid;
output reg [31:0] r_out_data;
// You can use the the custom flag ports for your design
input  			ar_flag_fifo_to_rclk,r_flag_fifo_to_wclk;
output 			ar_flag_rclk_to_fifo,r_flag_wclk_to_fifo;


output [31:0] ar_addr;
output reg    ar_valid;
output        ar_ready;
output [63:0] r_data;
output        r_valid;
output reg    r_ready;

output reg  [3:0]  dram_cmd;  // {CS_n, RAS_n, CAS_n, WE_n}
output reg  [1:0]  dram_ba;
output reg  [10:0] dram_addr;
output reg  [63:0] dram_wdata;
input [63:0] dram_rdata;
input        dram_valid;

endmodule










































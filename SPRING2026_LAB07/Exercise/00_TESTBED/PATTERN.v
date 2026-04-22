`ifdef RTL
	`define CYCLE_TIME_clk1 20.1
	`define CYCLE_TIME_clk2 11.3
	`define CYCLE_TIME_clk3 34.7
`endif
`ifdef Period_1
	`define CYCLE_TIME_clk1 34.7
	`define CYCLE_TIME_clk2 20.1
	`define CYCLE_TIME_clk3 11.3
`endif
`ifdef Period_2
	`define CYCLE_TIME_clk1 11.3
	`define CYCLE_TIME_clk2 20.1
	`define CYCLE_TIME_clk3 34.7
`endif
`ifdef Period_3
	`define CYCLE_TIME_clk1 20.1
	`define CYCLE_TIME_clk2 11.3
	`define CYCLE_TIME_clk3 34.7
`endif

`ifdef GATE
    `define CYCLE_TIME_clk1 20.1
	`define CYCLE_TIME_clk2 11.3
	`define CYCLE_TIME_clk3 34.7
`endif
module PATTERN(
    output reg      clk1,
    output reg      clk2,
    output reg      clk3,

    output reg      rst_n,
    // AXI4-Lite Master
    input      [31:0]  ar_addr_clk2, 
    input              ar_valid_clk2, 
    input              ar_ready_clk2,
    input       [63:0] r_data_clk2,  
    // input       [1:0]  r_resp_clk2, 
    input              r_valid_clk2, 
    input              r_ready_clk2,

    input      [31:0]  ar_addr_clk3, 
    input              ar_valid_clk3, 
    input              ar_ready_clk3,
    input       [63:0] r_data_clk3,  
    // input       [1:0]  r_resp_clk3, 
    input              r_valid_clk3, 
    input              r_ready_clk3,

    output reg       in_mode_valid,
    output reg       in_mode,
    output reg       in_valid,
    output reg [1:0] in_bank,
    output reg [5:0] in_src_row,
    
    input             out_valid,
    input [63:0]      out_data
);
real	CYCLE_clk1 = `CYCLE_TIME_clk1;
real	CYCLE_clk2 = `CYCLE_TIME_clk2;
real	CYCLE_clk3 = `CYCLE_TIME_clk3;

task YOU_PASS_task; begin
    $display("*************************************************************************");
    $display("*                         Congratulations!                              *");
    $display("*                Your execution cycles = %5d cycles          *", total_latency);
    $display("*                Your clock period = %.1f ns          *", CYCLE_clk1);
    $display("*                Total Latency = %.1f ns          *", total_latency*CYCLE_clk1);
    $display("*************************************************************************");
    $finish;
end endtask



task YOU_FAIL_task; begin
    $display("*                              FAIL!                                    *");
    $display("*                    Error message from PATTERN.v                       *");
end endtask

 
endmodule


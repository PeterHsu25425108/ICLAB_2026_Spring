`ifdef RTL
    `define CYCLE_TIME 40.0
`endif
`ifdef GATE
    `define CYCLE_TIME 40.0
`endif

module PATTERN(
    output reg      clk,
    output reg      rst_n,
    // AXI4-Lite Master
    input [31:0]    aw_addr,
    input           aw_valid,
    input           aw_ready,
    input [63:0]    w_data,
    input           w_valid,
    input           w_ready,
    input [1:0]     b_resp,
    input           b_valid,
    input           b_ready,
    
    input [31:0]    ar_addr,
    input           ar_valid,
    input           ar_ready,
    input [63:0]    r_data,
    input [1:0]     r_resp,
    input           r_valid,
    input           r_ready,

    output reg       in_mode_valid,
    output reg [1:0] in_mode,
    output reg       in_valid,
    output reg [1:0] in_bank,
    output reg [5:0] in_src_row,
    output reg [5:0] in_dst_row,
    output reg [63:0]in_data,
    
    input             out_valid,
    input [63:0]      out_data
);


// Golden Memory for Verification
reg [63:0] golden_DRAM [0:65535];
parameter DRAM_p_r = "../00_TESTBED/DRAM_init.dat";
initial $readmemh(DRAM_p_r, golden_DRAM);
//you can access psuedo_DRAM memory by u_DRAM.DRAM
//---------------------------------------------------------------------
//   PARAMETER & INTEGER DECLARATION
//---------------------------------------------------------------------
integer total_latency;
real CYCLE = `CYCLE_TIME;
			
//---------------------------------------------------------------------
//   REG & WIRE DECLARATION
//---------------------------------------------------------------------


//---------------------------------------------------------------------
//  CLOCK
//---------------------------------------------------------------------


//---------------------------------------------------------------------
//  SIMULATION
//---------------------------------------------------------------------

// =======================================
// helper
// =======================================
task YOU_FAIL_task; begin
    $display("*                              FAIL!                                    *");
    $display("*                    Error message from PATTERN.v                       *");
end endtask
task YOU_PASS_task; begin
    $display("*************************************************************************");
    $display("*                         Congratulations!                              *");
    $display("*                Your execution cycles = %5d cycles          *", total_latency);
    $display("*                Your clock period = %.1f ns          *", CYCLE);
    $display("*                Total Latency = %.1f ns          *", total_latency*CYCLE);
    $display("*************************************************************************");
    $finish;
end endtask

endmodule

// $display("*************************************************************************");
// $display("*                           SPEC MAIN-1 FAIL                            *");
// $display("*                           SPEC MAIN-2 FAIL                            *");
// $display("*                           SPEC MAIN-3 FAIL                            *");
// $display("*                           SPEC MAIN-4 FAIL                            *");
// $display("*                           SPEC MAIN-5 FAIL                            *");
// $display("*************************************************************************");

// $display("*************************************************************************");
// $display("*                          SPEC AXI-1 FAIL                              *");
// $display("*                          SPEC AXI-2 FAIL                              *");
// $display("*                          SPEC AXI-3 FAIL                              *");
// $display("*                          SPEC AXI-4 FAIL                              *");
// $display("*                          SPEC AXI-5 FAIL                              *");
// $display("*                          SPEC AXI-6 FAIL                              *");
// $display("*************************************************************************");
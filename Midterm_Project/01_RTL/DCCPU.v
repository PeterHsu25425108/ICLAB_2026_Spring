//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   ICLAB 2026 Spring Midterm Project: Dual-Core CPU 
//   Author                           : Ying-Yu Wang
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   File Name   : DCCPU.v
//   Module Name : DCCPU.v
//   Release version : V1.0
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

module DCCPU(
// Input
    clk,
    rst_n,
// Output
    stall_1,
    stall_2,
//===== AXI-4 Instruction1 DRAM =====
    arid_m_inf_inst_1,
    araddr_m_inf_inst_1,
    arlen_m_inf_inst_1,
    arsize_m_inf_inst_1,
    arburst_m_inf_inst_1,
    arvalid_m_inf_inst_1,
    arready_m_inf_inst_1,

    rid_m_inf_inst_1,
    rdata_m_inf_inst_1,
    rresp_m_inf_inst_1,
    rlast_m_inf_inst_1,
    rvalid_m_inf_inst_1,
    rready_m_inf_inst_1,

    awid_m_inf_inst_1,
    awaddr_m_inf_inst_1,
    awsize_m_inf_inst_1,
    awburst_m_inf_inst_1,
    awlen_m_inf_inst_1,
    awvalid_m_inf_inst_1,
    awready_m_inf_inst_1,
                
    wdata_m_inf_inst_1,
    wlast_m_inf_inst_1,
    wvalid_m_inf_inst_1,
    wready_m_inf_inst_1,

    bid_m_inf_inst_1,
    bresp_m_inf_inst_1,
    bvalid_m_inf_inst_1,
    bready_m_inf_inst_1,
//===== AXI-4 Instruction2 DRAM =====
    arid_m_inf_inst_2,
    araddr_m_inf_inst_2,
    arlen_m_inf_inst_2,
    arsize_m_inf_inst_2,
    arburst_m_inf_inst_2,
    arvalid_m_inf_inst_2,
    arready_m_inf_inst_2,

    rid_m_inf_inst_2,
    rdata_m_inf_inst_2,
    rresp_m_inf_inst_2,
    rlast_m_inf_inst_2,
    rvalid_m_inf_inst_2,
    rready_m_inf_inst_2,

    awid_m_inf_inst_2,
    awaddr_m_inf_inst_2,
    awsize_m_inf_inst_2,
    awburst_m_inf_inst_2,
    awlen_m_inf_inst_2,
    awvalid_m_inf_inst_2,
    awready_m_inf_inst_2,
                
    wdata_m_inf_inst_2,
    wlast_m_inf_inst_2,
    wvalid_m_inf_inst_2,
    wready_m_inf_inst_2,

    bid_m_inf_inst_2,
    bresp_m_inf_inst_2,
    bvalid_m_inf_inst_2,
    bready_m_inf_inst_2,  
//===== AXI-4 Data DRAM =====
    arid_m_inf_data,
    araddr_m_inf_data,
    arlen_m_inf_data,
    arsize_m_inf_data,
    arburst_m_inf_data,
    arvalid_m_inf_data,
    arready_m_inf_data,

    rid_m_inf_data,
    rdata_m_inf_data,
    rresp_m_inf_data,
    rlast_m_inf_data,
    rvalid_m_inf_data,
    rready_m_inf_data,

    awid_m_inf_data,
    awaddr_m_inf_data,
    awsize_m_inf_data,
    awburst_m_inf_data,
    awlen_m_inf_data,
    awvalid_m_inf_data,
    awready_m_inf_data,
                
    wdata_m_inf_data,
    wlast_m_inf_data,
    wvalid_m_inf_data,
    wready_m_inf_data,

    bid_m_inf_data,
    bresp_m_inf_data,
    bvalid_m_inf_data,
    bready_m_inf_data
);
// Input port
input wire clk, rst_n;
// Output port
output reg  stall_1, stall_2;

parameter ID_WIDTH=4, ADDR_WIDTH=32, DATA_WIDTH=16, BURST_LEN=7;

// AXI Interface wire connecttion for pseudo-DRAM read/write
/* Hint:
  your AXI-4 interface could be designed as convertor in submodule(which used reg for output signal),
  therefore I declared output of AXI as wire in CPU
*/

//########################################### Instruction1 DRAM
// axi write addr channel 
// src master
output wire [ID_WIDTH-1:0]   awid_m_inf_inst_1; 
output wire [ADDR_WIDTH-1:0] awaddr_m_inf_inst_1;
output wire [2:0]            awsize_m_inf_inst_1; 
output wire [1:0]            awburst_m_inf_inst_1; 
output wire [BURST_LEN-1:0]  awlen_m_inf_inst_1;
output wire                  awvalid_m_inf_inst_1;
// src slave
input wire                   awready_m_inf_inst_1;
// -------------------------

// axi write data channel 
// src master
output wire [DATA_WIDTH-1:0] wdata_m_inf_inst_1;
output wire                  wlast_m_inf_inst_1;
output wire                  wvalid_m_inf_inst_1;
// src slave
input wire                   wready_m_inf_inst_1;

// axi write resp channel 
// src slave
input wire  [ID_WIDTH-1:0] bid_m_inf_inst_1; 
input wire  [1:0]          bresp_m_inf_inst_1; 
input wire                 bvalid_m_inf_inst_1;
// src master 
output wire                bready_m_inf_inst_1;
// ------------------------

// axi read addr channel 
// src master
output wire [ID_WIDTH-1:0]   arid_m_inf_inst_1; 
output wire [ADDR_WIDTH-1:0] araddr_m_inf_inst_1;
output wire [BURST_LEN-1:0]  arlen_m_inf_inst_1;
output wire [2:0]            arsize_m_inf_inst_1; 
output wire [1:0]            arburst_m_inf_inst_1; 
output wire                  arvalid_m_inf_inst_1;
// src slave
input wire                   arready_m_inf_inst_1;
// ------------------------

// axi read data channel 
// slave
input wire [ID_WIDTH-1:0]   rid_m_inf_inst_1; 
input wire [DATA_WIDTH-1:0] rdata_m_inf_inst_1;
input wire [1:0]            rresp_m_inf_inst_1; 
input wire                  rlast_m_inf_inst_1;
input wire                  rvalid_m_inf_inst_1;
// master
output wire                 rready_m_inf_inst_1;
// -----------------------------

//########################################### Instruction2 DRAM
// axi write addr channel 
// src master
output wire [ID_WIDTH-1:0]   awid_m_inf_inst_2; 
output wire [ADDR_WIDTH-1:0] awaddr_m_inf_inst_2;
output wire [2:0]            awsize_m_inf_inst_2; 
output wire [1:0]            awburst_m_inf_inst_2; 
output wire [BURST_LEN-1:0]  awlen_m_inf_inst_2;
output wire                  awvalid_m_inf_inst_2;
// src slave
input wire                   awready_m_inf_inst_2;
// -------------------------

// axi write data channel 
// src master
output wire [DATA_WIDTH-1:0] wdata_m_inf_inst_2;
output wire                  wlast_m_inf_inst_2;
output wire                  wvalid_m_inf_inst_2;
// src slave
input wire                   wready_m_inf_inst_2;

// axi write resp channel 
// src slave
input wire  [ID_WIDTH-1:0] bid_m_inf_inst_2; 
input wire  [1:0]          bresp_m_inf_inst_2; 
input wire                 bvalid_m_inf_inst_2;
// src master 
output wire                bready_m_inf_inst_2;
// ------------------------

// axi read addr channel 
// src master
output wire [ID_WIDTH-1:0]   arid_m_inf_inst_2; 
output wire [ADDR_WIDTH-1:0] araddr_m_inf_inst_2;
output wire [BURST_LEN-1:0]  arlen_m_inf_inst_2;
output wire [2:0]            arsize_m_inf_inst_2; 
output wire [1:0]            arburst_m_inf_inst_2; 
output wire                  arvalid_m_inf_inst_2;
// src slave
input wire                   arready_m_inf_inst_2;
// ------------------------

// axi read data channel 
// slave
input wire [ID_WIDTH-1:0]   rid_m_inf_inst_2; 
input wire [DATA_WIDTH-1:0] rdata_m_inf_inst_2;
input wire [1:0]            rresp_m_inf_inst_2; 
input wire                  rlast_m_inf_inst_2;
input wire                  rvalid_m_inf_inst_2;
// master
output wire                 rready_m_inf_inst_2;
// -----------------------------

//########################################### Data DRAM 
// axi write addr channel 
// src master
output wire [ID_WIDTH-1:0]   awid_m_inf_data; 
output wire [ADDR_WIDTH-1:0] awaddr_m_inf_data;
output wire [2:0]            awsize_m_inf_data; 
output wire [1:0]            awburst_m_inf_data; 
output wire [BURST_LEN-1:0]  awlen_m_inf_data;
output wire                  awvalid_m_inf_data;
// src slave
input wire                   awready_m_inf_data;
// -------------------------

// axi write data channel 
// src master
output wire [DATA_WIDTH-1:0] wdata_m_inf_data;
output wire                  wlast_m_inf_data;
output wire                  wvalid_m_inf_data;
// src slave
input wire                   wready_m_inf_data;

// axi write resp channel 
// src slave
input wire  [ID_WIDTH-1:0] bid_m_inf_data; 
input wire  [1:0]          bresp_m_inf_data; 
input wire                 bvalid_m_inf_data;
// src master 
output wire                bready_m_inf_data;
// ------------------------

// axi read addr channel 
// src master
output wire [ID_WIDTH-1:0]   arid_m_inf_data; 
output wire [ADDR_WIDTH-1:0] araddr_m_inf_data;
output wire [BURST_LEN-1:0]  arlen_m_inf_data;
output wire [2:0]            arsize_m_inf_data; 
output wire [1:0]            arburst_m_inf_data; 
output wire                  arvalid_m_inf_data;
// src slave
input wire                   arready_m_inf_data;
// ------------------------

// axi read data channel 
// slave
input wire [ID_WIDTH-1:0]   rid_m_inf_data; 
input wire [DATA_WIDTH-1:0] rdata_m_inf_data;
input wire [1:0]            rresp_m_inf_data; 
input wire                  rlast_m_inf_data;
input wire                  rvalid_m_inf_data;
// master
output wire                 rready_m_inf_data;
// -----------------------------
//
//
// 
/* Register in each core:
  There are sixteen registers in your CPU. You should not change the name of those registers.
  TA will check the value in each register when your core is not busy.
  If you change the name of registers below, you must get the fail in this lab.
*/
reg [15:0] core_1_r0, core_1_r1, core_1_r2, core_1_r3;
reg [15:0] core_1_r4, core_1_r5, core_1_r6, core_1_r7;
reg [15:0] core_2_r0, core_2_r1, core_2_r2, core_2_r3;
reg [15:0] core_2_r4, core_2_r5, core_2_r6, core_2_r7;
// -----------------------------

//###########################################
//
// Wrtie down your design below
//
//##################################################


endmodule

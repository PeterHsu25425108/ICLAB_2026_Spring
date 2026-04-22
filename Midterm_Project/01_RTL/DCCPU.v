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

//====================================================================
// Parameter & State Definitions
//====================================================================
// when IC == this number and both cores have completed exec, check if we need to WB to data dram, WB if needed, and then stall
parameter STOP_IC = 4095; 

// --- Core FSM States ---
parameter C_PRELOAD      = 'd0;
parameter C_DEC1     = 'd1;
parameter C_DEC2 = 'd2; 
 // After fetching inst, wait for the scheduling result from the top module
parameter C_WAIT_SCHEDULE  = 'd3; 
parameter C_EXEC   = 'd4; 
parameter C_WB        = 'd5; // Write back to data dram
parameter C_DONE      = 'd6; // Instruction finished
parameter C_R_SRAM1 = 'd7;
parameter C_R_SRAM2 = 'd8;
parameter C_INST_MISS = 'd9;
parameter C_W_SRAM = 'd10;
parameter C_DATA_MISS_LOAD = 'd11;
parameter C_DATA_MISS_WB = 'd12;

// --- Main FSM (Arbiter) States ---
parameter M_PRELOAD        = 'd0;
parameter M_FETCH          = 'd1; // wait for the 2 cores to finish inst fetching, and send the scheduling result at the last cycle 
parameter M_CONCUR_EXE     = 'd2; 
parameter M_EXE_INST1      = 'd3;
parameter M_EXE_INST2      = 'd4;
parameter M_HALT_WB        = 'd5; // writing back to the data dram at the end of the simulation
// parameter M_HALT           = 'd6;
parameter M_STALL          = 'd6; // pull down both stall signals and stop all execution for 1 cycle
parameter M_PERIODIC_WB      = 'd7; // when IC = 49, 99 ... && both cores have completed their execution && dirty, write back to dram before stalling

// --- DRAM AXI FSM States (From CPU_iclab130.v) ---
parameter DRAM_IDLE         = 3'd0;
parameter DRAM_WAIT_ARREADY = 3'd1;
parameter DRAM_WAIT_RLAST   = 3'd2;
parameter DRAM_WAIT_AWREADY = 3'd3;
parameter DRAM_WRITE        = 3'd4;
parameter DRAM_WAIT_BVALID  = 3'd5;

//====================================================================
// Internal Signals & Registers
//====================================================================
// --- FSM Registers ---
reg [3:0] c1_st, c1_st_nxt;
reg [3:0] c2_st, c2_st_nxt;
reg [3:0] main_st, main_st_nxt;

reg [2:0] st_dram_inst1, st_dram_inst1_nxt;
reg [2:0] st_dram_inst2, st_dram_inst2_nxt;
reg [2:0] st_dram_data,   st_dram_data_nxt;

// program counters
reg [12:0] core_1_pc, core_2_pc;

// --- Control Signals (Core <-> Main) ---
// indicate the priority of the 2 core, take opcode as input
// 0: execute first
// both 0 -> execute the 2 cores concurrently
wire c1_priority, c2_priority;

// --- Instruction couter (shared among the 2 cores) ---
reg [11:0] IC;

// --- DATA SRAM ctrl ---
// count the cycles before periodic wb
reg [3:0] write_back_cnt;
reg dirty;
reg [12:0] load_store_addr_dram; // select from load_store_addr_1 and load_store_addr_2 based on the core that is accessing data dram
reg [6:0] cache_wr_addr_dram; // when sram interacts with data dram, select this for data_A
reg [4:0] data_tag;

// --- DATA SRAM ports ---
wire [6:0] data_A; // actual data dram addr wire
wire [15:0] data_DO;
reg [15:0] data_DI; // ffs directly connects to the DI port
reg data_WEB; // comb signal

// --- AXI Counters & Addresses ---
// [TODO: You need to define how these increment during AXI transfers]
reg [6:0] data_sram_cnt, inst_1_sram_cnt, inst_2_sram_cnt; 
reg [31:0] inst_1_araddr_reg, inst_2_araddr_reg, data_araddr_reg, data_awaddr_reg;

// sram preload flags
reg preload_inst_1_done, preload_inst_2_done, preload_data_done;
wire last_cycle_inst_1, last_cycle_inst_2; // indicate if this is the last cycle of the exec of this inst

// inst srams
wire [6:0] inst_1_A, inst_2_A;
wire [15:0] inst_1_DO, inst_2_DO;
reg [15:0] inst_1_DI, inst_2_DI;
reg inst_1_WEB, inst_2_WEB;
// output ffs of inst srams
reg [15:0] inst_1_DO_reg, inst_2_DO_reg; // latch the output of inst srams for decoding and execution

// decode
wire [2:0] opcode_1, opcode_2;
wire [3:0] rs_1, rt_1, rd_1, rl_1;
wire [3:0] rs_2, rt_2, rd_2, rl_2;
wire signed [4:0] immediate_1, immediate_2;
wire [12:0] address_1, address_2;
wire [12:0] load_store_addr_1, load_store_addr_2; // dram addr used for load & store inst
wire [10:0] rs_plus_imm_1, rs_plus_imm_2;

// reg operands
reg signed [15:0] rs_reg, rt_reg;

//====================================================================
// AXI-4 Static Settings (Based on Spec)
//====================================================================
// --- Instruction 1 DRAM ---
assign arid_m_inf_inst_1    = 4'd0;
assign arburst_m_inf_inst_1 = 2'b01;   // INCR
assign arsize_m_inf_inst_1  = 3'b001;  // 2 Bytes per beat (16-bit)
assign arlen_m_inf_inst_1   = 7'd127;  // [TODO: Adjust to your cache line size (e.g. 128 words -> 127)]
assign awid_m_inf_inst_1    = 4'd0;    // Inst DRAM is Read-Only, but tie off inputs
assign awburst_m_inf_inst_1 = 2'b01;
assign awsize_m_inf_inst_1  = 3'b001;

// --- Instruction 2 DRAM ---
assign arid_m_inf_inst_2    = 4'd0;
assign arburst_m_inf_inst_2 = 2'b01;
assign arsize_m_inf_inst_2  = 3'b001;
assign arlen_m_inf_inst_2   = 7'd127;  // [TODO: Adjust based on your SRAM size]
assign awid_m_inf_inst_2    = 4'd0;
assign awburst_m_inf_inst_2 = 2'b01;
assign awsize_m_inf_inst_2  = 3'b001;

// --- Data DRAM ---
assign arid_m_inf_data      = 4'd0;
assign arburst_m_inf_data   = 2'b01;
assign arsize_m_inf_data    = 3'b001;
assign arlen_m_inf_data     = 7'd127;  // [TODO: Adjust based on your SRAM size]
assign awid_m_inf_data      = 4'd0;
assign awburst_m_inf_data   = 2'b01;
assign awsize_m_inf_data    = 3'b001;
assign awlen_m_inf_data     = 7'd127;  // [TODO: Adjust based on dirty block size]

//====================================================================
// Counters
//====================================================================
always @(posedge clk or negedge rst_n) begin : inst_cnt
    if(!rst_n)begin
        IC <= 0;
    end else begin
        IC <= (main_st == M_STALL) + IC;
    end
end

always @(posedge clk or negedge rst_n) begin : prog_cnt
	if (!rst_n) begin
		PC <= 0;
	end
	else begin
		if (last) begin
			if (jump) PC <= address[11:0];
			else if (beq && rs_reg == rt_reg) PC <= PC + 2 + {{6{immediate[4]}}, immediate, 1'b0};
			else PC <= PC + 2;
		end
	end
end

//====================================================================
// Main FSM & Arbiter (The "Traffic Cop")
//====================================================================
always @(posedge clk or negedge rst_n) begin : main_and_core_fsm_seq
    if (!rst_n)begin
        c1_st <= C_PRELOAD;
        c2_st <= C_PRELOAD;
        main_st <= M_PRELOAD;
    end else begin
        c1_st <= c1_st_nxt;
        c2_st <= c2_st_nxt;
        main_st <= main_st_nxt;
    end
end

always @(*) begin : main_nxt_state_logic
    main_st_nxt = main_st;
    case(main_st)

    default:begin
        
    end
    endcase
end

always @(*) begin : c1_nxt_state_logic
    c1_st_nxt = c1_st;
    case(c1_st)

    default:begin
        
    end
    endcase
end

//====================================================================
// DRAM AXI FSMs (Identical logic to CPU_iclab130.v)
//====================================================================

// --- Instruction 1 DRAM FSM ---
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) st_dram_inst1 <= DRAM_IDLE;
    else        st_dram_inst1 <= st_dram_inst1_nxt;
end

always @(*) begin
    st_dram_inst1_nxt = st_dram_inst1;
    case (st_dram_inst1)
        DRAM_IDLE: begin
            if (main_st == M_PRELOAD || c1_st == C_INST_MISS) // Core requested a fetch
                st_dram_inst1_nxt = DRAM_WAIT_ARREADY;
        end
        DRAM_WAIT_ARREADY: begin
            if (arready_m_inf_inst_1)
                st_dram_inst1_nxt = DRAM_WAIT_RLAST;
        end
        DRAM_WAIT_RLAST: begin
            if (rlast_m_inf_inst_1 && rvalid_m_inf_inst_1)
                st_dram_inst1_nxt = DRAM_IDLE;
        end
    endcase
end

// --- Instruction 2 DRAM FSM ---
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) st_dram_inst2 <= DRAM_IDLE;
    else        st_dram_inst2 <= st_dram_inst2_nxt;
end

always @(*) begin
    st_dram_inst2_nxt = st_dram_inst2;
    case (st_dram_inst2)
        DRAM_IDLE: begin
            if (main_st == M_PRELOAD || c2_st == C_INST_MISS) 
                st_dram_inst2_nxt = DRAM_WAIT_ARREADY;
        end
        DRAM_WAIT_ARREADY: begin
            if (arready_m_inf_inst_2)
                st_dram_inst2_nxt = DRAM_WAIT_RLAST;
        end
        DRAM_WAIT_RLAST: begin
            if (rlast_m_inf_inst_2 && rvalid_m_inf_inst_2)
                st_dram_inst2_nxt = DRAM_IDLE;
        end
    endcase
end

// --- Data DRAM FSM ---
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) st_dram_data <= DRAM_IDLE;
    else        st_dram_data <= st_dram_data_nxt;
end

always @(*) begin
    st_dram_data_nxt = st_dram_data;
    case (st_dram_data)
        DRAM_IDLE: begin
            if (main_st == M_DATA_MISS_WB || main_st == M_PERIODIC_WB)
                st_dram_data_nxt = DRAM_WAIT_AWREADY;
            else if (main_st == M_DATA_MISS_LOAD)
                st_dram_data_nxt = DRAM_WAIT_ARREADY;
        end
        DRAM_WAIT_ARREADY: begin
            if (arready_m_inf_data)
                st_dram_data_nxt = DRAM_WAIT_RLAST;
        end
        DRAM_WAIT_RLAST: begin
            if (rlast_m_inf_data && rvalid_m_inf_data)
                st_dram_data_nxt = DRAM_IDLE;
        end
        DRAM_WAIT_AWREADY: begin
            if (awready_m_inf_data)
                st_dram_data_nxt = DRAM_WRITE;
        end
        DRAM_WRITE: begin
            if (wlast_m_inf_data && wready_m_inf_data)
                st_dram_data_nxt = DRAM_WAIT_BVALID;
        end
        DRAM_WAIT_BVALID: begin
            if (bvalid_m_inf_data) begin
                if (main_st == M_DATA_MISS_LOAD || main_st == M_PRELOAD) // If it was WB, immediately LOAD next
                    st_dram_data_nxt = DRAM_WAIT_ARREADY;
                else
                    st_dram_data_nxt = DRAM_IDLE;
            end
        end
    endcase
end

//====================================================================
// AXI Control Signal Assignments
//====================================================================
// --- Read Channels ---
assign arvalid_m_inf_inst_1 = (st_dram_inst1 == DRAM_WAIT_ARREADY);
assign arvalid_m_inf_inst_2 = (st_dram_inst2 == DRAM_WAIT_ARREADY);
assign arvalid_m_inf_data   = (st_dram_data   == DRAM_WAIT_ARREADY);

assign araddr_m_inf_inst_1  = inst_1_araddr_reg; // [TODO: Update this reg when Miss occurs]
assign araddr_m_inf_inst_2  = inst_2_araddr_reg; 
assign araddr_m_inf_data    = data_araddr_reg;

assign rready_m_inf_inst_1  = (st_dram_inst1 == DRAM_WAIT_RLAST);
assign rready_m_inf_inst_2  = (st_dram_inst2 == DRAM_WAIT_RLAST);
assign rready_m_inf_data    = (st_dram_data   == DRAM_WAIT_RLAST);

// --- Write Channels (Data DRAM only) ---
assign awvalid_m_inf_data   = (st_dram_data == DRAM_WAIT_AWREADY);
assign awaddr_m_inf_data    = data_awaddr_reg;

assign wvalid_m_inf_data    = (st_dram_data == DRAM_WRITE);
// assign wdata_m_inf_data  = data_DO_reg; // [TODO: Connect SRAM output to WDATA]
// assign wlast_m_inf_data  = (data_sram_cnt == 7'd127 && wvalid_m_inf_data); // [TODO: Setup burst counter]

assign bready_m_inf_data    = 1'b1; // Always ready to receive response

// Write channels for Inst DRAMs are unused, keep valid low
assign awvalid_m_inf_inst_1 = 1'b0;
assign awaddr_m_inf_inst_1  = 32'd0;
assign wvalid_m_inf_inst_1  = 1'b0;
assign wdata_m_inf_inst_1   = 16'd0;
assign wlast_m_inf_inst_1   = 1'b0;
assign bready_m_inf_inst_1  = 1'b0;

assign awvalid_m_inf_inst_2 = 1'b0;
assign awaddr_m_inf_inst_2  = 32'd0;
assign wvalid_m_inf_inst_2  = 1'b0;
assign wdata_m_inf_inst_2   = 16'd0;
assign wlast_m_inf_inst_2   = 1'b0;
assign bready_m_inf_inst_2  = 1'b0;

always @(*) begin
    // Inst 1
    if (main_st == M_PRELOAD) inst_1_araddr_reg = 32'h0000_0000;
    else                         inst_1_araddr_reg = {20'h00000, core_1_pc[12:8], 7'd0}; // Miss 時的位址

    // Inst 2
    if (main_st == M_PRELOAD) inst_2_araddr_reg = 32'h0000_0000;
    else                         inst_2_araddr_reg = {20'h00000, core_2_pc[12:8], 7'd0}; // Miss 時的位址

    // Data
    if (main_st == M_PRELOAD) data_araddr_reg = 32'h0000_1000;
    else                         data_araddr_reg = {19'h00000, 1'b1, c1_mem_addr[12:8], 7'd0}; // Miss 時的位址 (假設 C1 觸發)
end

//====================================================================
// Main FSM & Core FSMs 
//====================================================================
// [TODO: Insert the Main FSM (M_START to M_UPDATE_IC) and Core FSMs here]
// They will operate exactly as discussed previously, but now they trigger 
// the DRAM FSMs by setting Core state to C_INST_MISS or Main state to M_DATA_MISS_LOAD.


endmodule

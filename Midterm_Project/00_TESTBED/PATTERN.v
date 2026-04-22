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
//   File Name   : PATTERN.v
//   Module Name : PATTERN.v
//   Release version : V1.0
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

`include "../00_TESTBED/DRAM_MAP_define.v"
`include "../00_TESTBED/pseudo_DRAM_inst1.v"
`include "../00_TESTBED/pseudo_DRAM_inst2.v"
`include "../00_TESTBED/pseudo_DRAM_data.v"

`ifdef RTL
	`define CYCLE_TIME 20.0 
`elsif GATE
	`define CYCLE_TIME 20.0
`elsif CHIP
    `define CYCLE_TIME 20.0
`elsif POST
    `define CYCLE_TIME 20.0
`endif

`ifdef FUNC
`define PAT_NUM 952
`define MAX_WAIT_READY_CYCLE 2000
`endif
`ifdef PERF
`define PAT_NUM 952
`define MAX_WAIT_READY_CYCLE 100000
`endif

module PATTERN(
    //Output Port
    clk,
    rst_n,
    //Input Port
    stall_1,
    stall_2,
    //===== AXI-4 Instruction1 DRAM =====
    arid_s_inf_inst_1,
    araddr_s_inf_inst_1,
    arlen_s_inf_inst_1,
    arsize_s_inf_inst_1,
    arburst_s_inf_inst_1,
    arvalid_s_inf_inst_1,
    arready_s_inf_inst_1,
    rid_s_inf_inst_1,
    rdata_s_inf_inst_1,
    rresp_s_inf_inst_1,
    rlast_s_inf_inst_1,
    rvalid_s_inf_inst_1,
    rready_s_inf_inst_1,
    awid_s_inf_inst_1,
    awaddr_s_inf_inst_1,
    awsize_s_inf_inst_1,
    awburst_s_inf_inst_1,
    awlen_s_inf_inst_1,
    awvalid_s_inf_inst_1,
    awready_s_inf_inst_1,
    wdata_s_inf_inst_1,
    wlast_s_inf_inst_1,
    wvalid_s_inf_inst_1,
    wready_s_inf_inst_1,
    bid_s_inf_inst_1,
    bresp_s_inf_inst_1,
    bvalid_s_inf_inst_1,
    bready_s_inf_inst_1,
    //===== AXI-4 Instruction2 DRAM =====
    arid_s_inf_inst_2,
    araddr_s_inf_inst_2,
    arlen_s_inf_inst_2,
    arsize_s_inf_inst_2,
    arburst_s_inf_inst_2,
    arvalid_s_inf_inst_2,
    arready_s_inf_inst_2,
    rid_s_inf_inst_2,
    rdata_s_inf_inst_2,
    rresp_s_inf_inst_2,
    rlast_s_inf_inst_2,
    rvalid_s_inf_inst_2,
    rready_s_inf_inst_2,
    awid_s_inf_inst_2,
    awaddr_s_inf_inst_2,
    awsize_s_inf_inst_2,
    awburst_s_inf_inst_2,
    awlen_s_inf_inst_2,
    awvalid_s_inf_inst_2,
    awready_s_inf_inst_2,
    wdata_s_inf_inst_2,
    wlast_s_inf_inst_2,
    wvalid_s_inf_inst_2,
    wready_s_inf_inst_2,
    bid_s_inf_inst_2,
    bresp_s_inf_inst_2,
    bvalid_s_inf_inst_2,
    bready_s_inf_inst_2,
    //===== AXI-4 Data DRAM =====
    arid_s_inf_data,
    araddr_s_inf_data,
    arlen_s_inf_data,
    arsize_s_inf_data,
    arburst_s_inf_data,
    arvalid_s_inf_data,
    arready_s_inf_data,
    rid_s_inf_data,
    rdata_s_inf_data,
    rresp_s_inf_data,
    rlast_s_inf_data,
    rvalid_s_inf_data,
    rready_s_inf_data,
    awid_s_inf_data,
    awaddr_s_inf_data,
    awsize_s_inf_data,
    awburst_s_inf_data,
    awlen_s_inf_data,
    awvalid_s_inf_data,
    awready_s_inf_data,
    wdata_s_inf_data,
    wlast_s_inf_data,
    wvalid_s_inf_data,
    wready_s_inf_data,
    bid_s_inf_data,
    bresp_s_inf_data,
    bvalid_s_inf_data,
    bready_s_inf_data
    );

//---------------------------------------------------------------------
//   PORT DECLARATION          
//---------------------------------------------------------------------
output reg clk, rst_n;

input wire stall_1, stall_2;

//########################################### Instruction1 DRAM
input wire [3:0] arid_s_inf_inst_1;
input wire [31:0] araddr_s_inf_inst_1;
input wire [6:0] arlen_s_inf_inst_1;
input wire [2:0] arsize_s_inf_inst_1;
input wire [1:0] arburst_s_inf_inst_1;
input wire arvalid_s_inf_inst_1;
output wire arready_s_inf_inst_1;
output wire [3:0] rid_s_inf_inst_1;
output wire [15:0] rdata_s_inf_inst_1;
output wire [1:0] rresp_s_inf_inst_1;
output wire rlast_s_inf_inst_1;
output wire rvalid_s_inf_inst_1;
input wire rready_s_inf_inst_1;
input wire [3:0] awid_s_inf_inst_1;
input wire [31:0] awaddr_s_inf_inst_1;
input wire [2:0] awsize_s_inf_inst_1;
input wire [1:0] awburst_s_inf_inst_1;
input wire [6:0] awlen_s_inf_inst_1;
input wire awvalid_s_inf_inst_1;
output wire awready_s_inf_inst_1;
input wire [15:0] wdata_s_inf_inst_1;
input wire wlast_s_inf_inst_1;
input wire wvalid_s_inf_inst_1;
output wire wready_s_inf_inst_1;
output wire [3:0] bid_s_inf_inst_1;
output wire [1:0] bresp_s_inf_inst_1;
output wire bvalid_s_inf_inst_1;
input wire bready_s_inf_inst_1;

//########################################### Instruction2 DRAM
input wire [3:0] arid_s_inf_inst_2;
input wire [31:0] araddr_s_inf_inst_2;
input wire [6:0] arlen_s_inf_inst_2;
input wire [2:0] arsize_s_inf_inst_2;
input wire [1:0] arburst_s_inf_inst_2;
input wire arvalid_s_inf_inst_2;
output wire arready_s_inf_inst_2;
output wire [3:0] rid_s_inf_inst_2;
output wire [15:0] rdata_s_inf_inst_2;
output wire [1:0] rresp_s_inf_inst_2;
output wire rlast_s_inf_inst_2;
output wire rvalid_s_inf_inst_2;
input wire rready_s_inf_inst_2;
input wire [3:0] awid_s_inf_inst_2;
input wire [31:0] awaddr_s_inf_inst_2;
input wire [2:0] awsize_s_inf_inst_2;
input wire [1:0] awburst_s_inf_inst_2;
input wire [6:0] awlen_s_inf_inst_2;
input wire awvalid_s_inf_inst_2;
output wire awready_s_inf_inst_2;
input wire [15:0] wdata_s_inf_inst_2;
input wire wlast_s_inf_inst_2;
input wire wvalid_s_inf_inst_2;
output wire wready_s_inf_inst_2;
output wire [3:0] bid_s_inf_inst_2;
output wire [1:0] bresp_s_inf_inst_2;
output wire bvalid_s_inf_inst_2;
input wire bready_s_inf_inst_2;

//########################################### Data DRAM
input wire [3:0] arid_s_inf_data;
input wire [31:0] araddr_s_inf_data;
input wire [6:0] arlen_s_inf_data;
input wire [2:0] arsize_s_inf_data;
input wire [1:0] arburst_s_inf_data;
input wire arvalid_s_inf_data;
output wire arready_s_inf_data;
output wire [3:0] rid_s_inf_data;
output wire [15:0] rdata_s_inf_data;
output wire [1:0] rresp_s_inf_data;
output wire rlast_s_inf_data;
output wire rvalid_s_inf_data;
input wire rready_s_inf_data;
input wire [3:0] awid_s_inf_data;
input wire [31:0] awaddr_s_inf_data;
input wire [2:0] awsize_s_inf_data;
input wire [1:0] awburst_s_inf_data;
input wire [6:0] awlen_s_inf_data;
input wire awvalid_s_inf_data;
output wire awready_s_inf_data;
input wire [15:0] wdata_s_inf_data;
input wire wlast_s_inf_data;
input wire wvalid_s_inf_data;
output wire wready_s_inf_data;
output wire [3:0] bid_s_inf_data;
output wire [1:0] bresp_s_inf_data;
output wire bvalid_s_inf_data;
input wire bready_s_inf_data;

//---------------------------------------------------------------------
//   PARAMETER & INTEGER DECLARATION
//---------------------------------------------------------------------
integer inst1_file, inst2_file, data_file;
integer pat_idx, ic_count, exe_cycles;
integer total_latency;

// Golden model registers
reg signed [15:0] golden_core1_regs [0:7];
reg signed [15:0] golden_core2_regs [0:7];

//---------------------------------------------------------------------
//  TASK VARIABLE
//---------------------------------------------------------------------


//---------------------------------------------------------------------
//   WIRE & REGISTER DECLARATION
//---------------------------------------------------------------------

//---------------------------------------------------------------------
//   CLOCK
//---------------------------------------------------------------------

//---------------------------------------------------------------------
//   TEST PATTERN                                         
//---------------------------------------------------------------------

//---------------------------------------------------------------------
//   INSTANTIATE PSEUDO DRAM
//---------------------------------------------------------------------
// You MUST instantiate the TA's DRAM models here and pass the AXI signals to them.
pseudo_DRAM_inst1 u_DRAM_inst1 (
    .clk(clk),
    .rst_n(rst_n),
    // Connect your AXI slave signals here
    .araddr_s_inf(araddr_s_inf_inst_1)
    // ...
);

pseudo_DRAM_inst2 u_DRAM_inst2 (
    .clk(clk),
    .rst_n(rst_n)
    // Connect your AXI slave signals here
    // ...
);

pseudo_DRAM_data u_DRAM_data (
    .clk(clk),
    .rst_n(rst_n)
    // Connect your AXI slave signals here
    // ...
);

//---------------------------------------------------------------------
//   MAIN SIMULATION FLOW
//---------------------------------------------------------------------
initial begin
    // Step 1: Generate pattern files BEFORE reset
    generate_pattern_files();
    
    // Step 2: Initialize signals and reset system
    reset_task();

    // Step 3: Run testing patterns
    for (pat_idx = 0; pat_idx < `PAT_NUM; pat_idx = pat_idx + 1) begin
        execution_and_check_task();
    end

    // Step 4: Finish Simulation
    YOU_PASS_task();
end

//---------------------------------------------------------------------
//   TASKS
//---------------------------------------------------------------------

// Task: Generate .dat files and calculate Golden Answers
task generate_pattern_files; begin
    // Open files for writing
    inst1_file = $fopen("inst1_dram_file.dat", "w");
    inst2_file = $fopen("inst2_dram_file.dat", "w");
    data_file  = $fopen("data_dram_file.dat", "w");

    // TODO: Write a loop to generate instructions (e.g., 500 instructions)
    // Example Constraints to enforce here:
    // 1. Jump address must be EVEN and within (PC - 256) to (PC + 256).
    // 2. Mult: rd != rl.
    // 3. No double Store at the same IC.
    // 4. Update golden_core1_regs and golden_core2_regs during generation.
    // 5. Use $fdisplay(inst1_file, "%h", generated_inst_16bit);

    $fclose(inst1_file);
    $fclose(inst2_file);
    $fclose(data_file);
end endtask

// Task: System Reset
task reset_task; begin
    rst_n = 1'b1;
    #( `CYCLE_TIME * 2.0 );
    
    rst_n = 1'b0; // Active low reset
    #( `CYCLE_TIME * 2.0 );
    
    // Spec Check: Stalls must be high after reset
    if (stall_1 !== 1'b1 || stall_2 !== 1'b1) begin
        $display("[ERROR] Stall signals must be HIGH after reset.");
        $finish;
    end
    
    rst_n = 1'b1;
    #( `CYCLE_TIME * 2.0 );
end endtask

// Task: Execution Control and Spec Checking
task execution_and_check_task; begin
    ic_count = 0;
    exe_cycles = 0;

    // Loop until your defined halt condition (e.g., 500 instructions)
    while (ic_count < 500) begin
        @(negedge clk);
        exe_cycles = exe_cycles + 1;
        
        // Spec Check: Maximum execution cycle limitation
        if (exe_cycles > `MAX_WAIT_READY_CYCLE) begin
            $display("[ERROR] Execution time exceeded MAX_WAIT_READY_CYCLE.");
            $finish;
        end

        // Check if both cores have finished current instruction
        if (stall_1 === 1'b0 && stall_2 === 1'b0) begin
            
            // TODO: Check CPU Registers against Golden Model 
            // e.g., if (u_DCCPU.core_r0 !== golden_core1_regs[0]) ...
            
            ic_count = ic_count + 1;
            exe_cycles = 0; // Reset timeout counter for next instruction
            
            // Spec Check: TA will check Data DRAM every 50 instructions
            // Since IC starts from 0, the 50th instruction is executed when IC is 49.
            // Hence, check when (ic_count % 50 == 0).
            if (ic_count % 50 == 0) begin
                check_dram_task();
            end
        end
    end
    
    // Final DRAM check at the end of the simulation
    check_dram_task();
end endtask

// Task: Check Data DRAM
task check_dram_task; begin
    // TODO: Compare u_DRAM_data.mem[...] with your golden memory array
    // Example:
    // integer i;
    // for (i = 0; i < 2048; i = i + 1) begin
    //     if (u_DRAM_data.mem[i] !== golden_data_mem[i]) begin
    //         $display("[ERROR] Data DRAM mismatch at IC %d", ic_count);
    //         $finish;
    //     end
    // end
end endtask

// Task: Pass Simulation
task YOU_PASS_task; begin
    $display("=========================================================");
    $display("                      Congratulations!                   ");
    $display("              Execution passed all requirements.         ");
    $display("=========================================================");
    $finish;
end endtask


endmodule
//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   2026 ICLAB SPRING Course
//   Lab05        : Diffusion Model (DM)
//   Author       : PATTERN generated for DM
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

`ifdef RTL
    `define CYCLE_TIME 20.0
`endif
`ifdef GATE
    `define CYCLE_TIME 20.0
`endif

module PATTERN(
    // Output Port (To DUT)
    clk,
    rst_n,
    i_valid,
    i_iter,
    i_mode,
    i_data,
    i_weight,
    
    // Input Port (From DUT)
    o_valid,
    o_data
);

//================================================================
//   INPUT AND OUTPUT DECLARATION
//================================================================
output reg clk;
output reg rst_n;
output reg i_valid;
output reg [2:0] i_iter;
output reg [1:0] i_mode;
output reg [7:0] i_data;
output reg signed [3:0] i_weight;
    
input  o_valid;
input  [7:0] o_data;

//================================================================
// parameters & integer
//================================================================
real CYCLE = `CYCLE_TIME;

parameter PATNUM = 10; 
// Weight size: 
// Down Sampling Conv: 3*3*1*16 = 144
// Linear QKV: 16*16*3 = 768
// FFN: 16*16 = 256
// Up Sampling Conv: 3*3*16*1 = 144
// Total = 144 + 768 + 256 + 144 = 1312 [cite: 638]
parameter WEIGHT_WORDS = 1312;
parameter IMAGE_WORDS  = 4096; // 64x64 [cite: 117]
parameter OUT_WORDS    = 4096;

parameter WEIGHT_FILE  = "../00_TESTBED/input_weight.txt";
parameter IMAGE_FILE   = "../00_TESTBED/input_image.txt";
parameter ITER_FILE    = "../00_TESTBED/input_iter.txt";
parameter MODE_FILE    = "../00_TESTBED/input_mode.txt";
parameter GOLDEN_FILE  = "../00_TESTBED/golden_output.txt";

integer patcount, total_latency, i;
integer current_iter, current_mode;

reg signed [3:0] all_weight_data [0:WEIGHT_WORDS-1]; // Weight input only once [cite: 641]
reg [7:0] all_image_data  [0:PATNUM*IMAGE_WORDS-1];
reg [2:0] all_iter_data   [0:PATNUM-1];
reg [1:0] all_mode_data   [0:PATNUM-1];
reg [7:0] all_golden_data [0:PATNUM*OUT_WORDS-1];

//================================================================
// clock
//================================================================
initial begin
    clk = 0;
end
always #(CYCLE/2.0) clk = ~clk;

//================================================================
// initial
//================================================================
initial begin
    rst_n = 1'b1;
    i_valid = 1'b0;
    i_iter = 3'bx;
    i_mode = 2'bx;
    i_data = 8'bx;
    i_weight = 4'bx;
    
    total_latency = 0;
    
    load_test_data;
    reset_signal_task;
    
    // Input weights first [cite: 52, 641]
    input_weight_task;

    for(patcount = 0; patcount < PATNUM; patcount = patcount + 1) begin
        repeat($urandom_range(1, 3)) @(negedge clk); // [cite: 654]
        input_image_task;
        wait_out_valid_and_check;
        $display("  [PASS] Pattern %0d", patcount+1);
    end 
    
    YOU_PASS_task;
end 

//================================================================
// Background checking
//================================================================
always @(negedge clk) begin 
    if(o_valid === 0 && o_data !== 8'b0) begin
        $display("-----------------------------------------------------------------------");
        $display("  FAIL! o_data must be 0 when o_valid is low. [cite: 651]");
        $display("-----------------------------------------------------------------------");
        repeat(2) #CYCLE;
        $finish;
    end
    if(i_valid === 1 && o_valid === 1) begin
        $display("-----------------------------------------------------------------------");
        $display("  FAIL! o_valid cannot overlap with i_valid. [cite: 648]");
        $display("-----------------------------------------------------------------------");
        $finish;
    end
end

//================================================================
// Tasks
//================================================================
task load_test_data; begin
    $readmemh(WEIGHT_FILE, all_weight_data);
    $readmemh(IMAGE_FILE,  all_image_data);
    $readmemh(ITER_FILE,   all_iter_data);
    $readmemh(MODE_FILE,   all_mode_data);
    $readmemh(GOLDEN_FILE, all_golden_data);
end endtask

task reset_signal_task; begin 
    #(CYCLE);  rst_n = 0;
    #(CYCLE*3);
    rst_n = 1;
    if((o_valid !== 0) || (o_data !== 8'b0)) begin
        $display("  FAIL! Output signals must be 0 after reset. [cite: 630]");
        $finish;
    end
end endtask

task input_weight_task; begin
    i_valid = 1'b1;
    for(i = 0; i < WEIGHT_WORDS; i = i + 1) begin
        i_weight = all_weight_data[i];
        @(negedge clk);
    end
    i_valid = 1'b0;
    i_weight = 4'bx;
end endtask

task input_image_task; begin
    i_valid = 1'b1;
    i_iter = all_iter_data[patcount];
    i_mode = all_mode_data[patcount];
    for(i = 0; i < IMAGE_WORDS; i = i + 1) begin
        i_data = all_image_data[patcount * IMAGE_WORDS + i];
        @(negedge clk);
        // i_iter and i_mode valid only in 1st cycle [cite: 582]
        i_iter = 3'bx;
        i_mode = 2'bx;
    end
    i_valid = 1'b0;
    i_data = 8'bx;
end endtask

task wait_out_valid_and_check;
    integer lat, out_cnt;
    integer max_lat_per_iter;
    reg [7:0] golden;
begin
    lat = 0;
    out_cnt = 0;
    max_lat_per_iter = all_iter_data[patcount] * 150000;

    while(out_cnt < OUT_WORDS) begin
        if(o_valid === 1'b1) begin
            golden = all_golden_data[patcount * OUT_WORDS + out_cnt];
            
            if (o_data !== golden) begin
                $display("-----------------------------------------------------------------------");
                $display("  [FAIL] Pattern %0d, Pixel %0d", patcount+1, out_cnt);
                $display("         Expected: %h", golden);
                $display("         Got     : %h", o_data);
                $display("-----------------------------------------------------------------------");
                repeat(2) @(negedge clk);
                $finish;
            end
            
            out_cnt = out_cnt + 1;
        end else begin
            lat = lat + 1;
            if(lat > max_lat_per_iter) begin
                $display("  FAIL! Execution latency exceeded %0d cycles.", max_lat_per_iter);
                $finish;
            end
        end
        @(negedge clk);
    end
    
    total_latency = total_latency + lat;
end endtask

task YOU_PASS_task; begin
    $display("========================================================================");
    $display("                  Congratulations! Pass All Patterns!                   ");
    $display("            Average Latency : %0d cycles", total_latency/PATNUM);
    $display("========================================================================");
    repeat(2) @(negedge clk);
    $finish;
end endtask

endmodule
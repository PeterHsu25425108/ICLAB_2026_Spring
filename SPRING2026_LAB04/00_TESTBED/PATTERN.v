//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   2026 ICLAB SPRING Course
//   Lab04        : Convolution and Deconvolution Network Accelerator
//   Author       : PATTERN generated for debugging
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

`ifdef RTL
    `define CYCLE_TIME 50.0
`endif
`ifdef GATE
    `define CYCLE_TIME 50.0
`endif

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

//================================================================
//   INPUT AND OUTPUT DECLARATION
//================================================================
output reg clk;
output reg rst_n;
output reg instruction_in_valid;
output reg image_in_valid;
output reg weight_in_valid;
output reg [31:0] in_data;
    
input  out_valid;
input  [31:0] out_data;

//================================================================
// parameters & integer
//================================================================
real CYCLE = `CYCLE_TIME;

// ========== Parameter ==========
parameter PATNUM = 4;      
parameter INST_WORDS = 1;
parameter WEIGHT_WORDS = 144;
parameter IMAGE_WORDS = 128;
parameter OUT_WORDS = 128;

// ========== file path ==========
parameter INST_FILE   = "../00_TESTBED/input_instruction.txt";
parameter WEIGHT_FILE = "../00_TESTBED/input_weight.txt";
parameter IMAGE_FILE  = "../00_TESTBED/input_image.txt";
parameter GOLDEN_FILE = "../00_TESTBED/golden_output.txt";

integer patcount, total_latency, wait_val_time;
integer i;

//================================================================
// memory arrays (To store txt data)
//================================================================
reg [31:0] all_inst_data   [0:PATNUM*INST_WORDS-1];
reg [31:0] all_weight_data [0:PATNUM*WEIGHT_WORDS-1];
reg [31:0] all_image_data  [0:PATNUM*IMAGE_WORDS-1];
reg [31:0] all_golden_data [0:PATNUM*OUT_WORDS-1];

integer output_count;
integer passed_patterns;

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
    instruction_in_valid = 1'b0;
    image_in_valid = 1'b0;
    weight_in_valid = 1'b0;
    in_data = 32'bx;
    
    force clk = 0;
    total_latency = 0;
    output_count = 0;
    passed_patterns = 0;
    
    load_test_data;
    reset_signal_task;
    
    $display("========================================================================");
    $display("Total Patterns  : %0d", PATNUM);
    $display("========================================================================");
    $display("");
    
    for(patcount = 0; patcount < PATNUM; patcount = patcount + 1) begin
        $display("------------------------------------------------------------------------");
        $display("  Testing Pattern %0d/%0d", patcount+1, PATNUM);
        $display("------------------------------------------------------------------------");
        
        repeat($urandom_range(1, 3)) @(negedge clk);
        
        input_task;
        wait_out_valid_and_check;
        
        passed_patterns = passed_patterns + 1;
        $display("  [PASS] Pattern %0d: All 128 outputs correct!", patcount+1);
    end 
    
    YOU_PASS_task;
end 

//================================================================
// Background checking tasks
//================================================================
// Check out_data when out_valid is low
always @(negedge clk) begin 
    if(out_valid === 0 && out_data !== 32'b0) begin
        $display("---------------------------------------------------------------------------------------------");
        $display("             FAIL! The out_data should be 0 when out_valid is pulled down.                   ");
        $display("             Time: %0t, out_data = %h", $time, out_data);
        $display("---------------------------------------------------------------------------------------------");
        repeat(2) #CYCLE;
        $finish;
    end
end

//================================================================
// Main tasks
//================================================================
task load_test_data; begin
    $display("  Loading instruction from : %s", INST_FILE);
    $display("  Loading weight from      : %s", WEIGHT_FILE);
    $display("  Loading image from       : %s", IMAGE_FILE);
    $display("  Loading golden from      : %s", GOLDEN_FILE);
    $readmemh(INST_FILE,   all_inst_data);
    $readmemh(WEIGHT_FILE, all_weight_data);
    $readmemh(IMAGE_FILE,  all_image_data);
    $readmemh(GOLDEN_FILE, all_golden_data);
end endtask

task reset_signal_task; begin 
    #(CYCLE);  rst_n = 0;
    #(CYCLE*3); rst_n = 1;
    if((out_valid !== 0) || (out_data !== 32'b0)) begin
        $display("---------------------------------------------------------------------------------------------");
        $display("             FAIL! Output signals should be 0 after reset at %4t.", $time);
        $display("             out_valid = %b, out_data = %h", out_valid, out_data);
        $display("---------------------------------------------------------------------------------------------");
        $finish;
    end
    #(CYCLE);
    release clk;
end endtask

task input_task; begin
    instruction_in_valid = 1'b1;
    in_data = all_inst_data[patcount * INST_WORDS];
    @(negedge clk);
    instruction_in_valid = 1'b0;
    in_data = 32'bx;

    repeat($urandom_range(0, 2)) @(negedge clk);

    weight_in_valid = 1'b1;
    for(i = 0; i < WEIGHT_WORDS; i = i + 1) begin
        in_data = all_weight_data[patcount * WEIGHT_WORDS + i];
        @(negedge clk);
    end
    weight_in_valid = 1'b0;
    in_data = 32'bx;

    repeat($urandom_range(0, 2)) @(negedge clk);

    image_in_valid = 1'b1;
    for(i = 0; i < IMAGE_WORDS; i = i + 1) begin
        in_data = all_image_data[patcount * IMAGE_WORDS + i];
        @(negedge clk);
    end
    image_in_valid = 1'b0;
    in_data = 32'bx;
end endtask

task wait_out_valid_and_check;
    integer lat, out_cnt;
    shortreal golden_real, your_real, diff, error, abs_golden;
    reg [31:0] golden_hex;
begin
    lat = 0;
    out_cnt = 0;
    
    while(out_valid === 0) begin
        lat = lat + 1;
        if(lat > 1200) begin
            $display("---------------------------------------------------------------------------------------------");
            $display("             FAIL! The execution latency is over 1200 cycles. Time: %0t", $time);
            $display("---------------------------------------------------------------------------------------------");
            repeat(2) @(negedge clk);
            $finish;
        end
        @(negedge clk);
    end
    
    total_latency = total_latency + lat;
    
    while(out_valid === 1) begin
        if(out_cnt >= OUT_WORDS) begin
            $display("---------------------------------------------------------------------------------------------");
            $display("             FAIL! out_valid is high for more than 128 cycles.");
            $display("---------------------------------------------------------------------------------------------");
            $finish;
        end

        golden_hex = all_golden_data[patcount * OUT_WORDS + out_cnt];
        
        golden_real = $bitstoshortreal(golden_hex);
        your_real   = $bitstoshortreal(out_data);
        
        // 計算絕對誤差: abs((golden - your) / golden)
        diff = golden_real - your_real;
        if (diff < 0.0) diff = -diff;
        
        abs_golden = golden_real;
        if (abs_golden < 0.0) abs_golden = -abs_golden;
        
        // 避免除以 0 (通常非線性激勵函數如果輸出嚴格為 0，可以直接檢查差值)
        if (abs_golden == 0.0) begin
            error = diff; 
        end else begin
            error = diff / abs_golden;
        end
        
        if (error >= 0.002) begin
            $display("---------------------------------------------------------------------------------------------");
            $display("  [FAIL] Pattern %0d, Output %0d", patcount+1, out_cnt);
            $display("         Expected: %08x (Float: %f)", golden_hex, golden_real);
            $display("         Got     : %08x (Float: %f)", out_data, your_real);
            $display("         Error   : %f (Must be < 0.002)", error);
            $display("---------------------------------------------------------------------------------------------");
            repeat(2) @(negedge clk);
            $finish;
        end
        
        out_cnt = out_cnt + 1;
        @(negedge clk);
    end
    
    if (out_cnt != OUT_WORDS) begin
        $display("---------------------------------------------------------------------------------------------");
        $display("             FAIL! out_valid dropped early. Only got %0d/%0d outputs.", out_cnt, OUT_WORDS);
        $display("---------------------------------------------------------------------------------------------");
        $finish;
    end
    
end endtask

task YOU_PASS_task; begin
    $display("========================================================================");
    $display("                   \033[32m\033[5m █████ █████ █████ █████ █████ █████ █████ \033[0m");
    $display("                   \033[32m\033[5m █     █   █ █   █ █   █ █      █       █ \033[0m");
    $display("                   \033[32m\033[5m █     █   █ █████ █████ █████  █       █  \033[0m");
    $display("                   \033[32m\033[5m █     █   █ █  █  █  █  █      █       █  \033[0m");
    $display("                   \033[32m\033[5m █████ █████ █   █ █   █ █████ █████    █  \033[0m");
    $display("\n");
    $display("                        Congratulations!                                ");
    $display("                  You have passed all patterns!                         ");
    $display("            Average Latency       : %0d cycles/pattern", total_latency/PATNUM);
    $display("            Total Latency         : %0d cycles", total_latency);
    $display("========================================================================");
    repeat(2) @(negedge clk);
    $finish;
end endtask

endmodule
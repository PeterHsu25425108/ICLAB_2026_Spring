`define CYCLE_TIME  20.0

module PATTERN(
    // output signals
    clk,
    rst_n,
    i_valid,
    i_iter,
    i_mode,
    i_data,
    i_weight,
    
    // input signals
    o_valid,
    o_data
);

// ========================================
// I/O declaration
// ========================================
// Output
output reg          clk;
output reg          rst_n;
output reg          i_valid;
output reg    [2:0] i_iter;
output reg    [1:0] i_mode;
output reg    [7:0] i_data;
output reg    [3:0] i_weight;

// Input
input               o_valid;
input         [7:0] o_data;

// ========================================
// clock
// ========================================
real CYCLE = `CYCLE_TIME;
initial clk = 1'b0;
always  #(CYCLE/2.0) clk = ~clk; //clock

// ========================================
// integer & parameter
// ========================================
parameter PATNUM       = 10;   
parameter IMG_HEIGHT   = 64;  
parameter IMG_WIDTH    = 64;  
parameter TOTAL_PIXELS = 4096;   // 64 * 64
parameter WEIGHT_NUM   = 1312;   // 16x1x3x3(144) + 16x16x4(1024) + 1x16x3x3(144) = 1312

parameter WEIGHT_FILE  = "../00_TESTBED/weight_in.txt";
parameter IMAGE_FILE   = "../00_TESTBED/image_in.txt";  
parameter GOLDEN_FILE  = "../00_TESTBED/output.txt"; 
parameter ITER_FILE    = "../00_TESTBED/iter_in.txt";
parameter MODE_FILE    = "../00_TESTBED/mode_in.txt";

integer patcount, total_latency, latency_per_pat;
integer i, j, w_idx, base_idx, check_idx;
integer file_iter, file_mode;

integer error_count, total_errors;
integer passed_patterns, failed_patterns;

// ========================================
// wire & reg
// ========================================
reg [3:0] all_weight      [0:WEIGHT_NUM-1]; 
reg [7:0] all_input_data  [0:PATNUM*TOTAL_PIXELS-1];
reg [7:0] all_golden_data [0:PATNUM*TOTAL_PIXELS-1];
reg [7:0] current_golden  [0:TOTAL_PIXELS-1];
reg [2:0] all_iter        [0:PATNUM-1];
reg [1:0] all_mode        [0:PATNUM-1];
//================================================================
// design
//================================================================
initial begin

    rst_n    = 1'b1;
    i_valid  = 1'b0;
    i_data   = 'bx;
    i_weight = 'bx;
    i_mode   = 'bx;
    i_iter   = 'bx;

    total_latency   = 0;
    error_count     = 0;
    total_errors    = 0;
    passed_patterns = 0;
    failed_patterns = 0;
    force clk = 0;
	
    load_test_data;
    
    reset_signal_task;
    #(CYCLE*3);
    
    $display("========================================================================");
    $display("Total Patterns  : %0d", PATNUM);
    $display("========================================================================");
    $display("");
    
    $display("Sending Initial Weights (1312 cycles)...");
    send_weight_task;
    
    for(patcount = 0; patcount < PATNUM; patcount = patcount + 1) begin
        $display("------------------------------------------------------------------------");
        $display("  Testing Pattern %0d/%0d", patcount+1, PATNUM);
        $display("------------------------------------------------------------------------");
        
        repeat($urandom_range(1, 3)) @(negedge clk);
        
        extract_golden(patcount);
        

        file_iter = all_iter[patcount]; 
        file_mode = all_mode[patcount];
        
        input_image_task(patcount, file_iter, file_mode);
        wait_and_check_output;
        
        if(error_count == 0) begin
            passed_patterns = passed_patterns + 1;
            $display("  [PASS] Pattern %0d: All %0d pixels correct! (Latency: %0d)", patcount+1, TOTAL_PIXELS, latency_per_pat);
        end else begin
            failed_patterns = failed_patterns + 1;
            $display("  [FAIL] Pattern %0d: %0d errors found!", patcount+1, error_count);
            $display("========================================================================");
            $finish;
        end
        $display("");
    end 
    
    YOU_PASS_task;
end


always @(negedge clk) begin 
    if(o_valid === 0 && o_data !== 8'b0) begin
        $display("---------------------------------------------------------------------------------------------");
        $display("             FAIL! The o_data should be 0 when o_valid is low.                               ");
        $display("             Time: %0t, o_data = %0d", $time, o_data);
        $display("---------------------------------------------------------------------------------------------");
        repeat(2) #CYCLE;
        $finish;
    end
end


always @(negedge clk) begin 
    if(o_valid === 1 && i_valid === 1) begin
        $display("---------------------------------------------------------------------------------------------");
        $display("             FAIL! The o_valid should not be high when i_valid is high.                      ");
        $display("---------------------------------------------------------------------------------------------");
        $finish;
    end
end

//================================================================
// tasks
//================================================================
task load_test_data;
begin
    $display("  Loading Weights...  (%s)", WEIGHT_FILE);
    $readmemh(WEIGHT_FILE, all_weight);
    $display("  Loading Images...   (%s)", IMAGE_FILE);
    $readmemh(IMAGE_FILE, all_input_data);
    $display("  Loading Golden...   (%s)", GOLDEN_FILE);
    $readmemh(GOLDEN_FILE, all_golden_data);
	
	$readmemh(ITER_FILE, all_iter);
    $readmemh(MODE_FILE, all_mode);
end
endtask

task extract_golden;
    input integer pattern_id;
begin
    base_idx = pattern_id * TOTAL_PIXELS;
    for(j = 0; j < TOTAL_PIXELS; j = j + 1) begin
        current_golden[j] = all_golden_data[base_idx + j];
    end
end
endtask

task reset_signal_task; 
begin 
    #(CYCLE);  rst_n = 0;
    #(CYCLE*3); rst_n = 1;
    if((o_valid !== 0) || (o_data !== 8'b0)) begin
        $display("---------------------------------------------------------------------------------------------");
        $display("             FAIL! Output signals should be 0 after reset at %4t.", $time);
        $display("---------------------------------------------------------------------------------------------");
        $finish;
    end
    #(CYCLE);
    release clk;
end 
endtask

task send_weight_task;
begin
	@(negedge clk);
    i_valid = 1'b1;
    for(w_idx = 0; w_idx < WEIGHT_NUM; w_idx = w_idx + 1) begin
        i_weight = all_weight[w_idx];
        @(negedge clk);
    end
    i_valid = 1'b0;
    i_weight = 'bx;
end
endtask

task input_image_task; 
    input integer pattern_id;
    input integer current_iter;
    input integer current_mode;
begin
    base_idx = pattern_id * TOTAL_PIXELS;
    i_valid = 1'b1;
    error_count = 0;

    for(i = 0; i < TOTAL_PIXELS; i = i + 1) begin
        i_data = all_input_data[base_idx + i];
        
        if (i == 0) begin
            i_mode = current_mode;
            i_iter = current_iter;
        end else begin
            i_mode = 'bx;
            i_iter = 'bx;
        end
        
        @(negedge clk);
    end

    i_valid = 1'b0;
    i_data = 'bx;
    i_mode = 'bx;
    i_iter = 'bx;
end
endtask

task wait_and_check_output; 
begin
    latency_per_pat = 0;
    check_idx = 0;
    
    while(check_idx < TOTAL_PIXELS) begin
        // Spec: Only cycles where o_valid is low are counted toward the latency
        if(o_valid === 1'b0) begin
            latency_per_pat = latency_per_pat + 1;
        end 
        // If o_valid pulls high after falling edge of i_valid, latency is counted as 1
        else if (o_valid === 1'b1 && latency_per_pat == 0) begin
            latency_per_pat = 1;
        end
        
        if(latency_per_pat > file_iter * 150000) begin
            $display("---------------------------------------------------------------------------------------------");
            $display("             FAIL! The execution latency is over %0d cycles.", file_iter * 150000);
            $display("             Received only %0d/%0d outputs", check_idx, TOTAL_PIXELS);
            $display("---------------------------------------------------------------------------------------------");
            repeat(2) @(negedge clk);
            $finish;
        end
        
        if(o_valid === 1'b1) begin
            if (o_data !== current_golden[check_idx]) begin
                error_count = error_count + 1;
                total_errors = total_errors + 1;
                $display("  [ERROR] Pixel %4d: Exp=%0d Got=%0d", check_idx, current_golden[check_idx], o_data);
            end
            check_idx = check_idx + 1;
        end
        
        @(negedge clk);
    end
    
    total_latency = total_latency + latency_per_pat;
end 
endtask

task YOU_PASS_task; 
begin
    $display("========================================================================");
    $display("                        Congratulations!                                ");
    $display("                  You have passed all patterns!                         ");
    $display("            Average Latency        : %0d cycles/pattern", total_latency/PATNUM);
    $display("            Total Latency          : %0d cycles", total_latency);
    $display("                                                                        ");
    $display("========================================================================");

    repeat(2) @(negedge clk);
    $finish;
end
endtask

endmodule
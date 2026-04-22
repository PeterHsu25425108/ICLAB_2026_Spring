`ifdef RTL
    `define CYCLE_TIME 20.0
`endif
`ifdef GATE
    `define CYCLE_TIME 20.0
`endif
`define CYCLE_TIME 20.0

module PATTERN(
    // Output signals
    clk,
	rst_n,
	in_valid,
    in_weight, 
	out_mode,
    // Input signals
    out_valid, 
	out_code
);

// ========================================
// Parameter & Variables
// ========================================
parameter PATNUM = 2; 
parameter IN_WEIGHT_FILE ="../00_TESTBED/in_weight.txt" ;
parameter OUT_MODE_FILE = "../00_TESTBED/out_mode.txt";
parameter GOLDEN_FILE = "../00_TESTBED/golden.txt";
parameter LAT_LIMIT=2000;

integer i_pat, i, j;
// PIs
reg [4:0] in_weight_arr[PATNUM-1:0][0:7];
reg out_mode_arr[PATNUM-1:0];
// Max length of a char's huffman code = 7 for 8 input chars
// 5 output char -> at most 5*7=35 bits for the output code
// gloden
reg [34:0] golden_out[PATNUM-1:0];
// capture the output code
reg [34:0] out_code_capture;

// integers
integer patcount, total_latency, latency_per_pat;
// ========================================
// Input & Output
// ========================================
output reg clk, rst_n, in_valid, out_mode;
output reg [2:0] in_weight;
input out_valid, out_code;

//================================================================
// clock
//================================================================
real CYCLE = `CYCLE_TIME;
initial clk = 0;
always #(CYCLE/2.0) clk = ~clk;

// ========================================
// Pattern Start
// ========================================
initial begin
    load_data;
    reset_signal_task;
    #(CYCLE*3);

    $display("Finish reset task");

    for(patcount=0;patcount<PATNUM;patcount=patcount+1)begin
        $display("Sending input of PATTERN %0d...", patcount);
        send_input;
        $display("Waiting for output of PATTERN %0d...", patcount);
        wait_out_valid_and_check;
        // print pass message for each pattern passed
        $display("PATTERN %0d PASSED!", patcount);
        // wait for 2~4 cycles before sending the next pattern
        // randomize the wait time to better simulate real scenarios
        #(CYCLE*(2 + $urandom_range(0, 2)));
    end
    
    display_pass;
end

task wait_out_valid_and_check;
begin
    $display("enter wait out_valid");
    @(negedge clk);
    // latency = 1 if out_valid rises immediately after in_valid falls
    latency_per_pat = 0;
    while(out_valid !== 1) begin
        latency_per_pat = latency_per_pat + 1;
        $display("Waiting for out_valid=1, latency = %0d", latency_per_pat);
        $display("out_valid=%b, out_code=%b", out_valid, out_code);
        if(latency_per_pat > LAT_LIMIT) begin
            $display("---------------------------------------------------------------------------------------------");
            $display("             FAIL! Latency exceeds limit at %4t.", $time);
            $display("             Execution latency: %0d cycles, Limit: %0d cycles", latency_per_pat, LAT_LIMIT);
            $display("---------------------------------------------------------------------------------------------");
            $finish;
        end
       @(negedge clk);
    end

    $display("out_valid=1 arrived");

    j = 0;
    out_code_capture = 6'd0;
    while (out_valid === 1) begin
        j = j + 1;
        if(j > 35)begin // Max len of the huffman code of 8 characters should be <= 7
            $display("---------------------------------------------------------------------------------------------");
            $display("             FAIL! Output code length exceeds limit at %4t.", $time);
            $display("             Output code length: %0d bits, Code length Limit: 35 bits", j);
            $display("---------------------------------------------------------------------------------------------");
            $finish;
        end
        out_code_capture = {out_code_capture[34:1], out_code};
        
        @(negedge clk);
    end

    if(out_code_capture !== golden_out[patcount]) begin
        $display("---------------------------------------------------------------------------------------------");
        $display("             FAIL! Wrong output at %4t.", $time);
        $display("             Expected: %b, Got: %b", golden_out[patcount], out_code);
        $display("---------------------------------------------------------------------------------------------");
        $finish;
    end

    total_latency = total_latency + latency_per_pat;
end
endtask

task send_input;
begin
    @(negedge clk);
    in_valid = 1'b1;
    out_mode = out_mode_arr[patcount];
    for(i=0;i<8;i=i+1)begin
        $display("Sent out_mode for pat %0d", i);

        in_weight = in_weight_arr[patcount][i];
         $display("Sent in_weight for pat %0d", i);
        @(negedge clk);
        out_mode = 1'bx;
    end
    in_valid=0;
    in_weight = 3'bx;
    $display("Finished sending input for pat %0d", patcount);
end
endtask

task load_data;
begin
    $display("  Loading Weights...  (%s)", IN_WEIGHT_FILE);
    $readmemh(IN_WEIGHT_FILE, in_weight_arr);
    $display("  Loading Modes...  (%s)", OUT_MODE_FILE);
    $readmemh(OUT_MODE_FILE, out_mode_arr);
    $display("  Loading Golden...  (%s)", GOLDEN_FILE);
    $readmemh(GOLDEN_FILE, golden_out);

    // print the content of the input and golden data for debugging
    for(i_pat=0; i_pat<PATNUM; i_pat=i_pat+1)begin
        $display("PATTERN %0d:", i_pat);
        $display("  Weights: %p", in_weight_arr[i_pat]);
        $display("  Mode: %b", out_mode_arr[i_pat]);
        $display("  Golden Output Code: %b", golden_out[i_pat]);
    end
end
endtask

task reset_signal_task; 
begin 
    rst_n = 1'b1;
	in_valid = 1'b0;
    in_weight = 3'bx;
    out_mode = 1'bx;
    force clk = 1'b0;

    #(CYCLE);  rst_n = 0;
    #(CYCLE*3); rst_n = 1;
    if((out_valid !== 0) || (out_code !== 1'b0)) begin
        $display("---------------------------------------------------------------------------------------------");
        $display("             FAIL! Output signals should be 0 after reset at %4t.", $time);
        $display("---------------------------------------------------------------------------------------------");
        $finish;
    end
    #(CYCLE);
    release clk;
end 
endtask

task display_pass;
begin
        $display("\n");
        $display("        ----------------------------               ");
        $display("        --                        --       |\\__||  ");
        $display("        --  Congratulations !!    --      / O.O  | ");
        $display("        --                        --    /_____   | ");
        $display("        --  Simulation out!!     --    /^ ^ ^ \\  |");
        $display("        --                        --  |^ ^ ^ ^ |w| ");
        $display("        ----------------------------   \\m___m__|_|");
        $display("----------------------------------------------------------------------------------------------");
        $display("            Total Patterns           : %0d", PATNUM);
        $display("            Average Latency        : %0d cycles/pattern", total_latency/PATNUM);
        $display("            Total Latency          : %0d cycles", total_latency);
        $display("---------------------------------------------------------------------------------------------");
        $display("\n");
        $finish;
end
endtask

endmodule
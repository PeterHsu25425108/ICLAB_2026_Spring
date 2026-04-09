`define CYCLE_TIME 20.0

module PATTERN(
    output reg        clk,
    output reg        rst_n,
    output reg        in_valid,
    output reg  [2:0] in_weight, 
    output reg        out_mode,
    input  wire       out_valid, 
    input  wire       out_code
);

// ========================================
// Clock & 變數宣告
// ========================================
real CYCLE = `CYCLE_TIME;
initial clk = 1'b0;
always #(CYCLE/2.0) clk = ~clk;

parameter PATNUM = 100;
integer patcount;
integer i;
integer total_latency;


reg [2:0]  mem_weight [0:PATNUM*8-1]; 
reg        mem_mode   [0:PATNUM-1];   
reg [63:0] mem_golden [0:PATNUM-1];   
reg [5:0]  mem_len    [0:PATNUM-1]; 


reg [63:0] current_golden;
integer    current_len;


initial begin

    $readmemh("../00_TESTBED/weight_in.txt", mem_weight);
    $readmemh("../00_TESTBED/mode_in.txt",   mem_mode);
    $readmemb("../00_TESTBED/golden_out.txt", mem_golden);
    $readmemh("../00_TESTBED/len_out.txt",   mem_len);

    $display("=================================");
    $display("=     CYCLE TIME : %0.2f         =", CYCLE);
    $display("=================================");

    reset_signal_task;

    for (patcount = 0; patcount < PATNUM; patcount = patcount + 1) begin
        current_golden = mem_golden[patcount];
        current_len    = mem_len[patcount];
        
        input_data_task;         
        wait_and_check_task; 
    end

    YOU_PASS_task;
end

// ========================================
// Tasks
// ========================================
task reset_signal_task; begin
    rst_n = 1'b1;
    in_valid = 1'b0;
    in_weight = 'dx;
    out_mode = 'dx;
    total_latency = 0;
    force clk = 1'b0;

    #(CYCLE*3); rst_n = 1'b0;
    #(CYCLE*4);
    if((out_valid !== 1'd0) || (out_code)) begin
        $display("=========================================================");
        $display("=    FAIL! Output signals should be 0 after reset.      =");
        $display("=========================================================");
        $finish;
    end
    rst_n = 1'b1;
    #(CYCLE);
    release clk;
end endtask

task input_data_task; begin
    for(i = 0; i < 8; i = i + 1) begin
        @(negedge clk);
        in_valid  = 1'b1;
        in_weight = mem_weight[patcount * 8 + i];

        if(i == 0) out_mode = mem_mode[patcount];
        else       out_mode = 1'bx;
    end

    @(negedge clk);
    in_valid  = 1'b0;
    in_weight = 3'bx;
    out_mode  = 1'bx;
end endtask

integer latency_per_pat;
integer latency_wait_for_pull_down;
integer check_idx;
reg     expected_bit;
reg [63:0] your_bitstream; 
integer str_idx;           
reg     has_error;         
integer first_err_bit;     

task wait_and_check_task; begin
    latency_per_pat = 0;
	latency_wait_for_pull_down = 0;
    check_idx       = 0;
    your_bitstream  = 64'd0;
    has_error       = 1'b0;
    first_err_bit   = -1;
    while (out_valid === 1'b0) begin
        $display("waiting for out_valid to go HIGH... (Latency: %0d cycles)", latency_per_pat);
        @(negedge clk);
        latency_per_pat = latency_per_pat + 1;
        if (latency_per_pat > 1500) begin 
            $display("=========================================================");
            $display("=  [FAIL] Timeout! out_valid did not go HIGH.           =");
            $display("=========================================================");
            $finish;
        end
    end

    while (out_valid === 1'b1) begin
        your_bitstream = (your_bitstream << 1) | out_code;
        
        if (check_idx < current_len) begin
            expected_bit = current_golden[current_len - 1 - check_idx];
            
            if (out_code !== expected_bit && has_error == 1'b0) begin
                has_error     = 1'b1;
                first_err_bit = check_idx + 1; 
            end
        end

        check_idx = check_idx + 1;
        
        @(negedge clk);
		latency_wait_for_pull_down = latency_wait_for_pull_down +1;
        if (latency_wait_for_pull_down > 2000) begin
            $display("=========================================================");
            $display("=  [FAIL] Timeout! out_valid never went LOW.            =");
            $display("=========================================================");
            $finish;
        end
    end

    if (check_idx !== current_len || has_error == 1'b1) begin
        $display("=========================================================");
        $display("=  [FAIL] Pattern No.%4d                                =", patcount);
        if (check_idx < current_len) begin
            $display("=  Error: Insufficient length! (Got %0d, Expected %0d)   =", check_idx, current_len);
        end else if (check_idx > current_len) begin
            $display("=  Error: Length exceeded! (Got %0d, Expected %0d)       =", check_idx, current_len);
        end else begin
            $display("=  Error: Bit mismatch! (First error at bit %0d)         =", first_err_bit);
        end
        $display("---------------------------------------------------------");
        
        $write("=  Golden Output : ");
        for (str_idx = 0; str_idx < current_len; str_idx = str_idx + 1) begin
            $write("%b", current_golden[current_len - 1 - str_idx]);
        end
        $display("");
        
        $write("=  Your Output   : ");
        for (str_idx = 0; str_idx < check_idx; str_idx = str_idx + 1) begin
            $write("%b", your_bitstream[check_idx - 1 - str_idx]);
        end
        $display("\n=========================================================");
        $finish;
    end

    total_latency = total_latency + latency_per_pat;
    $display("  [PASS] Pattern %0d! (length: %0d bits, Latency: %0d)", patcount, current_len, latency_per_pat);

end endtask

task YOU_PASS_task; begin
    $display("=========================================================");
    $display("=                  Congratulations!                     =");
    $display("=             You have passed all patterns!             =");
    $display("=      Average Latency : %0d cycles/pattern             =", total_latency / PATNUM);
    $display("=      Total Latency   : %0d cycles                     =", total_latency);
    $display("=========================================================");
    $finish;
end endtask

endmodule
`define CYCLE_TIME 50.0
`define PATTERN_NUMBER 1000

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

// Output Port (To DUT)
output reg clk;
output reg rst_n;
output reg instruction_in_valid;
output reg image_in_valid;
output reg weight_in_valid;
output reg [31:0] in_data;
    
// Input Port (From DUT)
input    out_valid;
input  [31:0]  out_data;

//================================================================
// Parameters & Variables
//================================================================
integer patcount;
integer gap_cycles;
integer wait_cycles;
integer i;

reg [31:0] in_img_data [0:127]; // 128 image data
reg [31:0] in_weight_data [0:143]; // 144 weight data
reg [1:0] in_act_mode; // 0: ReLU, 1: Sigmoid, 2: Tanh
reg [31:0] in_instruction; // Instruction data
reg in_pad_mode; // 0: zero padding, 1: replication padding
real golden_out_data_float [0:127]; // 128 golden output data
reg [31:0] out_data_buffer [0:127]; // Buffer to store output data for checking

// Use a unified 10x10 array to prevent shape mismatch in tasks
typedef shortreal fm_t [0:1][0:9][0:9]; 

// Intermediate Feature Maps
fm_t fm_img, fm_pad0, fm_conv0, fm_pool0, fm_act0;
fm_t fm_pad1, fm_conv1, fm_pool1, fm_act1;
fm_t fm_unpool0, fm_pad2, fm_deconv0, fm_act2;
fm_t fm_unpool1, fm_pad3, fm_deconv1, fm_act3;

// Switch Variables for Max Pooling / Unpooling
typedef int sw_t [0:1][0:9][0:9];
sw_t sw_pool0_r, sw_pool0_c;
sw_t sw_pool1_r, sw_pool1_c;

// Weights: [layer][out_channel][in_channel][kernel_h][kernel_w]
shortreal weight [0:3][0:1][0:1][0:2][0:2];

//================================================================
// Clock Generation
//================================================================
initial clk = 0;
// You can adjust your clock period, but the maximum is 50 ns.
always #(`CYCLE_TIME/2.0) clk = ~clk;

//================================================================
// Main Control Flow
//================================================================
initial begin
    reset_signal_task;
    
    for (patcount = 0; patcount < `PATTERN_NUMBER; patcount = patcount + 1) begin
        gen_testcase_task;
        input_task;
        wait_out_valid_task;
        check_ans_task;
        $display("Pattern %0d passed.", patcount);
    end
    
    YOU_PASS_task;
end

//================================================================
// Tasks
//================================================================
task gen_testcase_task;
    shortreal val, min_c, max_c;
    integer c, h, w, layer, out_c, in_c, kh, kw;
    integer data_idx;
begin
    in_act_mode = $urandom_range(0, 3); // 0: Sigmoid, 1: Tanh, 2: ReLU, 3: Leaky ReLU
    in_pad_mode = $urandom_range(0, 1); // 0: Zero padding, 1: Replication padding
    in_instruction = {29'd0, in_pad_mode, in_act_mode};

    // 1. Generate Input Image Data (-127 to 128)
    for (i = 0; i < 128; i = i + 1) begin
        val = ($urandom_range(0, 25500) / 100.0) - 127.0; 
        in_img_data[i] = $shortrealtobits(val);
        c = i / 64; h = (i % 64) / 8; w = i % 8;
        fm_img[c][h][w] = val;
    end

    // 2. Generate Input Weight Data (-1.0 to 1.0)
    data_idx = 0;
    for (layer = 0; layer < 4; layer = layer + 1) begin
        for (out_c = 0; out_c < 2; out_c = out_c + 1) begin
            for (in_c = 0; in_c < 2; in_c = in_c + 1) begin
                for (kh = 0; kh < 3; kh = kh + 1) begin
                    for (kw = 0; kw < 3; kw = kw + 1) begin
                        val = ($urandom_range(0, 20000) / 10000.0) - 1.0;
                        in_weight_data[data_idx] = $shortrealtobits(val);
                        weight[layer][out_c][in_c][kh][kw] = val;
                        data_idx = data_idx + 1;
                    end
                end
            end
        end
    end

    // ==========================================================
    // GOLDEN CALCULATION (Encoder & Decoder Cascade)
    // ==========================================================

    // Stage 1: Preprocessing (Min-Max Scaling) [cite: 178-183]
    for (c = 0; c < 2; c = c + 1) begin
        min_c = fm_img[c][0][0]; max_c = fm_img[c][0][0];
        for (h = 0; h < 8; h = h + 1) for (w = 0; w < 8; w = w + 1) begin
            if (fm_img[c][h][w] < min_c) min_c = fm_img[c][h][w];
            if (fm_img[c][h][w] > max_c) max_c = fm_img[c][h][w];
        end
        for (h = 0; h < 8; h = h + 1) for (w = 0; w < 8; w = w + 1) begin
            fm_img[c][h][w] = (fm_img[c][h][w] - min_c) / (max_c - min_c);
        end
    end

    // Stage 2: Encoder Cascade 
    do_padding(8, in_pad_mode, fm_img, fm_pad0);     // 8x8 -> 10x10
    do_conv(10, 0, fm_pad0, fm_conv0);               // 10x10 -> 8x8
    do_maxpool(8, fm_conv0, fm_pool0, sw_pool0_r, sw_pool0_c); // 8x8 -> 4x4
    do_activation(4, in_act_mode, fm_pool0, fm_act0); // 4x4 -> 4x4

    do_padding(4, in_pad_mode, fm_act0, fm_pad1);    // 4x4 -> 6x6
    do_conv(6, 1, fm_pad1, fm_conv1);                // 6x6 -> 4x4
    do_maxpool(4, fm_conv1, fm_pool1, sw_pool1_r, sw_pool1_c); // 4x4 -> 2x2
    do_activation(2, in_act_mode, fm_pool1, fm_act1); // 2x2 -> 2x2

    // Stage 3: Decoder Cascade [cite: 204-211, 392]
    // Unpool0 uses Position info from Max pooling_1
    do_unpool(2, fm_act1, fm_unpool0, sw_pool1_r, sw_pool1_c); // 2x2 -> 4x4
    do_padding(4, in_pad_mode, fm_unpool0, fm_pad2);           // 4x4 -> 6x6
    do_conv(6, 2, fm_pad2, fm_deconv0);                        // 6x6 -> 4x4
    do_activation(4, in_act_mode, fm_deconv0, fm_act2);        // 4x4 -> 4x4

    // Unpool1 uses Position info from Max pooling_0
    do_unpool(4, fm_act2, fm_unpool1, sw_pool0_r, sw_pool0_c); // 4x4 -> 8x8
    do_padding(8, in_pad_mode, fm_unpool1, fm_pad3);           // 8x8 -> 10x10
    do_conv(10, 3, fm_pad3, fm_deconv1);                       // 10x10 -> 8x8
    do_activation(8, in_act_mode, fm_deconv1, fm_act3);        // 8x8 -> 8x8

    // 4. Map Final Output to Golden Array (Raster Scan)
    for (i = 0; i < 128; i = i + 1) begin
        c = i / 64; h = (i % 64) / 8; w = i % 8;
        golden_out_data_float[i] = fm_act3[c][h][w];
    end

end endtask

// =================================================================
// Modular Math Functions
// =================================================================

task automatic do_padding(
    input int in_size, input bit mode,
    ref fm_t in_arr, ref fm_t out_arr
);
    int ch, r, c;
    int out_size;
begin
    out_size = in_size + 2;
    // Initialize with zeros for Zero Padding
    for(ch=0; ch<2; ch++) for(r=0; r<out_size; r++) for(c=0; c<out_size; c++)
        out_arr[ch][r][c] = 0.0;
        
    // Copy center
    for(ch=0; ch<2; ch++) for(r=0; r<in_size; r++) for(c=0; c<in_size; c++)
        out_arr[ch][r+1][c+1] = in_arr[ch][r][c];

    // Apply Replication Padding boundaries if mode == 1 [cite: 218-310]
    if (mode == 1) begin
        for(ch=0; ch<2; ch++) begin
            for(r=0; r<in_size; r++) begin
                out_arr[ch][r+1][0]          = in_arr[ch][r][0];         // left
                out_arr[ch][r+1][out_size-1] = in_arr[ch][r][in_size-1]; // right
                out_arr[ch][0][r+1]          = in_arr[ch][0][r];         // top
                out_arr[ch][out_size-1][r+1] = in_arr[ch][in_size-1][r]; // bot
            end
            // Corners
            out_arr[ch][0][0]                   = in_arr[ch][0][0];
            out_arr[ch][0][out_size-1]          = in_arr[ch][0][in_size-1];
            out_arr[ch][out_size-1][0]          = in_arr[ch][in_size-1][0];
            out_arr[ch][out_size-1][out_size-1] = in_arr[ch][in_size-1][in_size-1];
        end
    end
end endtask

task automatic do_conv(
    input int in_size, input int l_idx,
    ref fm_t in_arr, ref fm_t out_arr
);
    int oc, ic, r, c, kr, kc;
    int out_size;
    shortreal sum;
begin
    out_size = in_size - 2;
    for(oc=0; oc<2; oc++) begin
        for(r=0; r<out_size; r++) begin
            for(c=0; c<out_size; c++) begin
                sum = 0.0;
                for(ic=0; ic<2; ic++) begin
                    for(kr=0; kr<3; kr++) begin
                        for(kc=0; kc<3; kc++) begin
                            sum = sum + in_arr[ic][r+kr][c+kc] * weight[l_idx][oc][ic][kr][kc];
                        end
                    end
                end
                out_arr[oc][r][c] = sum; // Deconv uses exact same convolution formula [cite: 313]
            end
        end
    end
end endtask

task automatic do_maxpool(
    input int in_size, ref fm_t in_arr, ref fm_t out_arr,
    ref sw_t sw_r, ref sw_t sw_c
);
    int ch, h, w, r, c;
    shortreal max_val;
    int out_size;
begin
    out_size = in_size / 2;
    for(ch=0; ch<2; ch++) begin
        for(h=0; h<out_size; h++) begin
            for(w=0; w<out_size; w++) begin
                max_val = -9999999.0;
                for(r=0; r<2; r++) begin
                    for(c=0; c<2; c++) begin
                        if (in_arr[ch][h*2+r][w*2+c] >= max_val) begin
                            max_val = in_arr[ch][h*2+r][w*2+c];
                            sw_r[ch][h][w] = r;
                            sw_c[ch][h][w] = c;
                        end
                    end
                end
                out_arr[ch][h][w] = max_val;
            end
        end
    end
end endtask

task automatic do_unpool(
    input int in_size, ref fm_t in_arr, ref fm_t out_arr,
    ref sw_t sw_r, ref sw_t sw_c
);
    int ch, h, w, r, c;
    int out_size;
begin
    out_size = in_size * 2;
    // Fill with zeros first [cite: 378]
    for(ch=0; ch<2; ch++) for(h=0; h<out_size; h++) for(w=0; w<out_size; w++)
        out_arr[ch][h][w] = 0.0;
        
    // Place activations back using switch variables
    for(ch=0; ch<2; ch++) begin
        for(h=0; h<in_size; h++) begin
            for(w=0; w<in_size; w++) begin
                r = sw_r[ch][h][w];
                c = sw_c[ch][h][w];
                out_arr[ch][h*2+r][w*2+c] = in_arr[ch][h][w];
            end
        end
    end
end endtask

task automatic do_activation(
    input int size, input int mode,
    ref fm_t in_arr, ref fm_t out_arr
);
    int ch, r, c;
    shortreal val;
begin
    for(ch=0; ch<2; ch++) begin
        for(r=0; r<size; r++) begin
            for(c=0; c<size; c++) begin
                val = in_arr[ch][r][c];
                case(mode)
                    0: val = 1.0 / (1.0 + $exp(-val)); // Sigmoid
                    1: val = ($exp(val) - $exp(-val)) / ($exp(val) + $exp(-val)); // Tanh
                    2: val = (val > 0) ? val : 0.0; // ReLU
                    3: begin // Leaky ReLU
                        // Apply PDF specific subnormal threshold logic [cite: 396-397, 421]
                        if (val <= 0.0 && val > -1.17549435e-38) val = 0.0;
                        else if (val < 0.0) val = val * 0.125;
                    end
                endcase
                out_arr[ch][r][c] = val;
            end
        end
    end
end endtask

// Task to initialize signals and handle the single asynchronous reset
task reset_signal_task; begin
    rst_n = 1'b1;
    instruction_in_valid = 1'b0;
    weight_in_valid = 1'b0;
    image_in_valid = 1'b0;
    in_data = 32'bx; // Tie to unknown state when invalids are low
    
    force clk = 0;
    #10;
    rst_n = 1'b0; // Active-low reset
    #10;
    // check if out_valid and out_data are reset properly
    if (out_valid !== 1'b0 || out_data !== 32'b0) begin
        $display("========================================================================");
        $display("SPEC FAIL: out_valid should be low after reset.");
        $display("========================================================================");
        $finish;
    end

    rst_n = 1'b1;
    release clk;
    
    // Wait a few cycles after reset before starting the first pattern
    @(negedge clk);
    @(negedge clk);
end endtask

// Task to drive inputs strictly on the negative edge of the clock
task input_task; begin
    // 1. Send Instruction (1 cycle)
    instruction_in_valid = 1'b1;
    in_data = in_instruction; // Load instruction data
    @(negedge clk); check_in_out_valid_overlap;
    instruction_in_valid = 1'b0;
    in_data = 32'bx;
    
    // Gap: 2 to 5 cycles
    gap_cycles = $urandom_range(2, 5);
    while (gap_cycles > 0) begin
        @(negedge clk); check_in_out_valid_overlap;
        gap_cycles = gap_cycles - 1;
    end
    
    // 2. Send Weights (144 cycles)
    weight_in_valid = 1'b1;
    for (i = 0; i < 144; i = i + 1) begin
        in_data = in_weight_data[i]; // Load weight data
        @(negedge clk); check_in_out_valid_overlap;
    end
    weight_in_valid = 1'b0;
    in_data = 32'bx;
    
    // Gap: 2 to 5 cycles
    gap_cycles = $urandom_range(2, 5);
    while (gap_cycles > 0) begin
        @(negedge clk); check_in_out_valid_overlap;
        gap_cycles = gap_cycles - 1;
    end
    
    // 3. Send Images (128 cycles)
    image_in_valid = 1'b1;
    for (i = 0; i < 128; i = i + 1) begin
        in_data = in_img_data[i]; // Load image data
        @(negedge clk); check_in_out_valid_overlap;
    end
    image_in_valid = 1'b0;
    in_data = 32'bx;
end endtask

// check if in_valid and out_valid are not high at the same time
task check_in_out_valid_overlap; begin
    if ((instruction_in_valid || weight_in_valid || image_in_valid) && out_valid) begin
        $display("========================================================================");
        $display("SPEC FAIL: in_valid and out_valid should not be high at the same time.");
        $display("========================================================================");
        $finish;
    end
end endtask

// Task to track execution latency and wait for the DUT to output
task wait_out_valid_task; begin
    wait_cycles = 0;
    
    // Wait until out_valid goes high, checking for the 1200 cycle latency limit
    while (out_valid === 1'b0) begin
        if (wait_cycles == 1200) begin
            $display("========================================================================");
            $display("SPEC FAIL: The execution latency exceeded 1200 cycles.");
            $display("========================================================================");
            $finish;
        end
        out_data_buffer[wait_cycles] = out_data; // Store output data for later checking
        @(negedge clk);
        wait_cycles = wait_cycles + 1;
    end
end endtask

real error_val;
// Task to check the output data sequence
task check_ans_task; begin
    // Check for 128 consecutive cycles of out_valid
    for (i = 0; i < 128; i = i + 1) begin
        if (out_valid === 1'b0) begin
            $display("========================================================================");
            $display("SPEC FAIL: out_valid must be high for 128 consecutive cycles.");
            $display("========================================================================");
            $finish;
        end
        
        // Implement IEEE-754 floating point check with < 0.002 error margin here.
        // Calculate relative error
        error_val = $abs((golden_out_data_float[i] - out_data_buffer[i]) / golden_out_data_float[i]);
        if (error_val >= 0.002) begin
            $display("========================================================================");
            $display("SPEC FAIL: Output data mismatch at cycle %0d. Expected: %f, Got: %f, Error: %f", 
                    i, golden_out_data_float[i], out_data_buffer[i], error_val);
            $display("========================================================================");
            $finish;
        end
        
        @(negedge clk);
    end
    
    // Verify out_data resets to zero when out_valid goes low
    if (out_data !== 32'b0) begin
        $display("========================================================================");
        $display("SPEC FAIL: out_data should be zero when out_valid is low.");
        $display("========================================================================");
        $finish;
    end
end endtask

// Final success task
task YOU_PASS_task; begin
    $display("========================================================================");
    $display("                           Congratulations!                             ");
    $display("                You have passed all %0d patterns!                       ", `PATTERN_NUMBER);
    $display("========================================================================");
    $finish;
end endtask

endmodule
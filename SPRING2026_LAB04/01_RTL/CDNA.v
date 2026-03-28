// Weights of all conv/deconv in this design are of the same dimensions
// IN_WID varies
// ch = 2
// kernel width = 3
// stride = 1
module Conv2d #(parameter IN_WID = 8)(
    input clk,
    input rst_n,
    input [31:0] in_data,
    input [31:0] in_weight,
    input pad_mode,
    input weight_valid,
    input input_valid, 
    output reg [31:0] out_data,     // 必須加 reg，因為在 always 區塊中賦值
    output reg output_valid         // 必須加 reg，因為在 always 區塊中賦值
);

// =======================================================================
// 0. Global Parameters & Constants
// =======================================================================
localparam PIXELS_PER_CH = IN_WID * IN_WID;

// =======================================================================
// 1. Weight Input Logic
// =======================================================================
reg [31:0] weight [0:35];
integer i;

always @(posedge clk or negedge rst_n) begin : weight_input_block
    if (!rst_n) begin
        for (i = 0; i < 36; i = i + 1) begin
            weight[i] <= 0;
        end
    end else begin
        // Shift weights down when weight_valid is high
        if (weight_valid) begin
            weight[35] <= in_weight;
            for (i = 0; i < 35; i = i + 1) begin
                weight[i] <= weight[i + 1];
            end
        end
    end
end

// =======================================================================
// 2. Control Counters & Flush Logic
// =======================================================================
reg [10:0] pixel_in_cnt;   // Tracks total valid pixels received
reg [10:0] window_out_cnt; // Tracks total valid 3x3 windows generated
reg [10:0] shift_pulses;   // Tracks total shifts performed

// [新增] 必須把 d1, d2 提早宣告，給下面的 is_flushing 使用
reg [10:0] window_out_cnt_d1, window_out_cnt_d2; 

// 通道指標：前 PIXELS_PER_CH 個 window 屬於 In_Ch 0 (in_ch_idx=0)
wire in_ch_idx = (window_out_cnt >= PIXELS_PER_CH);

// [修正 1] Flush 必須等管線最尾端 (d2) 也收齊 128 個才停止
wire is_flushing = (pixel_in_cnt == 2 * PIXELS_PER_CH) && (window_out_cnt_d2 < 2 * PIXELS_PER_CH);
wire shift_en    = input_valid | is_flushing; 

// [修正 2] 限制 window_valid 最多 128 個，防止 Flush 期間多產生垃圾視窗
wire window_valid = shift_en && (shift_pulses >= IN_WID + 2) && (window_out_cnt < 2 * PIXELS_PER_CH);
always @(posedge clk or negedge rst_n) begin : line_buffer_counters
    if (!rst_n) begin
        pixel_in_cnt   <= 0;
        window_out_cnt <= 0;
        shift_pulses   <= 0;
    end else begin
        // 🌟 核心歸零機制：如果已經滿載 (128)，且又有新的 input_valid 進來，代表下一張圖來了！
        if (input_valid && pixel_in_cnt == 2 * PIXELS_PER_CH) begin
            pixel_in_cnt   <= 1;   // 新圖的第一個像素已經進來了，所以設為 1
            window_out_cnt <= 0;   // 視窗輸出歸零
            shift_pulses   <= 1;   // 已經移位了一次
        end 
        // 正常計數邏輯
        else begin
            if (input_valid)  pixel_in_cnt   <= pixel_in_cnt + 1;
            if (shift_en)     shift_pulses   <= shift_pulses + 1;
            if (window_valid) window_out_cnt <= window_out_cnt + 1;
        end
    end
end

// =======================================================================
// 3. Line Buffer & Padding Logic
// =======================================================================
reg [31:0] sr [0 : 2*IN_WID+2];
integer j;

always @(posedge clk or negedge rst_n) begin : shift_register_block
    if (!rst_n) begin
        for(j=0; j<2*IN_WID+3; j=j+1) sr[j] <= 32'b0;
    end else if (shift_en) begin
        sr[0] <= is_flushing ? 32'b0 : in_data; 
        for(j=0; j<2*IN_WID+2; j=j+1) begin
            sr[j+1] <= sr[j];
        end
    end
end

// Coordinate Tracker
reg [4:0] cx, cy;
always @(posedge clk or negedge rst_n) begin : coordinate_tracker
    if (!rst_n) begin
        cx <= 0; 
        cy <= 0;
    end else if (input_valid && pixel_in_cnt == 2 * PIXELS_PER_CH) begin
        // 🌟 換新影像時，座標強制歸零
        cx <= 0;
        cy <= 0;
    end else if (window_valid) begin
        if (cx == IN_WID - 1) begin
            cx <= 0;
            if (cy == IN_WID - 1) begin
                cy <= 0; 
            end else begin
                cy <= cy + 1;
            end
        end else begin
            cx <= cx + 1;
        end
    end
end

// Boundary Flags & Padding MUXes
wire top_bound   = (cy == 0);
wire bot_bound   = (cy == IN_WID - 1);
wire left_bound  = (cx == 0);
wire right_bound = (cx == IN_WID - 1);

reg [31:0] p00, p01, p02;
reg [31:0] p10, p11, p12;
reg [31:0] p20, p21, p22;

always @(*) begin
    p11 = sr[IN_WID + 1];

    if (pad_mode == 1'b0) begin 
        // Zero Padding
        p00 = (top_bound | left_bound)  ? 32'b0 : sr[2*IN_WID + 2];
        p01 = (top_bound)               ? 32'b0 : sr[2*IN_WID + 1];
        p02 = (top_bound | right_bound) ? 32'b0 : sr[2*IN_WID];
        p10 = (left_bound)              ? 32'b0 : sr[IN_WID + 2];
        p12 = (right_bound)             ? 32'b0 : sr[IN_WID];
        p20 = (bot_bound | left_bound)  ? 32'b0 : sr[2];
        p21 = (bot_bound)               ? 32'b0 : sr[1];
        p22 = (bot_bound | right_bound) ? 32'b0 : sr[0];
    end else begin 
        // Replication Padding
        p00 = (top_bound & left_bound) ? sr[IN_WID + 1]   : 
              (top_bound)              ? sr[IN_WID + 2]   : 
              (left_bound)             ? sr[2*IN_WID + 1] : sr[2*IN_WID + 2];
        p01 = (top_bound)              ? sr[IN_WID + 1]   : sr[2*IN_WID + 1];
        p02 = (top_bound & right_bound)? sr[IN_WID + 1]   : 
              (top_bound)              ? sr[IN_WID]       : 
              (right_bound)            ? sr[2*IN_WID + 1] : sr[2*IN_WID];
        p10 = (left_bound)             ? sr[IN_WID + 1]   : sr[IN_WID + 2];
        p12 = (right_bound)            ? sr[IN_WID + 1]   : sr[IN_WID];
        p20 = (bot_bound & left_bound) ? sr[IN_WID + 1]   : 
              (bot_bound)              ? sr[IN_WID + 2]   : 
              (left_bound)             ? sr[1]            : sr[2];
        p21 = (bot_bound)              ? sr[IN_WID + 1]   : sr[1];
        p22 = (bot_bound & right_bound)? sr[IN_WID + 1]   : 
              (bot_bound)              ? sr[IN_WID]       : 
              (right_bound)            ? sr[1]            : sr[0];
    end
end

// =======================================================================
// 4. Dynamic Weight Selection
// =======================================================================
wire [31:0] w0 [0:8];
wire [31:0] w1 [0:8];

genvar k;
generate
    for (k = 0; k < 9; k = k + 1) begin : weight_mux
        assign w0[k] = in_ch_idx ? weight[k + 9]  : weight[k];
        assign w1[k] = in_ch_idx ? weight[k + 27] : weight[k + 18];
    end
endgenerate

// =======================================================================
// 5. Pipeline Control Signals (Delay Registers)
// =======================================================================
reg valid_d1, valid_d2;
reg in_ch_idx_d1, in_ch_idx_d2;

always @(posedge clk or negedge rst_n) begin : pipeline_ctrl_logic
    if (!rst_n) begin
        valid_d1 <= 0; valid_d2 <= 0;
        in_ch_idx_d1 <= 0; in_ch_idx_d2 <= 0;
        window_out_cnt_d1 <= 0; window_out_cnt_d2 <= 0;
    end else if (shift_en) begin
        valid_d1 <= window_valid;
        valid_d2 <= valid_d1;
        in_ch_idx_d1 <= in_ch_idx;
        in_ch_idx_d2 <= in_ch_idx_d1;
        window_out_cnt_d1 <= window_out_cnt;
        window_out_cnt_d2 <= window_out_cnt_d1;
    end
end

// =======================================================================
// 6. MAC Tree Datapath
// =======================================================================
wire [31:0] p_arr [0:8];
assign p_arr[0] = p00; assign p_arr[1] = p01; assign p_arr[2] = p02;
assign p_arr[3] = p10; assign p_arr[4] = p11; assign p_arr[5] = p12;
assign p_arr[6] = p20; assign p_arr[7] = p21; assign p_arr[8] = p22;

wire [31:0] mult_out0 [0:8];
wire [31:0] mult_out1 [0:8];
reg  [31:0] mult_reg0 [0:8];
reg  [31:0] mult_reg1 [0:8];

genvar m;
generate
    for(m = 0; m < 9; m = m + 1) begin : mac_mults
        DW_fp_mult #(23, 8, 0) u_mult0 (.a(p_arr[m]), .b(w0[m]), .rnd(3'b000), .z(mult_out0[m]), .status());
        DW_fp_mult #(23, 8, 0) u_mult1 (.a(p_arr[m]), .b(w1[m]), .rnd(3'b000), .z(mult_out1[m]), .status());
        
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                mult_reg0[m] <= 32'b0;
                mult_reg1[m] <= 32'b0;
            end else if (shift_en) begin
                mult_reg0[m] <= mult_out0[m];
                mult_reg1[m] <= mult_out1[m];
            end
        end
    end
endgenerate

wire [31:0] add_l1_c0 [0:3];
wire [31:0] add_l1_c1 [0:3];
wire [31:0] add_l2_c0 [0:1];
wire [31:0] add_l2_c1 [0:1];

reg [31:0] reg_add_l2_c0 [0:1];
reg [31:0] reg_add_l2_c1 [0:1];
reg [31:0] reg_mult8_c0;
reg [31:0] reg_mult8_c1;

generate
    for(m = 0; m < 4; m = m + 1) begin : add_l1
        DW_fp_add #(23, 8, 0) u_add_l1_c0 (.a(mult_reg0[m*2]), .b(mult_reg0[m*2+1]), .rnd(3'b000), .z(add_l1_c0[m]), .status());
        DW_fp_add #(23, 8, 0) u_add_l1_c1 (.a(mult_reg1[m*2]), .b(mult_reg1[m*2+1]), .rnd(3'b000), .z(add_l1_c1[m]), .status());
    end
    for(m = 0; m < 2; m = m + 1) begin : add_l2
        DW_fp_add #(23, 8, 0) u_add_l2_c0 (.a(add_l1_c0[m*2]), .b(add_l1_c0[m*2+1]), .rnd(3'b000), .z(add_l2_c0[m]), .status());
        DW_fp_add #(23, 8, 0) u_add_l2_c1 (.a(add_l1_c1[m*2]), .b(add_l1_c1[m*2+1]), .rnd(3'b000), .z(add_l2_c1[m]), .status());
    end
endgenerate

always @(posedge clk or negedge rst_n) begin : mac_reg_l2
    if (!rst_n) begin
        reg_add_l2_c0[0] <= 32'b0; reg_add_l2_c0[1] <= 32'b0; reg_mult8_c0 <= 32'b0;
        reg_add_l2_c1[0] <= 32'b0; reg_add_l2_c1[1] <= 32'b0; reg_mult8_c1 <= 32'b0;
    end else if (shift_en) begin
        reg_add_l2_c0[0] <= add_l2_c0[0]; reg_add_l2_c0[1] <= add_l2_c0[1]; reg_mult8_c0 <= mult_reg0[8];
        reg_add_l2_c1[0] <= add_l2_c1[0]; reg_add_l2_c1[1] <= add_l2_c1[1]; reg_mult8_c1 <= mult_reg1[8];
    end
end

wire [31:0] add_l3_c0, add_l3_c1;
wire [31:0] mac_out_ch0, mac_out_ch1;
reg [31:0] psum_buf0 [0 : PIXELS_PER_CH - 1];
reg [31:0] psum_buf1 [0 : PIXELS_PER_CH - 1];

DW_fp_add #(23, 8, 0) u_add_l3_c0 (.a(reg_add_l2_c0[0]), .b(reg_add_l2_c0[1]), .rnd(3'b000), .z(add_l3_c0), .status());
DW_fp_add #(23, 8, 0) u_add_l3_c1 (.a(reg_add_l2_c1[0]), .b(reg_add_l2_c1[1]), .rnd(3'b000), .z(add_l3_c1), .status());

DW_fp_add #(23, 8, 0) u_add_l4_c0 (.a(add_l3_c0), .b(reg_mult8_c0), .rnd(3'b000), .z(mac_out_ch0), .status());
DW_fp_add #(23, 8, 0) u_add_l4_c1 (.a(add_l3_c1), .b(reg_mult8_c1), .rnd(3'b000), .z(mac_out_ch1), .status());

wire [31:0] acc_in0 = in_ch_idx_d2 ? psum_buf0[window_out_cnt_d2 - PIXELS_PER_CH] : 32'b0;
wire [31:0] acc_in1 = in_ch_idx_d2 ? psum_buf1[window_out_cnt_d2 - PIXELS_PER_CH] : 32'b0;

wire [31:0] final_ch0, final_ch1;
DW_fp_add #(23, 8, 0) u_acc_c0 (.a(mac_out_ch0), .b(acc_in0), .rnd(3'b000), .z(final_ch0), .status());
DW_fp_add #(23, 8, 0) u_acc_c1 (.a(mac_out_ch1), .b(acc_in1), .rnd(3'b000), .z(final_ch1), .status());

// =======================================================================
// 7. Pipeline Reg 3: Partial Sum Buffer & Serialization Output
// =======================================================================


always @(posedge clk or negedge rst_n) begin : partial_sum_logic
    if (!rst_n) begin
        // Reset if necessary
    end else if (valid_d2 && !in_ch_idx_d2 && shift_en) begin
        psum_buf0[window_out_cnt_d2] <= final_ch0; 
        psum_buf1[window_out_cnt_d2] <= final_ch1;
    end
end

reg serialize_active;
reg [10:0] serialize_cnt;
reg [31:0] out_ch1_fifo [0 : PIXELS_PER_CH - 1];
integer s;

always @(posedge clk or negedge rst_n) begin : serialize_trigger
    if (!rst_n) begin
        serialize_active <= 1'b0;
    end else begin
        if (valid_d2 && in_ch_idx_d2 && shift_en && (window_out_cnt_d2 == 2 * PIXELS_PER_CH - 1)) begin
            serialize_active <= 1'b1;
        end else if (serialize_cnt == PIXELS_PER_CH - 1) begin
            serialize_active <= 1'b0;
        end
    end
end

always @(posedge clk or negedge rst_n) begin : output_serialization_logic
    if (!rst_n) begin
        out_data <= 32'b0;
        output_valid <= 1'b0;
        serialize_cnt <= 0;
    end else begin
        if (valid_d2 && in_ch_idx_d2 && shift_en) begin
            out_data <= final_ch0;
            output_valid <= 1'b1;
            
            out_ch1_fifo[PIXELS_PER_CH - 1] <= final_ch1;
            for (s = 0; s < PIXELS_PER_CH - 1; s = s + 1) begin
                out_ch1_fifo[s] <= out_ch1_fifo[s + 1];
            end
        end 
        else if (serialize_active && serialize_cnt < PIXELS_PER_CH) begin
            out_data <= out_ch1_fifo[0];
            output_valid <= 1'b1;
            serialize_cnt <= serialize_cnt + 1;
            
            out_ch1_fifo[PIXELS_PER_CH - 1] <= 32'b0;
            for (s = 0; s < PIXELS_PER_CH - 1; s = s + 1) begin
                out_ch1_fifo[s] <= out_ch1_fifo[s + 1];
            end
        end 
        else begin
            output_valid <= 1'b0;
            if (pixel_in_cnt == 0) serialize_cnt <= 0;
        end
    end
end

// =======================================================================
// Debug Counter (Only for nWave observation, will be optimized away if unused)
// =======================================================================
reg [7:0] debug_out_cnt;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        debug_out_cnt <= 0;
    end else begin
        // 當收到新影像的第一筆資料時歸零
        if (pixel_in_cnt == 1 && input_valid) begin
            debug_out_cnt <= 0;
        end
        // 只要有輸出就 +1
        else if (output_valid) begin
            debug_out_cnt <= debug_out_cnt + 1;
        end
    end
end

endmodule

module MaxPool #(parameter IN_WID = 8)(
    input clk,
    input rst_n,
    input [31:0] in_data,
    input input_valid,
    
    output reg [31:0] out_data,
    output reg [1:0]  out_switch,
    output reg output_valid
);

localparam SR_DEPTH = IN_WID / 2;

// =======================================================================
// 1. 完美自帶 Reset 的座標追蹤器
// =======================================================================
reg [4:0] cx, cy;
always @(posedge clk or negedge rst_n) begin : coord_tracker
    if (!rst_n) begin
        cx <= 0; cy <= 0;
    end else if (input_valid) begin
        if (cx == IN_WID - 1) begin
            cx <= 0;
            if (cy == IN_WID - 1) cy <= 0;
            else cy <= cy + 1;
        end else begin
            cx <= cx + 1;
        end
    end
end

wire is_top_row  = ~cy[0];
wire is_bot_row  =  cy[0];
wire is_even_col = ~cx[0]; // 0, 2, 4... (你不 Shift 的 Cycle)
wire is_odd_col  =  cx[0]; // 1, 3, 5... (你執行環狀 Shift 的 Cycle)

// =======================================================================
// 2. 核心暫存器 (Delay Line) 
// =======================================================================
reg [31:0] sr [0 : SR_DEPTH - 1];
reg [1:0]  pos_sr [0 : SR_DEPTH - 1];
integer i;

// =======================================================================
// 3. 單一比較器與極簡 Data Path
// =======================================================================
// 第一格的定義：上半部 且 是偶數列
wire is_first = is_top_row && is_even_col;

// 你的神來之筆：永遠只跟 sr[0] 比較！
wire [31:0] cmp_b = sr[0]; 

wire a_gt_b;
DW_fp_cmp #(23, 8, 0) u_cmp (
    .a(in_data),
    .b(cmp_b),
    .zctr(1'b0),
    .aeqb(), .altb(), .agtb(a_gt_b), .unordered(),
    .z0(), .z1(), .status0(), .status1()
);

wire [31:0] next_max = is_first ? in_data : (a_gt_b ? in_data : cmp_b);

wire [1:0] current_pos = {cy[0], cx[0]};
wire [1:0] next_pos    = is_first ? current_pos : (a_gt_b ? current_pos : pos_sr[0]);

// =======================================================================
// 4. 時序更新邏輯 (你的環狀移位魔法)
// =======================================================================
always @(posedge clk or negedge rst_n) begin : update_and_output
    if (!rst_n) begin
        for (i = 0; i < SR_DEPTH; i = i + 1) begin
            sr[i] <= 0; pos_sr[i] <= 0;
        end
        out_data <= 0; out_switch <= 0; output_valid <= 0;
    end else begin
        if (input_valid) begin
            
            // 【階段 A：偶數列 (x=0, 2, 4)】-> 不移位，sr[0] 充當 iter_max
            if (is_even_col) begin
                sr[0]     <= next_max;
                pos_sr[0] <= next_pos;
            end 
            // 【階段 B：奇數列 (x=1, 3, 5)】-> 執行環狀移位 (Circular Shift)
            else begin
                if (SR_DEPTH == 1) begin
                    // IN_WID=2 的特例保護
                    sr[0]     <= next_max;
                    pos_sr[0] <= next_pos;
                end else begin
                    // 1. 新的最大值推入 sr[1]
                    sr[1]     <= next_max;
                    pos_sr[1] <= next_pos;
                    
                    // 2. 陣列大風吹
                    for (i = 2; i < SR_DEPTH; i = i + 1) begin
                        sr[i]     <= sr[i - 1];
                        pos_sr[i] <= pos_sr[i - 1];
                    end
                    
                    // 3. 頭尾相接：把最舊的歷史紀錄繞回 sr[0]，完美準備給下一個 Cycle！
                    sr[0]     <= sr[SR_DEPTH - 1];
                    pos_sr[0] <= pos_sr[SR_DEPTH - 1];
                end
            end

            // 【輸出控制】-> 依然只在右下角觸發
            if (is_bot_row && is_odd_col) begin
                out_data     <= next_max;
                out_switch   <= next_pos;
                output_valid <= 1'b1;
            end else begin
                output_valid <= 1'b0;
            end
            
        end else begin
            output_valid <= 1'b0;
        end
    end
end

endmodule

// module UnPool#(parameter IN_WID= 8)(
//     clk,
//     rst_n,
//     in_data,
//     out_data,
//     input_valid, // high when a next input pixel is sent
//     output_valid // notify the later stages a new pixel is being sent
// );

// endmodule

module ActFunc (
    input wire         clk,
    input wire         rst_n,
    input wire [31:0]  in_data,
    input wire [1:0]   act_mode,      // Added: 00=Sigmoid, 01=Tanh, 10=ReLU, 11=Leaky ReLU
    input wire         input_valid,   // high when a next input pixel is sent
    
    output reg [31:0]  out_data,
    output reg         output_valid   // notify the later stages a new pixel is being sent
);

// IEEE floating point parameters
parameter inst_sig_width = 23;
parameter inst_exp_width = 8;
parameter inst_ieee_compliance = 0;
parameter inst_arch = 0;

// IEEE Constants
wire [31:0] FLOAT_ONE = 32'h3F800000;

// =======================================================================
// Stage 0: Combinational Logic (Fast Paths & Exp Setup)
// =======================================================================
wire sign_bit = in_data[31];
wire [7:0] exp_val = in_data[30:23];
wire [22:0] frac_val = in_data[22:0];

// --- 1. Fast Path: ReLU & Leaky ReLU (Combinational) ---
wire [31:0] relu_comb;
wire [31:0] lrelu_comb;
wire underflow_flag;

assign relu_comb = (~sign_bit) ? in_data : 32'b0;

// Leaky ReLU: flush to zero if -2^-123 < x <= 0 (exponent <= 3)
assign underflow_flag = sign_bit & (exp_val <= 8'd3);
assign lrelu_comb = (~sign_bit)      ? in_data :
                    (underflow_flag) ? 32'b0 :
                    {1'b1, exp_val - 8'd3, frac_val}; // Multiply by 0.125

// --- 2. Exp Setup: Sigmoid (-x) & Tanh (2x) ---
wire is_zero = (in_data[30:0] == 31'b0);
wire [31:0] neg_x = {~sign_bit, exp_val, frac_val};
wire [31:0] mul2_x = is_zero ? 32'b0 : {sign_bit, exp_val + 8'd1, frac_val};

wire [31:0] exp_in_comb;
assign exp_in_comb = (act_mode == 2'b00) ? neg_x : mul2_x;


// =======================================================================
// Pipeline Stage 1: Register before DW_fp_exp
// =======================================================================
reg [31:0] exp_in_reg;
reg valid_d1;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        exp_in_reg <= 32'b0;
        valid_d1   <= 1'b0;
    end else begin
        exp_in_reg <= exp_in_comb;
        valid_d1   <= input_valid;
    end
end

// =======================================================================
// DW_fp_exp IP Core
// =======================================================================
wire [31:0] exp_out_comb;

DW_fp_exp #(inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_arch) u_exp (
    .a(exp_in_reg),
    .z(exp_out_comb),
    .status()
);

// =======================================================================
// Pipeline Stage 2: Register after DW_fp_exp
// =======================================================================
reg [31:0] exp_out_reg;
reg valid_d2;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        exp_out_reg <= 32'b0;
        valid_d2    <= 1'b0;
    end else begin
        exp_out_reg <= exp_out_comb;
        valid_d2    <= valid_d1;
    end
end

// =======================================================================
// Stage 2.5: Shared Combinational logic for Sigmoid and Tanh
// =======================================================================
wire [31:0] add_out, recip_out, sub_out;
wire [31:0] tanh_mul2_comb;

// 1. Compute (e^k + 1)
DW_fp_add #(inst_sig_width, inst_exp_width, inst_ieee_compliance) u_add (
    .a(exp_out_reg),
    .b(FLOAT_ONE),
    .rnd(3'b000),
    .z(add_out),
    .status()
);

// 2. Compute 1 / (e^k + 1) -> This is the final answer for Sigmoid
DW_fp_recip #(inst_sig_width, inst_exp_width, inst_ieee_compliance) u_recip (
    .a(add_out),
    .rnd(3'b000),
    .z(recip_out),
    .status()
);

// 3. Multiply by 2.0 for Tanh (Shift Exponent)
assign tanh_mul2_comb = (recip_out[30:0] == 31'b0) ? 32'b0 :
                        {recip_out[31], recip_out[30:23] + 8'd1, recip_out[22:0]};

// 4. Compute 1.0 - (2 / (e^2x + 1)) -> This is the final answer for Tanh
DW_fp_sub #(inst_sig_width, inst_exp_width, inst_ieee_compliance) u_sub (
    .a(FLOAT_ONE),
    .b(tanh_mul2_comb),
    .rnd(3'b000),
    .z(sub_out),
    .status()
);

// =======================================================================
// Pipeline Stage 3: Final Output Isolation FF & MUX
// =======================================================================
reg [31:0] next_out_data;
reg        next_out_valid;

// Select data and valid signals based on act_mode to achieve optimal latency
always @(*) begin
    case (act_mode)
        2'b00: begin // Sigmoid (3 cycles latency)
            next_out_data  = recip_out;
            next_out_valid = valid_d2;
        end
        2'b01: begin // Tanh (3 cycles latency)
            next_out_data  = sub_out;
            next_out_valid = valid_d2;
        end
        2'b10: begin // ReLU (1 cycle latency, bypassing pipeline)
            next_out_data  = relu_comb;
            next_out_valid = input_valid; 
        end
        2'b11: begin // Leaky ReLU (1 cycle latency, bypassing pipeline)
            next_out_data  = lrelu_comb;
            next_out_valid = input_valid;
        end
        default: begin
            next_out_data  = 32'b0;
            next_out_valid = 1'b0;
        end
    endcase
end

// Output isolation Flip-Flops
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        out_data     <= 32'b0;
        output_valid <= 1'b0;
    end else begin
        out_data     <= next_out_data;
        output_valid <= next_out_valid;
    end
end

endmodule

module PreProcess (
    // input
    input clk,
    input rst_n,
    input image_in_valid,
    input [31:0] in_data,
    output reg [31:0] out_data,
    // output 
    output reg output_valid
    // output reg done
);

// Image storage moved from CDNA
reg [31:0] in_image[0:63];
reg img_arrived;
integer i;

// incre when imag_in_valid == 1
reg [7:0] preproc_counter;

// Having recieved all pixels of ch0/1, this signal is propageted as the output_valid signal
wire ch_allset;
// the current channel we are computing
wire curr_ch;
// indicate if we are recieving the first pixel of a new ch
wire first_pixel;

// the valid chain
reg [3:0] valid_chain;

// the max value of the current channel;
// used for pipeline propagation
// refreshed when ch_allset == 1
reg [31:0] ch_max, ch_min;

// I/O from minmax IP
wire [31:0] dwout_max, dwout_min;
// wire [31:0] dwin_max, dwin_min;

// maintain the max/min value thruout the input iterations
reg [31:0] iter_max, iter_min;

// ch_allset logic
assign ch_allset = (preproc_counter ==63) | (preproc_counter ==127) && image_in_valid;
// first pixel logic
assign first_pixel = (preproc_counter ==0) | (preproc_counter ==64) && image_in_valid;
// current channel logic
// assign curr_ch = preproc_counter[6];

// main computation pipeline declaration
wire [31:0] nxt_denom, nxt_numer; // call subtraction IP
reg [31:0] denom, numer;
wire [31:0] denom_reciprocal; // call DW_fp_recip

wire [31:0] nxt_out_data; // call mult
reg [31:0] numer_2_mult; 
reg [31:0] denom_recip_2_mult; 
wire [31:0] pixel_2_sub; // the pixel used for numerator computation

// maintain per iter min/max value
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        iter_max <= 0;
        iter_min <= 0;
    end else begin
        iter_max <= first_pixel ? in_data : dwout_max;
        iter_min <= first_pixel ? in_data : dwout_min;
    end
end

// IEEE floating point parameter
parameter inst_sig_width = 23;
parameter inst_exp_width = 8;
parameter inst_ieee_compliance = 0;
parameter inst_arch_type = 0;
parameter inst_arch = 0;
parameter inst_faithful_round = 0;
// call IP to compute min/max
DW_fp_cmp #(inst_sig_width, inst_exp_width, inst_ieee_compliance) cmp_max (
    .a(in_data),
    .b(iter_max),
    .zctr(1'b0),
    .aeqb(),
    .altb(),
    .agtb(),
    .unordered(),
    .z0(),            // Unused
    .z1(dwout_max),    // Connects to Max(in_data, iter_max)
    .status0(),
    .status1()
);

DW_fp_cmp #(inst_sig_width, inst_exp_width, inst_ieee_compliance) cmp_min (
    .a(in_data),
    .b(iter_min),
    .zctr(1'b0),
    .aeqb(),
    .altb(),
    .agtb(),
    .unordered(),
    .z0(dwout_min),            // Unused
    .z1(),    // Connects to Max(in_data, iter_max)
    .status0(),
    .status1()
);

// maxmin update
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        ch_max <= 0;
        ch_min <= 0;
    end else begin
        if(ch_allset) begin // update min/max value
            ch_max <= dwout_max;
            ch_min <= dwout_min;
        end
        else begin // hold current value
            ch_max <= ch_max;
            ch_min <= ch_min;
        end
    end
end

// ========================
// Main computation pipeline
// ========================
// schedule Pc,i,j input

// call subtraction to compute nxt_denom & nxt_numer
DW_fp_sub #(inst_sig_width, inst_exp_width, inst_ieee_compliance) sub_denom (
    .a(ch_max),
    .b(ch_min),
    .rnd(3'b000),
    .z(nxt_denom),
    .status()
);

assign pixel_2_sub = in_image[0];
DW_fp_sub #(inst_sig_width, inst_exp_width, inst_ieee_compliance) sub_numer (
    .a(pixel_2_sub),
    .b(ch_min),
    .rnd(3'b000),
    .z(nxt_numer),
    .status()
);

// calcualte the numerator  & denominator
always @(posedge clk or negedge rst_n) begin : compute_denom_numer
    if(!rst_n) begin
        denom <= 0;
        numer <= 0;
    end else begin
        denom <= nxt_denom;
        numer <= nxt_numer;
    end
end

// call DW_fp_recip
DW_fp_recip #(inst_sig_width, inst_exp_width, inst_ieee_compliance) recip_denom (
    .a(denom),
    .rnd(3'b000),
    .z(denom_reciprocal),
    .status()
);

always @(posedge clk or negedge rst_n) begin : mult_input
    if(!rst_n) begin
        denom_recip_2_mult <= 0;
        numer_2_mult <= 0;
    end else begin
        denom_recip_2_mult <= denom_reciprocal;
        numer_2_mult <= numer;
    end
end

// call DW_fp_mult to compute the final output
DW_fp_mult #(inst_sig_width, inst_exp_width, inst_ieee_compliance) mult_final (
    .a(numer_2_mult),
    .b(denom_recip_2_mult),
    .rnd(3'b000),
    .z(nxt_out_data),
    .status()
);

always @(posedge clk or negedge rst_n) begin : output_logic
    if(!rst_n) begin
        out_data <= 0;
    end else begin
        out_data <= nxt_out_data;
    end
end

always @(posedge clk or negedge rst_n) begin : preproc_counter_logic
    if(!rst_n) begin
        preproc_counter <= 0;
    end
    else begin
        // preproc_counter <= ((image_in_valid || img_arrived) && preproc_counter < 195) ? preproc_counter + 1 : preproc_counter;
        preproc_counter <= ((!image_in_valid && preproc_counter == 0) || (preproc_counter >= 194)) ? 0 : preproc_counter + 1;
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        img_arrived <= 0;
    end else begin
        img_arrived <= (image_in_valid) ? 1 : img_arrived;
    end
end

// output valid ctrl
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        output_valid <= 0;
    end else begin
        output_valid <= (preproc_counter >= 66 && preproc_counter < 194) ? 1 : 0; // valid when the second channel starts to be processed
    end
end

always @(posedge clk or negedge rst_n) begin : image_input_block
    if(!rst_n) begin
        for(i=0; i<64; i=i+1) begin
            in_image[i] <= 0;
        end
    end
    else begin
        if(image_in_valid) begin
            in_image[63] <= in_data; // 新資料從 63 進入
            for(i=0; i<63; i=i+1) begin
                in_image[i] <= in_image[i+1]; // 資料往 0 的方向移位
            end
        end
        else begin
            in_image[63] <= 0; // 新資料從 63 進入
            for(i=0; i<63; i=i+1) begin
                in_image[i] <= in_image[i+1]; // 資料往 0 的方向移位
            end
        end
    end
end

endmodule

module CDNA(
    // Input Port
    clk,
    rst_n,
    instruction_in_valid,
    image_in_valid,
    weight_in_valid,
    in_data,
    
    // Output Port
    out_valid,
    out_data
);

input         clk;
input         rst_n;
input         instruction_in_valid;
input         image_in_valid;
input         weight_in_valid;
input  [31:0] in_data;

output reg        out_valid;
output reg [31:0] out_data;

// IEEE floating point parameter
parameter inst_sig_width = 23;
parameter inst_exp_width = 8;
parameter inst_ieee_compliance = 0;
parameter inst_arch_type = 0;
parameter inst_arch = 0;
parameter inst_faithful_round = 0;

// ==== Input storage reg =======
reg repli_pad;
reg [1:0] act_mode;

// reg [31:0] Conv0_weight[35:0];
// reg [31:0] Conv1_weight[35:0];
// reg [31:0] DeConv0_weight[35:0];
// reg [31:0] DeConv1_weight[35:0];
wire [31:0] c0_out_data;
wire c0_out_valid;

reg [7:0] weight_cnt;
wire [31:0] pre_out_data;
wire pre_out_valid;
integer i;

// maxpool output and control signal
wire [31:0] maxpool0_out_data;
wire maxpool0_out_valid;
wire [1:0] maxpool0_out_switch; // 2-bit switch to indicate the position of the max value in the 2x2 grid

wire [31:0] maxpool1_out_data;
wire maxpool1_out_valid;
wire [1:0] maxpool1_out_switch; // 2-bit switch to indicate the position of the max value in the 2x2 grid

// store the position of maxpool output in ther 2x2 grid, will be used by unpooling
reg [1:0] sw_pool0_fifo [0:31]; // 深度 32，供 Unpool1 使用
reg [1:0] sw_pool1_fifo [0:7];  // 深度 8，供 Unpool0 使用
integer k;

// main counter
reg [8:0] main_counter;

always @(posedge clk or negedge rst_n) begin : main_cnt_logic
    if(!rst_n) begin
        main_counter <= 0;
    end
    else begin
        // main_counter <= (image_in_valid || instruction_in_valid || weight_in_valid) ?
        //                 main_counter + 1 : main_counter;
        if (instruction_in_valid) begin
            main_counter <= 1; // 收到新測資的第一個訊號，強制重新起算
        end
        else if (image_in_valid || weight_in_valid) begin
            main_counter <= main_counter + 1;
        end
    end
end

// =======================================================================
// Weight Counter & Distribution Logic
// =======================================================================


always @(posedge clk or negedge rst_n) begin : weight_cnt_logic
    if (!rst_n) begin
        weight_cnt <= 0;
    end else begin
        // Reset counter when weight_in_valid is low, ensuring clean start
        if (weight_in_valid) begin
            weight_cnt <= weight_cnt + 1;
        end else begin
            weight_cnt <= 0;
        end
    end
end

// Generate specific valid signals for each layer (36 weights per layer)
wire w_valid_c0  = weight_in_valid && (weight_cnt < 36);
wire w_valid_c1  = weight_in_valid && (weight_cnt >= 36 && weight_cnt < 72);
wire w_valid_dc0 = weight_in_valid && (weight_cnt >= 72 && weight_cnt < 108);
wire w_valid_dc1 = weight_in_valid && (weight_cnt >= 108 && weight_cnt < 144);

// ================== Input storage logic =================
always @(posedge clk or negedge rst_n) begin : instruction_input_block
    if(!rst_n) begin
        repli_pad <= 0;
        act_mode <= 0;
    end
    else begin
        repli_pad <= instruction_in_valid ? in_data[2] : repli_pad;
        act_mode <= instruction_in_valid ? in_data[1:0] : act_mode;
    end
end


// =======================================================================
// Module Instantiations
// ======================================================================

PreProcess u_PreProcess (
    .clk(clk),
    .rst_n(rst_n),
    .image_in_valid(image_in_valid),
    .in_data(in_data),
    .out_data(pre_out_data),
    .output_valid(pre_out_valid)
    // .done(pre_done)
);

Conv2d #(.IN_WID(8)) u_Conv0 (
    .clk(clk),
    .rst_n(rst_n),
    .in_data(pre_out_data),
    .in_weight(in_data),
    .pad_mode(repli_pad),
    .weight_valid(w_valid_c0),   // Only high for the first 36 cycles
    .input_valid(pre_out_valid), 
    .out_data(c0_out_data),
    .output_valid(c0_out_valid)
);

MaxPool #(8) u_maxpool0 (
    .clk(clk),
    .rst_n(rst_n),
    .in_data(c0_out_data),
    .input_valid(c0_out_valid),
    .out_data(maxpool0_out_data), 
    .out_switch(maxpool0_out_switch), // Connect to FIFO for UnPool
    .output_valid(maxpool0_out_valid) 
);

// 當 MaxPool0 吐出有效結果時，把 2-bit Switch 推入 FIFO
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (k = 0; k < 32; k = k + 1) begin
            sw_pool0_fifo[k] <= 0;
        end
    end else if (maxpool0_out_valid) begin
        sw_pool0_fifo[31] <= maxpool0_out_switch; // 剛產生的訊號從尾端進入
        for (k = 0; k < 31; k = k + 1) begin
            sw_pool0_fifo[k] <= sw_pool0_fifo[k + 1]; // 依序往前推
        end
    end
end

// ==== Output logic ======
always @(posedge clk or negedge rst_n) begin : output_logic
    if(!rst_n) begin
        out_valid <= 0;
        out_data <= 0;
    end else begin
        // out_valid <= (main_counter >= 145) ? 1 : 0;
    end
end

endmodule
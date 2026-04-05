// the sram control commands
`define HIGHZ 3'b000
`define STANDBY 3'b001
`define READ 3'b111
`define WRITE 3'b101

// wrap the sram inside
// Stores 64x64x8bit(unsigned) => Open up 4 banks of 128bitx64 for parallel W/R
// or maybe we can divide it into 4 banks to allow accessing the entire row
// each read gets 16x8bit, and each write requires 64 i_image inputs
module SRAM_IMG (
    input wire [5:0] A, // 64 words, W/R addr are shared among the 4 banks
    output wire [511:0] Dout_bus,
    input wire [511:0] Din_bus,
    input wire clk ,
    input wire WEB ,
    input wire OE ,
    input wire CS 
);

SRAM64x128_WRAP sram_img_bank0 (
    .A(A),
    .Dout(Dout_bus[127:0]),
    .Din(Din_bus[127:0]),
    .clk(clk),
    .WEB(WEB),
    .OE(OE),
    .CS(CS)
);

SRAM64x128_WRAP sram_img_bank1 (
    .A(A),
    .Dout(Dout_bus[255:128]),
    .Din(Din_bus[255:128]),
    .clk(clk),
    .WEB(WEB),
    .OE(OE),
    .CS(CS)
);

SRAM64x128_WRAP sram_img_bank2 (
    .A(A),
    .Dout(Dout_bus[383:256]),
    .Din(Din_bus[383:256]),
    .clk(clk),
    .WEB(WEB),
    .OE(OE),
    .CS(CS)
);

SRAM64x128_WRAP sram_img_bank3 (
    .A(A),
    .Dout(Dout_bus[511:384]),
    .Din(Din_bus[511:384]),
    .clk(clk),
    .WEB(WEB),
    .OE(OE),
    .CS(CS)
);

endmodule

module SRAM64x128_WRAP(
    input wire [5:0] A,
    output wire [127:0] Dout,
    input wire [127:0] Din,
    input wire clk,
    input wire WEB,
    input wire OE,
    input wire CS
);

    SRAM_64x128bit u_sram_64x128 (
        A[0], A[1], A[2], A[3], A[4], A[5],
        Dout[0], Dout[1], Dout[2], Dout[3], Dout[4], Dout[5], Dout[6], Dout[7], Dout[8], Dout[9], Dout[10], Dout[11], Dout[12], Dout[13], Dout[14], Dout[15],
        Dout[16], Dout[17], Dout[18], Dout[19], Dout[20], Dout[21], Dout[22], Dout[23], Dout[24], Dout[25], Dout[26], Dout[27], Dout[28], Dout[29], Dout[30], Dout[31],
        Dout[32], Dout[33], Dout[34], Dout[35], Dout[36], Dout[37], Dout[38], Dout[39], Dout[40], Dout[41], Dout[42], Dout[43], Dout[44], Dout[45], Dout[46], Dout[47],
        Dout[48], Dout[49], Dout[50], Dout[51], Dout[52], Dout[53], Dout[54], Dout[55], Dout[56], Dout[57], Dout[58], Dout[59], Dout[60], Dout[61], Dout[62], Dout[63],
        Dout[64], Dout[65], Dout[66], Dout[67], Dout[68], Dout[69], Dout[70], Dout[71], Dout[72], Dout[73], Dout[74], Dout[75], Dout[76], Dout[77], Dout[78], Dout[79],
        Dout[80], Dout[81], Dout[82], Dout[83], Dout[84], Dout[85], Dout[86], Dout[87], Dout[88], Dout[89], Dout[90], Dout[91], Dout[92], Dout[93], Dout[94], Dout[95],
        Dout[96], Dout[97], Dout[98], Dout[99], Dout[100], Dout[101], Dout[102], Dout[103], Dout[104], Dout[105], Dout[106], Dout[107], Dout[108], Dout[109], Dout[110], Dout[111],
        Dout[112], Dout[113], Dout[114], Dout[115], Dout[116], Dout[117], Dout[118], Dout[119], Dout[120], Dout[121], Dout[122], Dout[123], Dout[124], Dout[125], Dout[126], Dout[127],
        Din[0], Din[1], Din[2], Din[3], Din[4], Din[5], Din[6], Din[7], Din[8], Din[9], Din[10], Din[11], Din[12], Din[13], Din[14], Din[15],
        Din[16], Din[17], Din[18], Din[19], Din[20], Din[21], Din[22], Din[23], Din[24], Din[25], Din[26], Din[27], Din[28], Din[29], Din[30], Din[31],
        Din[32], Din[33], Din[34], Din[35], Din[36], Din[37], Din[38], Din[39], Din[40], Din[41], Din[42], Din[43], Din[44], Din[45], Din[46], Din[47],
        Din[48], Din[49], Din[50], Din[51], Din[52], Din[53], Din[54], Din[55], Din[56], Din[57], Din[58], Din[59], Din[60], Din[61], Din[62], Din[63],
        Din[64], Din[65], Din[66], Din[67], Din[68], Din[69], Din[70], Din[71], Din[72], Din[73], Din[74], Din[75], Din[76], Din[77], Din[78], Din[79],
        Din[80], Din[81], Din[82], Din[83], Din[84], Din[85], Din[86], Din[87], Din[88], Din[89], Din[90], Din[91], Din[92], Din[93], Din[94], Din[95],
        Din[96], Din[97], Din[98], Din[99], Din[100], Din[101], Din[102], Din[103], Din[104], Din[105], Din[106], Din[107], Din[108], Din[109], Din[110], Din[111],
        Din[112], Din[113], Din[114], Din[115], Din[116], Din[117], Din[118], Din[119], Din[120], Din[121], Din[122], Din[123], Din[124], Din[125], Din[126], Din[127],
        clk, WEB, OE, CS
    );

endmodule

module SRAM256x128_WRAP(
    input wire [7:0] A,
    output wire [127:0] Dout,
    input wire [127:0] Din,
    input wire clk,
    input wire WEB,
    input wire OE,
    input wire CS
);

    SRAM_256x128bit u_sram_256x128 (
        A[0], A[1], A[2], A[3], A[4], A[5], A[6], A[7],
        Dout[0], Dout[1], Dout[2], Dout[3], Dout[4], Dout[5], Dout[6], Dout[7], Dout[8], Dout[9], Dout[10], Dout[11], Dout[12], Dout[13], Dout[14], Dout[15],
        Dout[16], Dout[17], Dout[18], Dout[19], Dout[20], Dout[21], Dout[22], Dout[23], Dout[24], Dout[25], Dout[26], Dout[27], Dout[28], Dout[29], Dout[30], Dout[31],
        Dout[32], Dout[33], Dout[34], Dout[35], Dout[36], Dout[37], Dout[38], Dout[39], Dout[40], Dout[41], Dout[42], Dout[43], Dout[44], Dout[45], Dout[46], Dout[47],
        Dout[48], Dout[49], Dout[50], Dout[51], Dout[52], Dout[53], Dout[54], Dout[55], Dout[56], Dout[57], Dout[58], Dout[59], Dout[60], Dout[61], Dout[62], Dout[63],
        Dout[64], Dout[65], Dout[66], Dout[67], Dout[68], Dout[69], Dout[70], Dout[71], Dout[72], Dout[73], Dout[74], Dout[75], Dout[76], Dout[77], Dout[78], Dout[79],
        Dout[80], Dout[81], Dout[82], Dout[83], Dout[84], Dout[85], Dout[86], Dout[87], Dout[88], Dout[89], Dout[90], Dout[91], Dout[92], Dout[93], Dout[94], Dout[95],
        Dout[96], Dout[97], Dout[98], Dout[99], Dout[100], Dout[101], Dout[102], Dout[103], Dout[104], Dout[105], Dout[106], Dout[107], Dout[108], Dout[109], Dout[110], Dout[111],
        Dout[112], Dout[113], Dout[114], Dout[115], Dout[116], Dout[117], Dout[118], Dout[119], Dout[120], Dout[121], Dout[122], Dout[123], Dout[124], Dout[125], Dout[126], Dout[127],
        Din[0], Din[1], Din[2], Din[3], Din[4], Din[5], Din[6], Din[7], Din[8], Din[9], Din[10], Din[11], Din[12], Din[13], Din[14], Din[15],
        Din[16], Din[17], Din[18], Din[19], Din[20], Din[21], Din[22], Din[23], Din[24], Din[25], Din[26], Din[27], Din[28], Din[29], Din[30], Din[31],
        Din[32], Din[33], Din[34], Din[35], Din[36], Din[37], Din[38], Din[39], Din[40], Din[41], Din[42], Din[43], Din[44], Din[45], Din[46], Din[47],
        Din[48], Din[49], Din[50], Din[51], Din[52], Din[53], Din[54], Din[55], Din[56], Din[57], Din[58], Din[59], Din[60], Din[61], Din[62], Din[63],
        Din[64], Din[65], Din[66], Din[67], Din[68], Din[69], Din[70], Din[71], Din[72], Din[73], Din[74], Din[75], Din[76], Din[77], Din[78], Din[79],
        Din[80], Din[81], Din[82], Din[83], Din[84], Din[85], Din[86], Din[87], Din[88], Din[89], Din[90], Din[91], Din[92], Din[93], Din[94], Din[95],
        Din[96], Din[97], Din[98], Din[99], Din[100], Din[101], Din[102], Din[103], Din[104], Din[105], Din[106], Din[107], Din[108], Din[109], Din[110], Din[111],
        Din[112], Din[113], Din[114], Din[115], Din[116], Din[117], Din[118], Din[119], Din[120], Din[121], Din[122], Din[123], Din[124], Din[125], Din[126], Din[127],
        clk, WEB, OE, CS
    );

endmodule

// the mac for a conv3x3, the input multiplexing should be handled by higher lvl modules
// Postprocessing:
// 1. (conv_output >>> 6) + 128
// 2. ReLU + clip to [0, 255]
module Conv3x3MAC(
    clk,
    rst_n,
    i_data_valid,
    i_data_word, // concat 8 bit unsigned x 9 together
    i_weight_valid,
    i_weight, // 4 bit signed x 9
    output_valid,
    output_data
);
input clk, rst_n, i_data_valid, i_weight_valid;
input [71:0] i_data_word;
input signed [35:0] i_weight;
output output_valid;
output reg [7:0] output_data;

wire signed [11:0] mult_result[0:8]; // 8 bit x 4 bit = 12 bit
reg signed [11:0] mult_result_reg[0:8]; // multiplier output stored at the pipeline reg
reg signed [14:0] sum_result; // 9 products, max bit width = 12 bit + log2(9) = 15 bit

parameter STAGE_CNT = 5;
reg [STAGE_CNT-1:0] valid_chain;
assign output_valid = valid_chain[STAGE_CNT-1];

// regs storing weights and the 9 input data
reg signed [3:0] weight_reg[0:8];
// regs storing the intermediate addition results in the adder tree, used for pipelining
// adder tree structure:
// level 1: 4 sums of 2 products (sum0 = prod0 + prod1, sum1 = prod2 + prod3, sum2 = prod4 + prod5, sum3 = prod6 + prod7, prod8 is directly passed to the next level)
// level 2: 2 sums of 4 products (sum4 = sum0 + sum1, sum5 = sum2 + sum3)
// level 3: sum6 = sum4 + sum5 + prod8
reg signed [12:0] sum_level1[0:3]; // 4 sums of 2 products, 12 bit + 12 bit = 13 bit
reg signed [13:0] sum_level2[0:1]; // 2 sums of 4 products, 13 bit + 13 bit = 14 bit
reg signed [15:0] sum_level3; // 9 products, still needs 16 bit to avoid overflow

// post processing vars
wire signed [15:0] shift_result;
wire [7:0] clip_result;

genvar i;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        valid_chain <= {STAGE_CNT{1'b0}};
    end else begin
        valid_chain <= {valid_chain[STAGE_CNT-2:0], i_data_valid};
    end
end

// Import weights when i_weight_valid is high, and store them in a reg for multiplication
// the weights are given all in once
generate
    for(i=0;i<9;i=i+1) begin
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) begin
                weight_reg[i] <= 0;
            end else if(i_weight_valid) begin
                weight_reg[i] <= i_weight[4*i +: 4];
            end
        end
    end
endgenerate

// perform multiplication, and pipeline the multiplier output
generate
    for(i=0;i<9;i=i+1) begin
        assign mult_result[i] = weight_reg[i] * i_data_word[8*i +: 8];

        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) begin
                mult_result_reg[i] <= 0;
            end else begin
                mult_result_reg[i] <= mult_result[i];
            end
        end
    end
endgenerate

// the adder tree that adds the 9 products together
generate
    for(i=0;i<4;i=i+1) begin
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) begin
                sum_level1[i] <= 0;
            end else begin
                sum_level1[i] <= mult_result_reg[2*i] + mult_result_reg[2*i+1];
            end
        end
    end
endgenerate

generate
    for(i=0;i<2;i=i+1) begin
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) begin
                sum_level2[i] <= 0;
            end else begin
                sum_level2[i] <= sum_level1[2*i] + sum_level1[2*i+1];
            end
        end
    end
endgenerate

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        sum_level3 <= 0;
    end else begin
        sum_level3 <= sum_level2[0] + sum_level2[1] + mult_result_reg[8];
    end
end

// post processing: right shift by 6 for normalization, and clip to [0, 255]
assign shift_result = sum_level3 >>> 6;
assign clip_result = (shift_result > 255) ? 255 : (shift_result < 0) ? 0 : shift_result;

// output the final result, and pipeline the output valid signal together with the data
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        output_data <= 0;
    end else begin
        output_data <= clip_result;
    end
end

endmodule

// the mac tree for linear transformation operations, perform conventional MatMul
// here we just implement the arithmetics, the input multiplexing should be handled by higher lvl modules
// used for Q, K, V projection
module LinearTransMAC(
    clk,
    rst_n,
    input_valid,
    a_row_word,
    b_row_word,
    output_valid,
    output_data
);

input clk, rst_n, input_valid;
input signed [127:0] a_row_word; // can be a word read from sram (8 bit signed x 16)
input signed [63:0] b_row_word; // a column in the weight matrix (4 bit signed x 16)
output output_valid;
output reg signed [7:0] output_data;

reg signed [7:0] mat_row_a[0:15];
reg signed [3:0] mat_row_b[0:15];
wire signed [11:0] mult_result[0:15]; // 8 bit x 4 bit = 12 bit
reg signed [11:0] mult_result_reg[0:15]; // multiplier output stored at the pipeline reg

// 16 product accumulation tree
reg signed [12:0] sum_level1[0:7]; // 8 sums of 2 products, 12 bit + 12 bit = 13 bit
reg signed [13:0] sum_level2[0:3]; // 4 sums of 4 products, 13 bit + 13 bit = 14 bit
reg signed [14:0] sum_level3[0:1]; // 2 sums of 8 products, 14 bit + 14 bit = 15 bit
wire signed [15:0] adder_out;
wire signed [12:0] shift_out;// (x >>> 4)
wire signed [7:0] clip_out;

// valid chain
parameter STAGE_CNT = 6;
reg [STAGE_CNT-1:0] valid_chain; // a chain of valid signals for pipelining, valid_chain[0] is the input valid, valid_chain[4] is the output valid
assign output_valid = valid_chain[STAGE_CNT-1];

genvar i;

generate
    for(i=0;i<16;i=i+1) begin
        always @(posedge clk or negedge rst_n) begin : mult_input_logic
            if(!rst_n) begin
                mat_row_a[i] <= 0;
                mat_row_b[i] <= 0;
            end else begin
                mat_row_a[i] <= a_row_word[8*i +: 8] & {8{input_valid}};
                mat_row_b[i] <= b_row_word[4*i +: 4] & {4{input_valid}};
            end
        end
    end
endgenerate

// 16 multiplications
generate
    for(i=0;i<16;i=i+1) begin : mult_logic
        assign mult_result[i] = mat_row_a[i] * mat_row_b[i];

        always @(posedge clk or negedge rst_n) begin : pipeline_mult_output
            if(!rst_n) begin
                    mult_result_reg[i] <= 0;
            end else begin
                    mult_result_reg[i] <= mult_result[i];
            end
        end
    end
endgenerate

// accumulate all 16 products, and pipeline the adder trees
generate
    for(i=0;i<8;i=i+1) begin : adder_tree_level1
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) begin
                sum_level1[i] <= 0;
            end else begin
                sum_level1[i] <= mult_result_reg[2*i] + mult_result_reg[2*i+1];
            end
        end
    end
endgenerate

generate
    for(i=0;i<4;i=i+1) begin : adder_tree_level2
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) begin
                sum_level2[i] <= 0;
            end else begin
                sum_level2[i] <= sum_level1[2*i] + sum_level1[2*i+1];
            end
        end
    end
endgenerate

generate
    for(i=0;i<2;i=i+1) begin : adder_tree_level3
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) begin
                sum_level3[i] <= 0;
            end else begin
                sum_level3[i] <= sum_level2[2*i] + sum_level2[2*i+1];
            end
        end
    end
endgenerate

// at the last adder stage, normalization and clipping are also performed to fit the output back to 8 bit
assign adder_out = sum_level3[0] + sum_level3[1];
assign shift_out = adder_out >>> 4; // right shift by 4 to normalize the output back to 8 bit, can be adjusted according to the actual value range of the output
assign clip_out = (shift_out > 127) ? 127 : (shift_out < -128) ? -128 : shift_out;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        valid_chain <= {STAGE_CNT{1'b0}};
    end else begin
        valid_chain <= {valid_chain[STAGE_CNT-2:0], input_valid};
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        output_data <= 0;
    end else begin
        output_data <= clip_out;
    end
end

endmodule


// module ConvBlock(
//     clk,
//     rst_n,
//     up_sample, // indicate if we are using this mod as an up-sampling conv, driven by the top module
//     input_valid,
//     iter_cnt,
//     // i_mode,
//     input_data,
//     i_weight,
//     us_weight_valid,
//     ds_weight_valid,
//     output_valid,
//     output_data
// );
// input       clk, rst_n, input_valid;
// // the weights are stored in sram, have to read them out before computing output
// // but at the first time ds_conv is running, we load the weight directly into this reg
// // and also send its weight to the sram at the same time
// reg signed [3:0] conv_weight [0:8];

// endmodule

module TFBlock(
    clk,
    rst_n,
    input_valid,
    iter_cnt,
    // i_mode,
    input_data,
    i_weight,
    i_weight_valid,
    output_valid,
    output_data
);

input       clk, rst_n, input_valid;
input       [7:0] input_data;
input       [2:0] iter_cnt;
// input       [1:0] i_mode;
input       [3:0] i_weight;
input i_weight_valid;
output  reg output_valid;
output reg  [7:0] output_data;

// temporarily assigned to 0 for simulation
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        output_valid <= 0;
        output_data <= 0;
    end else begin
        
    end
end


endmodule

module DM(
    clk,
    rst_n,
    i_valid,
    i_iter,
    i_mode,
    i_data,
    i_weight,
    o_valid,
    o_data
);

input       clk, rst_n, i_valid;
input       [7:0] i_data;
input       [2:0] i_iter;
input       [1:0] i_mode;
input       [3:0] i_weight;
output  o_valid;
output  [7:0] o_data;

// states
reg [2:0] state, nxt_state;
// have to seperate the actions of shared hardware to avoid conflicts
parameter LOAD_NEW_IMG = 3'd0; // a new input image is coming, load them into sram_img, set iter_counter = new i_iter when entered
parameter DS_CONV = 3'd1; // sram_img -> ds_conv -> sram_temp
parameter QKV_PROJ = 3'd2; // sram_temp -> linear_transform -> sram_q, sram_k, sram_v
parameter CALC_ATTN = 3'd3; // sram_q, sram_k, sram_v -> attn pipeline -> sram_temp
parameter US_CONV_UPDATE_IMG = 3'd4; // sram_temp -> us_conv -> interpolation -> read from sram_img and minus noise -> write back to sram_img
// these states are for weight input, only active at the start of a testcase
parameter LOAD_DS_CONV_WEIGHT = 3'd5;
parameter LOAD_PROJ_WEIGHT = 3'd6;
parameter LOAD_US_CONV_WEIGHT = 3'd7;

reg [2:0] iter_counter; // records the number of remaining diff iterations to perform
// telling iter_counter that the transformer block has completed operations, and it can decrement itself
// !!: tf_out_valid should only rise when iter_counter > 0, watch out when driving tf_out_valid in the transformer block modules
wire tf_out_valid; 

reg [1:0] interpolate_mode; // mode of interpolation
reg [11:0] main_counter; // records the number of inputs
reg weight_input_done;
reg img_input_done;

// Threshold wire driven by the current state
// 32 elements (0-31) for Proj/FFN, 18 elements (0-17) for Conv
wire [4:0] write_threshold;
assign write_threshold = (state == LOAD_PROJ_WEIGHT) ? 5'd31 : 5'd17;

// Unified SRAM IO
reg [5:0] weight_wr_addr;
wire web_weight, oe_weight, cs_weight;
wire [127:0] dout_weight_raw;
reg [127:0] din_weight;
reg [2:0] weight_sram_cmd;
// write counter and buffer for weight input
// buffer the 32 weights for proj/ffn weight, and 18 weights for conv weight, then write to sram in one cycle when the buffer is full
reg [4:0] weight_sram_write_cnt; // count the number of weights currently in the buffer
reg [127:0] weight_sram_write_buf; // buffer for the weights to be written into sram, for conv weight, only the lower 72 bit are used
assign {cs_weight, web_weight, oe_weight} = weight_sram_cmd;

// SRAM_IMG IO
reg [5:0] img_sram_wr_addr;
wire web_img, oe_img, cs_img;
reg [2:0] img_sram_cmd;
wire [511:0] dout_img_raw;
wire [511:0] din_img;
// store 64 i_image inputs before writing the entire row into sram
// TODO: might be able to share this buf for read and write, since the read and write operations are separated in time
reg [511:0] img_sram_write_buf;
reg [5:0] img_sram_write_cnt; // count the number of i_image inputs currently in the buffer
assign {cs_img, web_img, oe_img} = img_sram_cmd;
assign din_img = img_sram_write_buf;

//SRAM_TEMP IO
reg [7:0] temp_addr;
wire temp_web, temp_oe, temp_cs;
reg [127:0] temp_din;
wire [127:0] temp_dout;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= LOAD_DS_CONV_WEIGHT;
    end else begin
        state <= nxt_state;
    end
end

always @(*) begin : state_transition
    nxt_state = state;
    case (state)
        LOAD_DS_CONV_WEIGHT: begin
            if (i_valid && main_counter == 143)
                nxt_state = LOAD_PROJ_WEIGHT;
        end
        LOAD_PROJ_WEIGHT: begin
            if (i_valid && main_counter == 1167)
                nxt_state = LOAD_US_CONV_WEIGHT;
        end
        LOAD_US_CONV_WEIGHT: begin
            if (!i_valid /*&& main_counter == 1311*/)
                nxt_state = LOAD_NEW_IMG;
        end
        LOAD_NEW_IMG: begin
            if (img_input_done)begin
                nxt_state = DS_CONV;
            end
        end
        DS_CONV: begin
            // Defined by subsequent processing logic
        end
        QKV_PROJ: begin
            // Defined by subsequent processing logic
        end
        CALC_ATTN: begin
            // Defined by subsequent processing logic
        end
        US_CONV_UPDATE_IMG: begin
            // Logic to switch back to LOAD_NEW_IMG when iter_counter == 1
            // or switch to DS_CONV when iter_counter > 1
        end
        default: nxt_state = state;
    endcase
end

// SRAM_IMG instantiation, storing input image
SRAM_IMG sram_img (
    .A(img_sram_wr_addr),
    .Dout_bus(dout_img_raw),
    .Din_bus(din_img),
    .clk(clk),
    .WEB(web_img),
    .OE(oe_img),
    .CS(cs_img)
);

// TODO: SRAM_IMG control logic, including write data generation, address generation, and command generation
// write buf and counter logic for sram_img
integer i;
always @(posedge clk or negedge rst_n) begin : img_sram_write_buf_cnt_addr_ctrl
    if(!rst_n)begin
        img_sram_write_buf <= 0;
        img_sram_write_cnt <= 0;
    end else begin
        case(state)
        LOAD_NEW_IMG:begin
            
            for(i=0;i<64;i=i+1) begin
                if(i_valid) begin
                    if(i==0) img_sram_write_buf[8*i +: 8] <= i_data;
                    else img_sram_write_buf[8*i +: 8] <= img_sram_write_buf[8*(i-1) +: 8];
                end
            end
            img_sram_write_cnt <= i_valid ? img_sram_write_cnt + 1 : img_sram_write_cnt;
        end
        default:begin
            img_sram_write_buf <= 0;
            img_sram_write_cnt <= 0;
        end
        endcase
    end
end

always @(posedge clk or negedge rst_n) begin : img_sram_wr_addr_ctrl
    if(!rst_n)begin
        img_sram_wr_addr <= 0;
    end else begin
        case(state)
        LOAD_NEW_IMG:begin
            img_sram_wr_addr <= (img_sram_cmd == `WRITE) ? img_sram_wr_addr + 1 : img_sram_wr_addr;
        end
        default:begin
            img_sram_wr_addr <= 0;
        end
        endcase
    end
end

always @(posedge clk or negedge rst_n) begin : img_sram_cmd_ctrl
    if(!rst_n)begin
        img_sram_cmd <= `STANDBY;
    end else begin
        case(state)
        LOAD_NEW_IMG:begin
            img_sram_cmd <= (img_sram_write_cnt >= 63) ? `WRITE : `STANDBY;
        end
        default:begin
            img_sram_cmd <= `STANDBY;
        end
        endcase
    end
end

// Unified SRAM Instantiation, storing ds_conv, us_conv, q/k/v projection, ffn weights
SRAM64x128_WRAP sram_weight (
    .A(weight_wr_addr),
    .Dout(dout_weight_raw),
    .Din(din_weight),
    .clk(clk),
    .WEB(web_weight),
    .OE(oe_weight),
    .CS(cs_weight)
);

// Dynamic Shift Register & Counter Control
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        weight_sram_write_cnt <= 0;
        weight_sram_write_buf <= 0;
    end else if (i_valid && !weight_input_done) begin
        // Shift new data in from LSB
        weight_sram_write_buf <= {weight_sram_write_buf[123:0], i_weight};

        // Reset counter dynamically based on current weight type
        if (weight_sram_write_cnt == write_threshold) begin
            weight_sram_write_cnt <= 0;
        end else begin
            weight_sram_write_cnt <= weight_sram_write_cnt + 1;
        end
    end
end
// ds_conv weight: main_counter = 0~143
// q weight: main_counter = 144~399
// k weight: main_counter = 400~655
// v weight: main_counter = 656~911
// ffn weight: main_counter = 912~1167
// us_conv weight: main_counter = 1168~1311

// SRAM Command & Write Data Generation
// Command, Din, and Address updates
always @(*) begin : weight_sram__din_ctrl
    din_weight = weight_sram_write_buf;
end

always @(posedge clk or negedge rst_n) begin : weight_sram_cmd_ctrl
    if (!rst_n) begin
        // weight_wr_addr <= 0;
        weight_sram_cmd <= `STANDBY;
    end else if (weight_sram_write_cnt == write_threshold 
        && (state == LOAD_DS_CONV_WEIGHT || state == LOAD_US_CONV_WEIGHT || state == LOAD_PROJ_WEIGHT)) begin
        // weight_wr_addr <= weight_wr_addr + 1;
        weight_sram_cmd <= `WRITE;
    end else begin // TODO: we need to reset weight_wr_addr for future reads
        weight_sram_cmd <= `STANDBY;
        // weight_wr_addr <= weight_wr_addr;
    end
end

always @(posedge clk or negedge rst_n) begin : weight_sram_wr_addr_ctrl
    if (!rst_n) begin
        weight_wr_addr <= 0;
        weight_sram_cmd <= `STANDBY;
    end else begin
        case(state)
        LOAD_DS_CONV_WEIGHT, LOAD_US_CONV_WEIGHT, LOAD_PROJ_WEIGHT:begin
            weight_wr_addr <= (weight_sram_cmd == `WRITE) ? weight_wr_addr+1 : weight_wr_addr;
        end
        default:begin
            weight_wr_addr <= 0;
        end
        endcase 
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        main_counter <= 0;
    end else begin
        if(i_valid) begin
            main_counter <= main_counter + 1;
        end else if(weight_input_done) begin // now we are btw the last weight input and the first image input
            main_counter <= main_counter;
        end else begin // now we are at the end of a input image stream, another one may come later
            main_counter <= 0;
        end
    end
end

always @(posedge clk or negedge rst_n) begin : img_input_done_logic
    if(!rst_n) begin
        img_input_done <= 0;
    end else begin
        // reset img_input_done when transitioning to LOAD_NEW_IMG from other states
        if(state != nxt_state && nxt_state == LOAD_NEW_IMG) img_input_done <= 0;
        else begin
            img_input_done <= img_input_done || (state == LOAD_NEW_IMG && main_counter == 4095);
        end 
    end
end

always @(posedge clk or negedge rst_n) begin : weight_input_done_logic
    if(!rst_n) begin
        weight_input_done <= 0;
        interpolate_mode <= 0;
        iter_counter <= 0;
    end else begin
        weight_input_done <= (weight_input_done || (!i_valid && main_counter >= 1311));

        interpolate_mode <= (main_counter == 0 && i_valid && weight_input_done) ? i_mode : interpolate_mode;

        if(main_counter == 0 && i_valid && weight_input_done) begin
            iter_counter <= i_iter;
        end else begin
            iter_counter <= (tf_out_valid && iter_counter > 0) ? iter_counter - 1 : iter_counter;
        end
    end
end

// SRAM_TEMP instantiation, used for storing intermediate data
SRAM256x128_WRAP sram_temp (
    .A(temp_addr),
    .Dout(temp_dout),
    .Din(temp_din),
    .clk(clk),
    .WEB(temp_web),
    .OE(temp_oe),
    .CS(temp_cs)
);

// TODO: SRAM_TEMP control logic, including write data generation, address generation, and command generation
// may need to have write & read valid signals to interact with the Conv and LinearTransform modules

TFBlock tf_blk(
    .clk(clk),
    .rst_n(rst_n),
    .input_valid(i_valid && weight_input_done), // start feeding data after weights are inputted
    .iter_cnt(iter_counter),
    .input_data(i_data),
    .i_weight(i_weight),
    .i_weight_valid(/*i_valid && !weight_input_done*/), // only feed weight when we are still in the weight input phase
    .output_valid(tf_out_valid),
    .output_data(o_data)
);
// assigned temporarily for simulation, will be replaced by the output valid signal from the transformer block
assign o_valid = tf_out_valid;

endmodule
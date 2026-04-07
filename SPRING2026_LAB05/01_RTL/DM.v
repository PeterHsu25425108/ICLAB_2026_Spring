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

module SRAM_CTRL #(parameter WORD_LEN=128, ADDR_LEN=8)(
    input clk,
    input rst_n,
    input [ADDR_LEN-1:0] addr,
    input [WORD_LEN-1:0] data_in,
    // sent by master
    input read_req,
    input write_req,
    // input sent from sram
    input [WORD_LEN-1:0] sram_DO,
    
    // send by this mod to master
    output reg read_valid,
    output reg write_valid,
    output reg [WORD_LEN-1:0] data_out,
    // sent to sram
    output [ADDR_LEN-1:0] sram_A,
    output [2:0] sram_cmd,
    output reg [WORD_LEN-1:0] sram_DI
);

reg read_buf_capture, nxt_read_buf_capture;
reg [ADDR_LEN-1:0] addr_reg;
reg [2:0] cmd_reg;

// internal logic
always @(posedge clk or negedge rst_n) begin : valid_sig_ctrl
    if(!rst_n) begin
        nxt_read_buf_capture <= 0;
        read_buf_capture <= 0;
        read_valid <= 0;
        write_valid <= 0;
    end else begin

        read_valid <= read_buf_capture;
        read_buf_capture <= nxt_read_buf_capture;
        nxt_read_buf_capture <= read_req;
        // Write acknowledgement aligns with registered SRAM cmd/addr/data outputs.
        write_valid <= write_req;
    end
end

always @(posedge clk or negedge rst_n) begin : data_out_ctrl
    if(!rst_n) begin
        data_out <= 0;
    end else begin
        data_out <= read_buf_capture ? sram_DO : data_out;
    end
end

// SRAM interface - register addr and cmd to sync with registered sram_DI
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        addr_reg <= 0;
        cmd_reg <= `STANDBY;
    end else begin
        addr_reg <= addr;
        cmd_reg <= read_req ? `READ : (write_req ? `WRITE : `STANDBY);
    end
end

assign sram_A = addr_reg;
assign sram_cmd = cmd_reg;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        sram_DI <= 0;
    end else begin
        sram_DI <= write_req ? data_in : sram_DI;
    end
end

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
    // i_weight_valid,
    weight, // 4 bit signed x 9
    output_valid,
    output_data
);
input clk, rst_n, i_data_valid;
input [71:0] i_data_word;
input signed [35:0] weight;
output output_valid;
// output reg [7:0] output_data;
output [15:0] output_data;

wire signed [11:0] mult_result[0:8]; // 8 bit x 4 bit = 12 bit
reg signed [11:0] mult_result_reg[0:8]; // multiplier output stored at the pipeline reg
reg signed [14:0] sum_result; // 9 products, max bit width = 12 bit + log2(9) = 15 bit

parameter STAGE_CNT = 4;
reg [STAGE_CNT-1:0] valid_chain;
assign output_valid = valid_chain[STAGE_CNT-1];

// regs storing the intermediate addition results in the adder tree, used for pipelining
// adder tree structure:
// level 1: 4 sums of 2 products (sum0 = prod0 + prod1, sum1 = prod2 + prod3, sum2 = prod4 + prod5, sum3 = prod6 + prod7, prod8 is directly passed to the next level)
// level 2: 2 sums of 4 products (sum4 = sum0 + sum1, sum5 = sum2 + sum3)
// level 3: sum6 = sum4 + sum5 + prod8
reg signed [12:0] sum_level1[0:3]; // 4 sums of 2 products, 12 bit + 12 bit = 13 bit
reg signed [13:0] sum_level2[0:1]; // 2 sums of 4 products, 13 bit + 13 bit = 14 bit
reg signed [15:0] sum_level3; // 9 products, still needs 16 bit to avoid overflow

// post processing vars
// wire signed [15:0] shift_result;
// wire [7:0] clip_result;

genvar i;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        valid_chain <= {STAGE_CNT{1'b0}};
    end else begin
        valid_chain <= {valid_chain[STAGE_CNT-2:0], i_data_valid};
    end
end

// perform multiplication, and pipeline the multiplier output
generate
    for(i=0;i<9;i=i+1) begin
        assign mult_result[i] = weight[4*i +: 4] * i_data_word[8*i +: 8];

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

assign output_data = sum_level3;

// post processing: right shift by 6 for normalization, and clip to [0, 255]
// assign shift_result = sum_level3 >>> 6;
// assign clip_result = (shift_result > 255) ? 255 : (shift_result < 0) ? 0 : shift_result;

// // output the final result, and pipeline the output valid signal together with the data
// always @(posedge clk or negedge rst_n) begin
//     if(!rst_n) begin
//         output_data <= 0;
//     end else begin
//         output_data <= clip_result;
//     end
// end

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


module ConvBlock(
    input clk,
    input rst_n,
    input is_us_conv, // indocate whether we are doing us_conv, used for weight_read_addr
    input en, // wehn set low, block the MACs' input dataflow and does not perform any sram w/r
    
    // SRAM_IMG Interface
    output reg [5:0] img_read_addr,
    output reg img_read_req,
    input [511:0] img_data_in,  // A full 64-pixel row
    input img_read_valid,

    // SRAM_WEIGHT Interface
    output reg [5:0] weight_read_addr,
    output  weight_read_req,
    input [127:0] weight_data_in, // directly connects to weight_sram_read_buf
    input weight_read_valid,
    
    // SRAM_TEMP Interface
    // read data returned from sram_temp read buffer in DM
    input [127:0] temp_data_in,
    output reg [7:0] temp_read_addr,
    output reg temp_read_req,
    output reg [7:0] temp_write_addr,
    output reg temp_write_req,
    input temp_write_valid,
    input temp_read_valid,
    
    // Top-level Control
    output reg ds_conv_done, // Tells FSM to switch to QKV_PROJ, high after all the 16 out chs are computed & stored into sram_temp
    output reg us_out_valid, //tell the interpolation module to start reading the output
    // output data port
    // DS_CONV: Full 16-channel feature vector, connects to temp_sram_write_buf
    // US_CONV: concat 1 pixel output for 16 out chs, will be sent to the interpolation module
    output reg [127:0] ds_out_data,
    output reg [7:0] us_out_data
);

// the weights are stored in sram, have to read them out before computing output
// 1 word is read from sram_weight, which contains the weight for 16 3x3 kernels
reg signed [35:0] conv_weight [0:15];
reg weight_allset; // high when all weights we need have been read into conv_weight
wire [5:0] weight_read_addr_offset; 
assign weight_read_addr_offset = is_us_conv ? 0 : 40;
wire [35:0] weight_input_evench, weight_input_oddch;
assign {weight_input_evench, weight_input_oddch} = weight_data_in[71:0]; 

// indicate if the read value has been returned, they control whether to 
// accept new values into the pipeline
// reg img_r_valid, temp_sram_read_valid;
// reg nxt_img_r_valid, nxt_temp_sram_read_valid;
// count how many rounds or weight read have we done (max 8)
reg [2:0] weight_read_cnt;

// each read returns 64 8bit pixels, we process them one by one
reg [511:0] img_row_pixel_buf;
// count how many rows of img have we read (max 64)
reg [5:0] img_read_cnt;
// count how many pixels in img_row_pixel_buf we have sent to the pipeline
// stride-4 shift on 64 pixels -> 16 shifts in total
reg [3:0] img_shift_cnt;
reg img_pending; // has shifted all pixels in img_row_pixel_buf, still waiting for img_read_valid to be high to load the next row

// shift regs for conv
// up sampling: stride = 1
// 16*2+3 = 35, ach with 128bite
// {ch15, ch14, ..., ch0}, each ch data is 8bit, total 128 bit for each ch data to allow parallel access to 16 pixels in the same channel
reg [127:0] us_conv_sr [0:34];
reg [17:0] us_center_valid;
// the row & col counter for us_conv_sr, used to determine zero padding
reg [3:0] us_row_cnt, us_col_cnt;// 16x16 
reg [127:0] us_3x3_window[0:15][0:8]; // to store the 3x3 window of the current pixel for all 16 channels, used as the input of the MACs

// down sampling: stride = 4
// 64*2+2 = 130, each with 8 bit
reg [7:0] ds_conv_sr[0:131];
reg [65:0] ds_center_valid;
// the row & col counter for ds_conv_sr, used to determine zero padding
reg [5:0] ds_row_cnt, ds_col_cnt; // 64x64
reg [7:0] ds_3x3_window[0:8]; // to store the 3x3 window of the current pixel, used as the input of the MACs

// final IOs of MACs
reg [71:0] conv_mac_i_data[0:15];
wire [15:0] conv_mac_o_data[0:15];
wire [15:0] conv_mac_o_valid;
// post-processing outputs for ds_conv
wire signed [10:0] shift_o_data[0:15];
wire [7:0] clip_o_data[0:15];
// post-processing outputs for us_conv
reg signed [19:0] sum_over_all_chs;
wire signed [14:0] shifted_all_ch_sum;
wire [7:0] clip_all_ch_sum;
// input valid signal for the macs
reg conv_mac_i_valid;

assign weight_read_req = en && (weight_read_cnt <= 7) && !weight_allset;
// SRAM_WEIGHT interface control
always @(posedge clk or negedge rst_n) begin : weight_read_ctrl
    if(!rst_n)begin
        weight_read_addr <= 0;
        // weight_read_req <= 0;
        weight_allset <= 0;
        weight_read_cnt <= 0;
        for(integer i=0;i<16;i=i+1)begin
            conv_weight[i] <= 0;
        end
    end else begin
        if(!en)begin
            weight_read_addr <= weight_read_addr_offset;
            // weight_read_req <= 0;
            weight_allset <= 0;
            weight_read_cnt <= 0;
            for(integer i=0;i<16;i=i+1)begin
                conv_weight[i] <= 0;
            end
        end else begin
            // weight_read_req <= (weight_read_cnt != 7) && !weight_allset; // keep requesting until all weights are read
            weight_read_addr <= weight_read_req ?  weight_read_addr+1 :  weight_read_addr; // increment the read address when we are requesting, so that the next value can be returned in the next cycle
            weight_read_cnt <= weight_read_cnt + weight_read_req; // increment the count when the read value is returned
            weight_allset <= (weight_read_cnt == 7) ? 1 : weight_allset; // we need to read 8 rows of weights to get the full 16 3x3 kernels for all output channels
            if(weight_read_valid) begin
                // the 3x3 kernel weight of 2 output channels are stored in 1 row of sram, and each weight is 4 bit signed
                // each ch's kernel weights are 72bit
                // use shifting to store the weights
                conv_weight[14] <= weight_input_evench[35:0];
                conv_weight[15] <= weight_input_oddch[35:0];
                for(integer i=0;i<14;i=i+1)begin
                    conv_weight[i] <= conv_weight[i+2];
                end
            end else begin
                for(integer i=0;i<16;i=i+1)begin
                    conv_weight[i] <= conv_weight[i];
                end
            end
        end
    end
end

// SRAM_IMG interface control (do not start reading before weight_allset == 1)
always @(posedge clk or negedge rst_n) begin : img_read_ctrl
    if(!rst_n)begin
        img_read_addr <= 0;
        img_read_req <= 0;
        img_read_cnt <= 0;
        img_pending <= 0;
        img_row_pixel_buf <= 0;
    end else begin
        if(!en || !weight_allset)begin
            img_read_addr <= 0;
            img_read_req <= 0;
            img_read_cnt <= 0;
            img_pending <= 0;
            img_row_pixel_buf <= 0;
        end else begin
            
            // we can start reading the image data once all the weights are read, and the MACs are ready to compute
            img_read_req <= (img_read_addr == 63 && img_read_valid) ? 0 : (img_shift_cnt==15); // stop requesting when we have read all the rows we need, and the last read value is returned
            img_read_addr <= img_read_valid ? img_read_addr + 1 : img_read_addr; // increment the read address when the read value is returned, so that the next value can be returned in the next cycle
            if(img_pending)begin
                img_pending <= !img_read_valid;
            end else begin
                img_pending <= (img_shift_cnt==15);
            end

            img_read_cnt <= img_read_valid ? img_read_cnt + 1 : img_read_cnt; // increment the row count when the read value is returned
             // update the pixel buffer with the new row of pixels when the read value is returned
             if(img_read_valid) begin
                img_row_pixel_buf <= img_data_in;
             end else begin
                // shift for 4 steps if img_pending == 0
                img_row_pixel_buf <= !img_pending ? {img_row_pixel_buf[479:0], {4{8'b0}}} : img_row_pixel_buf;
             end
        end
    end
end

// SRAM_TEMP interface control (do not start writing before weight_allset == 1)
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        temp_read_addr <= 0;
        temp_read_req <= 0;
        temp_write_addr <= 0;
        temp_write_req <= 0;
    end else begin
        if(!en || !weight_allset)begin
            temp_read_addr <= 0;
            temp_read_req <= 0;
            temp_write_addr <= 0;
            temp_write_req <= 0;
        end else if(is_us_conv) begin // read from sram_temp
            temp_read_req <= (temp_read_addr == 8'd255 && temp_read_valid) ? 0 : 1;
            temp_read_addr <= temp_read_valid ? temp_read_addr + 1 : temp_read_addr;
            temp_write_req <= 0;
            temp_write_addr <= temp_write_addr;
        end else begin // write to sram_temp, when the conv output is ready (conv_mac_o_valid), we can start writing to sram_temp, and each write corresponds to 1 pixel of the output feature map, so we can increment the write address every time we write
            temp_read_req <= 0;
            temp_read_addr <= temp_read_addr;
            temp_write_req <= &conv_mac_o_valid;
            temp_write_addr <= temp_write_req ? temp_write_addr + 1 : temp_write_addr;
        end
    end
end

// down sampling shift reg control logic (stride = 4)
// read the first 4 elements in img_row_pixel_buf into ds_conv_sr
// and img_row_pixel_buf will shift left 4 elements so the next 4 elements will be moved to the left end
// and img_shift_cnt will be incremented by 4, when img_shift_cnt == 15, that means we will be sending the last 4 
// at the nxt clk edge, so we have to input another 64 from the sram input
always @(posedge clk or negedge rst_n) begin : img_row_pixel_buf_shift_logic
    if(!rst_n) begin
        ds_center_valid <= 0;
        img_shift_cnt <= 0;
        for(integer i=0;i<131;i=i+1)begin
            ds_conv_sr[i] <= 0;
        end
    end else begin
        if(!en)begin
            ds_center_valid <= 0;
            img_shift_cnt <= 0;
            for(integer i=0;i<131;i=i+1)begin
                ds_conv_sr[i] <= 0;
            end
        end else begin
            // accept inputs from sram_img
            // shift the shift reg every cycle, and update the center valid signal accordingly
            if(!is_us_conv)begin
                img_shift_cnt <= img_read_valid ? 0 : img_shift_cnt+1;
                if(!img_pending)begin
                    ds_conv_sr[3] <= img_row_pixel_buf[511:504];
                    ds_conv_sr[2] <= img_row_pixel_buf[503:496];
                    ds_conv_sr[1] <= img_row_pixel_buf[495:488];
                    ds_conv_sr[0] <= img_row_pixel_buf[487:480];
                    for(integer i=4;i<132;i=i+1)begin
                        ds_conv_sr[i] <= ds_conv_sr[i-4];
                    end
                end
            end
        end
    end
end

// up sampling shift reg control logic (stride = 1)
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        us_center_valid <= 0;
        img_shift_cnt <= 0;
        for(integer i=0;i<35;i=i+1)begin
            us_conv_sr[i] <= 0;
        end
    end else begin
        if(!en)begin
            us_center_valid <= 0;
            img_shift_cnt <= 0;
            for(integer i=0;i<35;i=i+1)begin
                us_conv_sr[i] <= 0;
            end
        end else begin
            // accept inputs from sram_temp
            
           
        end
    end
end
// MAC input selection
genvar i, j;

always @(*) begin : mac_input_valid_selection
    if(!en)begin
        conv_mac_i_valid = 0;
    end else if(is_us_conv)begin
        conv_mac_i_valid = us_center_valid;
    end else begin
        // TODO: make sure the stride-4 input can really be available
        //  every cycle after the first input reaches ds center
        conv_mac_i_valid = ds_center_valid;
    end
end

// TODO: zero padding logic using the row & col counters
wire us_top_bound, us_bot_bound, us_left_bound, us_right_bound;
wire ds_top_bound, ds_bot_bound, ds_left_bound, ds_right_bound;
assign us_top_bound = (us_row_cnt == 0);
assign us_bot_bound = (us_row_cnt == 15);
assign us_left_bound = (us_col_cnt == 0);
assign us_right_bound = (us_col_cnt == 15);
assign ds_top_bound = (ds_row_cnt == 0);
assign ds_bot_bound = (ds_row_cnt == 63);
assign ds_left_bound = (ds_col_cnt == 0);
assign ds_right_bound = (ds_col_cnt == 63);
generate
for(i=0;i<16;i=i+1)begin
    always @(*) begin : us_conv_zero_padding_logic
        us_3x3_window[i][0] = (us_top_bound || us_left_bound) ? 0 : us_conv_sr[i][127:120]; // top-left
        us_3x3_window[i][1] = (us_top_bound) ? 0 : us_conv_sr[i][119:112]; // top-center
        us_3x3_window[i][2] = (us_top_bound || us_right_bound) ? 0 : us_conv_sr[i][111:104]; // top-right
        us_3x3_window[i][3] = (us_left_bound) ? 0 : us_conv_sr[i][103:96]; // mid-left
        us_3x3_window[i][4] = us_conv_sr[i][95:88]; // mid-center
        us_3x3_window[i][5] = (us_right_bound) ? 0 : us_conv_sr[i][87:80]; // mid-right
        us_3x3_window[i][6] = (us_bot_bound || us_left_bound) ? 0 : us_conv_sr[i][79:72]; // bot-left
        us_3x3_window[i][7] = (us_bot_bound) ? 0 : us_conv_sr[i][71:64]; // bot-center
        us_3x3_window[i][8] = (us_bot_bound || us_right_bound) ? 0 : us_conv_sr[i][63:56]; // bot-right
    end
end

// TODO: zero padding logic for ds_conv using ds_row_cnt and ds_col_cnt
always @(*) begin
    ds_3x3_window[0] = (ds_top_bound || ds_left_bound) ? 0 : ds_conv_sr[0]; // top-left
    ds_3x3_window[1] = (ds_top_bound) ? 0 : ds_conv_sr[1]; // top-center
    ds_3x3_window[2] = (ds_top_bound || ds_right_bound) ? 0 : ds_conv_sr[2]; // top-right
    ds_3x3_window[3] = (ds_left_bound) ? 0 : ds_conv_sr[16]; // mid-left
    ds_3x3_window[4] = ds_conv_sr[17]; // mid-center
    ds_3x3_window[5] = (ds_right_bound) ? 0 : ds_conv_sr[18]; // mid-right
    ds_3x3_window[6] = (ds_bot_bound || ds_left_bound) ? 0 : ds_conv_sr[32]; // bot-left
    ds_3x3_window[7] = (ds_bot_bound) ? 0 : ds_conv_sr[33]; // bot-center
    ds_3x3_window[8] = (ds_bot_bound || ds_right_bound) ? 0 : ds_conv_sr[34]; // bot-right
end

endgenerate




generate
    for(i=0;i<15;i=i+1)begin
        for(j=0;j<9;j=j+1)begin
        always @(*) begin : mac_input_data_selection
            if(!en)begin
                conv_mac_i_data[i][8*j +: 8] = 0;
            end else if(is_us_conv)begin
                conv_mac_i_data[i][8*j +: 8] = us_3x3_window[i][j];
            end else begin
                conv_mac_i_data[i][8*j +: 8] = ds_3x3_window[j];
            end

        end
        end
    end
endgenerate

// MACs
generate
    for(i=0;i<16;i=i+1) begin : conv_mac_gen
        Conv3x3MAC conv_mac_inst (
            .clk(clk),
            .rst_n(rst_n),
            .i_data_valid(conv_mac_i_valid),
            .i_data_word(conv_mac_i_data[i]),
            .weight(conv_weight[i]),
            .output_valid(conv_mac_o_valid[i]),
            .output_data(conv_mac_o_data[i])
        );

    assign shift_o_data[i] = 128 + conv_mac_o_data[i] >>> 6;
    assign clip_o_data[i] = (shift_o_data[i] > 255) ? 255 : (shift_o_data[i] < 0) ? 0 : shift_o_data[i];
    end
endgenerate

integer idx;
always @(*) begin : sum_over_all_chs_accumulation
    sum_over_all_chs = 0;
    for(idx=0;idx<16;idx=idx+1)begin
        sum_over_all_chs = sum_over_all_chs + conv_mac_o_data[idx];
    end
end
assign shifted_all_ch_sum = sum_over_all_chs >>> 6 + 128;
assign clip_all_ch_sum = (shifted_all_ch_sum > 255) ? 255 : (shifted_all_ch_sum < 0) ? 0 : shifted_all_ch_sum;

// perform addition for us_conv, and for ds_conv just concat the MAC outputs together, and write to sram_temp 
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        ds_conv_done <= 0;
        us_out_valid <= 0;
        ds_out_data <= 0;
        us_out_data <= 0;
    end else begin
        if(is_us_conv) begin
            if(&conv_mac_o_valid) begin // when all MAC outputs are valid
                // add  the 16 MAC outputs together
                // TODO: the post processing logic for us_conv should be performed on the final addition result
                us_out_data <= clip_all_ch_sum;
                us_out_valid <= 1;
                ds_conv_done <= 0;
                ds_out_data <= 0;
            end else begin
                us_out_valid <= 0;
                ds_conv_done <= 0;
                ds_out_data <= 0;
                us_out_data <= 0;
            end
        end else begin
            if(&conv_mac_o_valid) begin // when all MAC outputs are valid
                // when we are writing the last pixel (255th) of the output feature map, we can signal the end of ds_conv here, 
                // since the FSM can start the next stage as soon as the last pixel is written into sram_temp
                if(temp_write_addr==255 && temp_write_valid)begin
                    ds_conv_done <= 1; // signal the end of ds_conv
                end
                
                ds_out_data <= {clip_o_data[15], clip_o_data[14], clip_o_data[13], clip_o_data[12],
                            clip_o_data[11], clip_o_data[10], clip_o_data[9], clip_o_data[8],
                            clip_o_data[7], clip_o_data[6], clip_o_data[5], clip_o_data[4],
                            clip_o_data[3], clip_o_data[2], clip_o_data[1], clip_o_data[0]};
                us_out_valid <= 0;
                us_out_data <= 0;
            end else begin
                ds_conv_done <= 0;
                ds_out_data <= 0;
                us_out_data <= 0;
            end
        end
    end
end

endmodule

// Weight Input Control submodule
// Handles accumulation of weight inputs from primary input and write control to SRAM_WEIGHT via SRAM_CTRL
module WeightInputCtrl(
    input clk,
    input rst_n,
    input [2:0] state,
    input i_valid,
    input [3:0] i_weight,
    input weight_input_done,
    input [4:0] write_threshold,
    output reg [127:0] weight_sram_write_buf,
    output reg [4:0] weight_sram_write_cnt,
    output reg [2:0] load_weight_cmd,
    output reg [5:0] load_weight_addr
);

// state definitions (must match parent module)
parameter LOAD_NEW_IMG = 3'd0;
parameter DS_CONV = 3'd1;
parameter QKV_PROJ = 3'd2;
parameter CALC_ATTN = 3'd3;
parameter US_CONV_UPDATE_IMG = 3'd4;
parameter LOAD_DS_CONV_WEIGHT = 3'd5;
parameter LOAD_PROJ_WEIGHT = 3'd6;
parameter LOAD_US_CONV_WEIGHT = 3'd7;

// Accumulate weights and track count
always @(posedge clk or negedge rst_n) begin : weight_buf_ctrl
    if (!rst_n) begin
        weight_sram_write_cnt <= 0;
        weight_sram_write_buf <= 0;
    end else begin
        case (state)
        LOAD_DS_CONV_WEIGHT,
        LOAD_PROJ_WEIGHT,
        LOAD_US_CONV_WEIGHT: begin
            if (i_valid && !weight_input_done) begin
                // Shift in new weight and apply mask based on state
                weight_sram_write_buf <= {weight_sram_write_buf[123:0], i_weight} & 
                                         (state == LOAD_PROJ_WEIGHT ? {128{1'b1}} : {{56{1'b0}},{72{1'b1}}});
                
                if (weight_sram_write_cnt == write_threshold) begin
                    weight_sram_write_cnt <= 0;
                end else begin
                    weight_sram_write_cnt <= weight_sram_write_cnt + 1;
                end
            end
        end
        default: begin
            weight_sram_write_buf <= weight_sram_write_buf;
            weight_sram_write_cnt <= 0;
        end
        endcase
    end
end

// Generate write command when buffer is full
always @(posedge clk or negedge rst_n) begin : load_cmd_ctrl
    if (!rst_n) begin
        load_weight_cmd <= `STANDBY;
    end else if (weight_sram_write_cnt == write_threshold 
        && (state == LOAD_DS_CONV_WEIGHT || state == LOAD_US_CONV_WEIGHT || state == LOAD_PROJ_WEIGHT)) begin
        load_weight_cmd <= `WRITE;
    end else begin 
        load_weight_cmd <= `STANDBY;
    end
end

// Manage write address
always @(posedge clk or negedge rst_n) begin : load_addr_ctrl
    if (!rst_n) begin
        load_weight_addr <= 0;
    end else begin
        case(state)
        LOAD_DS_CONV_WEIGHT, LOAD_US_CONV_WEIGHT, LOAD_PROJ_WEIGHT: begin
            load_weight_addr <= (load_weight_cmd == `WRITE) ? load_weight_addr + 1 : load_weight_addr;
        end
        default: begin
            load_weight_addr <= 0;
        end
        endcase
    end
end

endmodule

// Image Input Control submodule
// Handles accumulation of primary image inputs and write control to SRAM_IMG via SRAM_CTRL
module ImgInputCtrl(
    input clk,
    input rst_n,
    input [2:0] state,
    input i_valid,
    input [7:0] i_data,
    input img_input_done,
    output reg [511:0] img_sram_write_buf,
    output reg [5:0] img_sram_write_cnt,
    output reg [2:0] load_img_cmd,
    output reg [5:0] load_img_addr
);

// state definitions (must match parent module)
parameter LOAD_NEW_IMG = 3'd0;
parameter DS_CONV = 3'd1;
parameter QKV_PROJ = 3'd2;
parameter CALC_ATTN = 3'd3;
parameter US_CONV_UPDATE_IMG = 3'd4;
parameter LOAD_DS_CONV_WEIGHT = 3'd5;
parameter LOAD_PROJ_WEIGHT = 3'd6;
parameter LOAD_US_CONV_WEIGHT = 3'd7;

always @(posedge clk or negedge rst_n) begin : img_buf_ctrl
    if(!rst_n) begin
        img_sram_write_buf <= 0;
        img_sram_write_cnt <= 0;
    end else begin
        case(state)
        LOAD_NEW_IMG: begin
            if(i_valid && !img_input_done) begin
                img_sram_write_buf <= {img_sram_write_buf[503:0], i_data};
                if(img_sram_write_cnt == 6'd63) begin
                    img_sram_write_cnt <= 0;
                end else begin
                    img_sram_write_cnt <= img_sram_write_cnt + 1;
                end
            end
        end
        default: begin
            img_sram_write_buf <= img_sram_write_buf;
            img_sram_write_cnt <= 0;
        end
        endcase
    end
end

always @(posedge clk or negedge rst_n) begin : load_img_cmd_ctrl
    if(!rst_n) begin
        load_img_cmd <= `STANDBY;
    end else if(state == LOAD_NEW_IMG && i_valid && !img_input_done && img_sram_write_cnt == 6'd63) begin
        load_img_cmd <= `WRITE;
    end else begin
        load_img_cmd <= `STANDBY;
    end
end

always @(posedge clk or negedge rst_n) begin : load_img_addr_ctrl
    if(!rst_n) begin
        load_img_addr <= 0;
    end else begin
        case(state)
        LOAD_NEW_IMG: begin
            load_img_addr <= (load_img_cmd == `WRITE) ? load_img_addr + 1 : load_img_addr;
        end
        default: begin
            load_img_addr <= 0;
        end
        endcase
    end
end

endmodule

module TFBlock(
    clk,
    rst_n,
    input_valid,
    iter_cnt,
    // i_mode,
    input_data,
    i_weight,
    i_weight_valid,
    temp_write_valid,
    output_valid,
    output_data
);

input       clk, rst_n, input_valid;
input       [7:0] input_data;
input       [2:0] iter_cnt;
// input       [1:0] i_mode;
input       [3:0] i_weight;
input i_weight_valid;
input temp_write_valid;
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

// SRAM_WEIGHT IO
wire web_weight, oe_weight, cs_weight;
wire [127:0] dout_weight_raw;
// write counter and buffer for weight input (driven by WeightInputCtrl submodule)
// buffer the 32 weights for proj/ffn weight, and 18 weights for conv weight, then write to sram in one cycle when the buffer is full
wire [4:0] weight_sram_write_cnt; // count the number of weights currently in the buffer
wire [127:0] weight_sram_write_buf; // buffer for the weights to be written into sram, for conv weight, only the lower 72 bit are used
wire [127:0] weight_sram_read_buf;
wire weight_sram_read_valid;
wire weight_sram_write_valid;
reg weight_sram_read_req_sel;
reg weight_sram_write_req_sel;
reg [5:0] weight_sram_addr_sel;
reg [127:0] weight_sram_data_sel;
wire [5:0] weight_sram_A;
wire [2:0] weight_sram_cmd;
wire [127:0] weight_sram_DI;

// SRAM_WEIGHT_IO for weight loading phase (driven by WeightInputCtrl submodule), shared by both conv and proj/ffn weight loading
wire [2:0] load_weight_cmd;
wire [5:0] load_weight_addr;

// SRAM_IMG IO
wire web_img, oe_img, cs_img;
wire [2:0] img_sram_cmd;
wire [511:0] dout_img_raw;
wire [511:0] img_sram_DI;
wire [511:0] img_sram_read_buf;
wire img_sram_read_valid;
wire img_sram_write_valid;
wire [5:0] img_sram_A;
reg img_sram_read_req_sel;
reg img_sram_write_req_sel;
reg [5:0] img_sram_addr_sel;
reg [511:0] img_sram_data_sel;

// SRAM_IMG_IO for input loading phase (driven by ImgInputCtrl)
wire [511:0] img_sram_write_buf;
wire [5:0] img_sram_write_cnt;
wire [2:0] load_img_cmd;
wire [5:0] load_img_addr;

// Wire declarations for ConvBlock outputs
wire [5:0] conv_img_read_addr;
wire conv_img_read_req;
wire [5:0] conv_weight_read_addr;
wire conv_weight_read_req;
wire [7:0] conv_temp_read_addr;
wire conv_temp_read_req;
wire [7:0] conv_temp_write_addr;
wire conv_temp_write_req;
wire [127:0] conv_temp_write_data;

// conv block control signals
wire conv_en, conv_is_us;
wire us_out_valid;
wire [127:0] ds_out_data;
wire [7:0] us_out_data;
wire ds_conv_done;

//SRAM_TEMP IO
wire [7:0] temp_addr;
wire temp_web, temp_oe, temp_cs;
reg [127:0] temp_sram_write_buf;
wire [127:0] temp_sram_read_buf;
wire [127:0] temp_dout, temp_din;
wire [2:0] temp_sram_cmd;
wire temp_sram_read_valid;
wire temp_r_buf_capture;
wire [5:0] temp_sram_read_A;
wire [2:0] temp_sram_read_cmd;
reg [7:0] temp_sram_addr_sel;
reg [127:0] temp_sram_data_sel;
reg temp_sram_read_req_sel;
reg temp_sram_write_req_sel;
wire temp_sram_write_valid;
reg conv_temp_write_valid_mux;
reg tf_temp_write_valid_mux;

assign {cs_img, web_img, oe_img} = img_sram_cmd;

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
            if (ds_conv_done) nxt_state = QKV_PROJ;
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
    .A(img_sram_A),
    .Dout_bus(dout_img_raw),
    .Din_bus(img_sram_DI),
    .clk(clk),
    .WEB(web_img),
    .OE(oe_img),
    .CS(cs_img)
);

always @(*) begin : sram_img_cmd_addr_data_select
    case(state)
    LOAD_NEW_IMG:begin
        img_sram_addr_sel = load_img_addr;
        img_sram_data_sel = img_sram_write_buf;
        img_sram_read_req_sel = 1'b0;
        img_sram_write_req_sel = (load_img_cmd == `WRITE);
    end
    DS_CONV:begin
        img_sram_addr_sel = conv_img_read_addr;
        img_sram_data_sel = img_sram_write_buf;
        img_sram_read_req_sel = conv_img_read_req;
        img_sram_write_req_sel = 1'b0;
    end
    default:begin
        img_sram_addr_sel = 0;
        img_sram_data_sel = img_sram_write_buf;
        img_sram_read_req_sel = 1'b0;
        img_sram_write_req_sel = 1'b0;
    end
    endcase
end

SRAM_CTRL #(
    .WORD_LEN(512),
    .ADDR_LEN(6)
) sram_img_ctrl (
    .clk(clk),
    .rst_n(rst_n),
    .addr(img_sram_addr_sel),
    .data_in(img_sram_data_sel),
    .read_req(img_sram_read_req_sel),
    .write_req(img_sram_write_req_sel),
    .sram_DO(dout_img_raw),
    .read_valid(img_sram_read_valid),
    .write_valid(img_sram_write_valid),
    .data_out(img_sram_read_buf),
    .sram_A(img_sram_A),
    .sram_cmd(img_sram_cmd),
    .sram_DI(img_sram_DI)
);

ImgInputCtrl img_input_ctrl(
    .clk(clk),
    .rst_n(rst_n),
    .state(state),
    .i_valid(i_valid),
    .i_data(i_data),
    .img_input_done(img_input_done),
    .img_sram_write_buf(img_sram_write_buf),
    .img_sram_write_cnt(img_sram_write_cnt),
    .load_img_cmd(load_img_cmd),
    .load_img_addr(load_img_addr)
);

always @(*) begin : sram_weight_cmd_addr_data_select
    case(state)
    LOAD_US_CONV_WEIGHT,
    LOAD_PROJ_WEIGHT,
    LOAD_DS_CONV_WEIGHT: begin
        weight_sram_addr_sel = load_weight_addr;
        weight_sram_data_sel = weight_sram_write_buf;
        weight_sram_read_req_sel = 1'b0;
        weight_sram_write_req_sel = (load_weight_cmd == `WRITE);
    end
    DS_CONV: begin
        weight_sram_addr_sel = conv_weight_read_addr;
        weight_sram_data_sel = weight_sram_write_buf;
        weight_sram_read_req_sel = conv_weight_read_req;
        weight_sram_write_req_sel = 1'b0;
    end
    default: begin
        weight_sram_addr_sel = 0;
        weight_sram_data_sel = weight_sram_write_buf;
        weight_sram_read_req_sel = 1'b0;
        weight_sram_write_req_sel = 1'b0;
    end
    endcase
end

SRAM_CTRL #(
    .WORD_LEN(128),
    .ADDR_LEN(6)
) sram_weight_ctrl (
    .clk(clk),
    .rst_n(rst_n),
    .addr(weight_sram_addr_sel),
    .data_in(weight_sram_data_sel),
    .read_req(weight_sram_read_req_sel),
    .write_req(weight_sram_write_req_sel),
    .sram_DO(dout_weight_raw),
    .read_valid(weight_sram_read_valid),
    .write_valid(weight_sram_write_valid),
    .data_out(weight_sram_read_buf),
    .sram_A(weight_sram_A),
    .sram_cmd(weight_sram_cmd),
    .sram_DI(weight_sram_DI)
);

SRAM64x128_WRAP sram_weight (
    .A(weight_sram_A),
    .Dout(dout_weight_raw),
    .Din(weight_sram_DI),
    .clk(clk),
    .WEB(web_weight),
    .OE(oe_weight),
    .CS(cs_weight)
);

assign {cs_weight, web_weight, oe_weight} = weight_sram_cmd;

// Instantiate weight input control submodule
WeightInputCtrl weight_input_ctrl(
    .clk(clk),
    .rst_n(rst_n),
    .state(state),
    .i_valid(i_valid),
    .i_weight(i_weight),
    .weight_input_done(weight_input_done),
    .write_threshold(write_threshold),
    .weight_sram_write_buf(weight_sram_write_buf),
    .weight_sram_write_cnt(weight_sram_write_cnt),
    .load_weight_cmd(load_weight_cmd),
    .load_weight_addr(load_weight_addr)
);

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
            img_input_done <= img_input_done || ((state == LOAD_NEW_IMG) && img_sram_write_valid && (img_sram_A == 6'd63));
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

always @(*) begin : sram_temp_cmd_addr_select
    case(state)
    DS_CONV: begin
        temp_sram_addr_sel = conv_temp_write_addr;
        temp_sram_data_sel = ds_out_data;
        temp_sram_read_req_sel = 1'b0;
        temp_sram_write_req_sel = conv_temp_write_req;
    end
    US_CONV_UPDATE_IMG: begin
        temp_sram_addr_sel = conv_temp_read_addr;
        temp_sram_data_sel = 128'd0;
        temp_sram_read_req_sel = conv_temp_read_req;
        temp_sram_write_req_sel = 1'b0;
    end
    default: begin
        temp_sram_addr_sel = 0;
        temp_sram_data_sel = 128'd0;
        temp_sram_read_req_sel = 1'b0;
        temp_sram_write_req_sel = 1'b0;
    end
    endcase
end

always @(*) begin : sram_write_valid_distribution
    conv_temp_write_valid_mux = 1'b0;
    tf_temp_write_valid_mux = 1'b0;

    case(state)
    DS_CONV,
    US_CONV_UPDATE_IMG: begin
        conv_temp_write_valid_mux = temp_sram_write_valid;
    end
    QKV_PROJ,
    CALC_ATTN: begin
        tf_temp_write_valid_mux = temp_sram_write_valid;
    end
    default: begin
        conv_temp_write_valid_mux = 1'b0;
        tf_temp_write_valid_mux = 1'b0;
    end
    endcase
end

SRAM_CTRL #(
    .WORD_LEN(128),
    .ADDR_LEN(8)
) sram_temp_ctrl (
    .clk(clk),
    .rst_n(rst_n),
    .addr(temp_sram_addr_sel),
    .data_in(temp_sram_data_sel),
    .read_req(temp_sram_read_req_sel),
    .write_req(temp_sram_write_req_sel),
    .sram_DO(temp_dout),
    .read_valid(temp_sram_read_valid),
    .write_valid(temp_sram_write_valid),
    .data_out(temp_sram_read_buf),
    .sram_A(temp_addr),
    .sram_cmd(temp_sram_cmd),
    .sram_DI(temp_din)
);

SRAM256x128_WRAP sram_temp (
    .A(temp_addr),
    .Dout(temp_dout),
    .Din(temp_din),
    .clk(clk),
    .WEB(temp_web),
    .OE(temp_oe),
    .CS(temp_cs)
);

assign {temp_cs, temp_web, temp_oe} = temp_sram_cmd;

ConvBlock conv_blk(
    .clk(clk),
    .rst_n(rst_n),
    .is_us_conv(state==US_CONV_UPDATE_IMG), // only when the interpolate mode is 2 (us_conv) we set is_us_conv to 1
    .en((state == DS_CONV) || (state == US_CONV_UPDATE_IMG)), // enable the conv block when we are in ds_conv or in us_conv_update_img with us_conv mode
    .img_read_addr(conv_img_read_addr),
    .img_read_req(conv_img_read_req),
    .img_data_in(img_sram_read_buf),
    .img_read_valid(img_sram_read_valid),
    .weight_read_addr(conv_weight_read_addr),
    .weight_read_req(conv_weight_read_req),
    .weight_data_in(weight_sram_read_buf),
    .weight_read_valid(weight_sram_read_valid),
    .temp_data_in(temp_sram_read_buf),
    .temp_read_addr(conv_temp_read_addr),
    .temp_read_req(conv_temp_read_req),
    .temp_write_addr(conv_temp_write_addr),
    .temp_write_req(conv_temp_write_req),
    .temp_write_valid(conv_temp_write_valid_mux),
    .temp_read_valid(temp_sram_read_valid),
    .ds_conv_done(ds_conv_done),
    .us_out_valid(us_out_valid),
    .ds_out_data(ds_out_data),
    .us_out_data(us_out_data)
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
    .temp_write_valid(tf_temp_write_valid_mux),
    .output_valid(tf_out_valid),
    .output_data(o_data)
);
// assigned temporarily for simulation, will be replaced by the output valid signal from the transformer block
assign o_valid = tf_out_valid;

endmodule
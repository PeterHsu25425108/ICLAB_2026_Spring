// states
// `define 

// the mac tree for linear transformation operations, perform conventional MatMul
// here we just implement the arithmetics, the input multiplexing should be handled elsewhere
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
reg signed [15:0] sum_level4; // final sum of 16 products
wire signed [16:0] adder_out;
wire signed [12:0] shift_out;// (x >>> 4)
wire signed [7:0] clip_out;

// valid chain
parameter STAGE_CNT = 4;
reg valid_chain[STAGE_CNT-1:0]; // a chain of valid signals for pipelining, valid_chain[0] is the input valid, valid_chain[4] is the output valid
assign output_valid = valid_chain[STAGE_CNT-1];

genvar i;

generate
    for(i=0;i<16;i=i+1) begin
        always @(posedge clk or negedge rst_n) begin : mult_input_logic
            if(!rst_n) begin
                    mat_row_a[i] <= 0;
                    mat_row_b[i] <= 0;
            end else if(input_valid) begin
                    mat_row_a[i] <= a_row_word[8*i+7:8*i] & {8{input_valid}};
                    mat_row_b[i] <= b_row_word[4*i+3:4*i] & {4{input_valid}};
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
            end else if(input_valid) begin
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
            end else if(input_valid) begin
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
            end else if(input_valid) begin
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
            end else if(input_valid) begin
                sum_level3[i] <= sum_level2[2*i] + sum_level2[2*i+1];
            end
        end
    end
endgenerate

// at the last adder stage, normalization and clipping are also performed to fit the output back to 8 bit
assign adder_out = sum_level3[0] + sum_level3[1];
assign shift_out = adder_out >>> 4; // right shift by 4 to normalize the output back to 8 bit, can be adjusted according to the actual value range of the output
assign clip_out = (shift_out > 127) ? 127 : (shift_out < -128) ? -128 : shift_out;

generate
    for(i=0;i<STAGE_CNT;i=i+1) begin : valid_chain_logic
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) begin
                valid_chain[i] <= 0;
            end else if(i == 0) begin
                valid_chain[i] <= input_valid;
            end else begin
                valid_chain[i] <= valid_chain[i-1];
            end
        end
    end
endgenerate

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

reg [2:0] iter_counter; // records the number of remaining diff iterations to perform
// telling iter_counter that the transformer block has completed operations, and it can decrement itself
// !!: tf_out_valid should only rise when iter_counter > 0, watch out when driving tf_out_valid in the transformer block modules
wire tf_out_valid; 

reg [1:0] interpolate_mode; // mode of interpolation
reg [11:0] main_counter; // records the number of inputs

reg weight_input_done;

// ffs stroing weights
// reg signed [3:0] ds_conv_weight;

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

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        weight_input_done <= 0;
        interpolate_mode <= 0;
        iter_counter <= 0;
    end else begin
        weight_input_done <= (weight_input_done || (!i_valid && main_counter >= 1311));

        interpolate_mode <= (main_counter == 0 && i_valid && weight_input_done) ? i_iter : interpolate_mode;

        if(main_counter == 0 && i_valid && weight_input_done) begin
            iter_counter <= i_iter;
        end else begin
            iter_counter <= (tf_out_valid && iter_counter > 0) ? iter_counter - 1 : iter_counter;
        end
    end
end


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
module ConvBlock(
    clk,
    rst_n,
    up_sample, // indicate if we are using this mod as an up-sampling conv, driven by the top module
    input_valid,
    iter_cnt,
    // i_mode,
    input_data,
    i_weight,
    us_weight_valid,
    ds_weight_valid,
    output_valid,
    output_data
);
input       clk, rst_n, input_valid;
reg signed [3:0] us_weight [0:8];
reg signed [3:0] ds_weight [0:8];

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
    output_valid,
    output_data
);

input       clk, rst_n, input_valid;
input       [] input_data;
input       [2:0] iter_cnt;
input       [1:0] i_mode;
input       [3:0] i_weight;
output reg  output_valid;
output reg  [] output_data;

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
output reg  o_valid;
output reg  [7:0] o_data;

reg [2:0] iter_counter; // records the number of remaining diff iterations to perform
// telling iter_counter that the transformer block has completed operations, and it can decrement itself
// !!: tf_out_valid should only rise when iter_counter > 0, watch out when driving tf_out_valid in the transformer block modules
wire tf_out_valid; 

reg [1:0] interpolate_mode; // mode of interpolation
reg [10:0] main_counter; // records the number of inputs

reg weight_input_done;

// ffs stroing weights
// reg signed [3:0] ds_conv_weight;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        main_counter <= 0;
    end else begin
        // if(!o_valid) begin
        //     main_counter <= i_valid ? main_counter + 1 : main_counter;
        // end else begin // reset when the output is sent
        //     main_counter <= 0;
        // end
        main_counter <= i_valid ? main_counter + 1 : 0;
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        weight_input_done <= 0;
        interpolate_mode <= 0;
        iter_counter <= 0;
    end else begin
        weight_input_done <= (weight_input_done || (i_valid && main_counter >= 1312-1));
        interpolate_mode <= (main_counter == 0 && i_valid) ? i_iter : interpolate_mode;
        if(main_counter == 0 && i_valid) begin
            iter_counter <= i_iter;
        end else begin
            iter_counter <= (tf_out_valid && iter_counter > 0) ? iter_counter - 1 : iter_counter;
        end
    end
end

// TFBlock tf_blk(
//     .clk(clk),
//     .rst_n(rst_n),
//     .input_valid(i_valid && weight_input_done), // start feeding data after weights are inputted
//     .iter_cnt(iter_counter),
//     .i_mode(interpolate_mode),
//     .input_data(i_data),
//     .i_weight(i_weight),
//     .output_valid(tf_out_valid),
//     .output_data(o_data)
// );

endmodule
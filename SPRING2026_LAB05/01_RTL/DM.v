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
// reg signed [3:0] us_weight [0:8];
// reg signed [3:0] ds_weight [0:8];

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
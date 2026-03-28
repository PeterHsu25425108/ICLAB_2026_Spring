// Weights of all conv/deconv in this design are of the same dimensions
// IN_WID varies
// ch = 2
// kernel width = 3
// stride = 1
// module Conv2d #(parameter IN_WID= 8)(
//     clk,
//     rst_n,
//     in_data,
//     out_data,
//     weight, // weights have been pre-stored in Conv0/1_weight or DeConv0/1_weight
//     pad_mode,
//     input_valid, // high when a nex input pixel is sent
//     output_valid, // notify the later stages a new pixel is being sent
//     done // sent 
// );
// input clk, rst_n;
// input input_valid;
// input [31:0] in_data;
// input [31:0] weight[0:35];
// input pad_mode;

// output [31:0] out_data;
// output output_valid, done;

// endmodule

// module MaxPool#(parameter IN_WID= 8)(
//     clk,
//     rst_n,
//     in_data,
//     out_data,
//     input_valid, // high when a nex input pixel is sent
//     output_valid, // notify the later stages a new pixel is being sent
//     done // sent 
// );

// endmodule

// module UnPool#(parameter IN_WID= 8)(
//     clk,
//     rst_n,
//     in_data,
//     out_data,
//     input_valid, // high when a next input pixel is sent
//     output_valid, // notify the later stages a new pixel is being sent
//     done // sent 
// );

// endmodule

// module ActFunc#(parameter IN_WID= 8)(
//     clk,
//     rst_n,
//     in_data,
//     out_data,
//     input_valid, // high when a nex input pixel is sent
//     output_valid, // notify the later stages a new pixel is being sent
//     done // sent 
// );

// endmodule

module PreProcess (
    // input
    input clk,
    input rst_n,
    input image_in_valid,
    input [31:0] in_data,
    output [31:0] out_data,
    // output 
    output output_valid,
    output reg done
);

// Image storage moved from CDNA
reg [31:0] in_image[0:127];
integer i;

// incre when imag_in_valid == 1
reg [6:0] preproc_counter;

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
assign ch_allset = (preproc_counter == 63) | (preproc_counter == 127) && image_in_valid;
// first pixel logic
assign first_pixel = (preproc_counter == 0) | (preproc_counter == 64) && image_in_valid;
// current channel logic
assign curr_ch = preproc_counter[6];

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


// max/min updated everytime a new pixel comes
always @(posedge clk or negedge rst_n) begin : valid_propagate
    if(!rst_n) begin
        valid_chain <= 0;
    end
    else begin
        valid_chain[0] <= ch_allset;
        for(i=1; i<4; i=i+1) begin
            valid_chain[i] <= valid_chain[i-1];
        end
    end
end
assign output_valid = valid_chain[3];

always @(posedge clk or negedge rst_n) begin : preproc_counter_logic
    if(!rst_n) begin
        preproc_counter <= 0;
    end
    else begin
        preproc_counter <= image_in_valid ? preproc_counter + 1 : preproc_counter;
    end
end

// Image input logic moved from CDNA
always @(posedge clk or negedge rst_n) begin : image_input_block
    if(!rst_n) begin
        for(i=0; i<128; i=i+1) begin
            in_image[i] <= 0;
        end
    end
    else begin
        if(image_in_valid) begin
            in_image[127] <= in_data;
            for(i=0; i<127; i=i+1) begin
                in_image[i] <= in_image[i+1];
            end
        end
    end
end

// Min-Max Scaling preprocessing logic to be added here

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

reg [31:0] Conv0_weight[35:0];
reg [31:0] Conv1_weight[35:0];
reg [31:0] DeConv0_weight[35:0];
reg [31:0] DeConv1_weight[35:0];

integer i;

// main counter
reg [8:0] main_counter;

always @(posedge clk or negedge rst_n) begin : main_cnt_logic
    if(!rst_n) begin
        main_counter <= 0;
    end
    else begin
        main_counter <= (image_in_valid || instruction_in_valid || weight_in_valid) ?
                        main_counter + 1 : main_counter;
    end
end

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

always @(posedge clk or negedge rst_n) begin : weight_input_block
    if(!rst_n) begin
        for(i=0; i<36; i=i+1) begin
            Conv0_weight[i] <= 0;
            Conv1_weight[i] <= 0;
            DeConv0_weight[i] <= 0;
            DeConv1_weight[i] <= 0;
        end
    end
    else begin
        // raster scan order
        if(weight_in_valid) begin
            DeConv1_weight[35] <= in_data;
            DeConv0_weight[35] <= DeConv1_weight[0];
            Conv1_weight[35] <= DeConv0_weight[0];
            Conv0_weight[35] <= Conv1_weight[0];
            // Conv0
            for(i=0; i<35; i=i+1) begin
                Conv0_weight[i] <= Conv0_weight[i+1];
                Conv1_weight[i] <= Conv1_weight[i+1];
                DeConv0_weight[i] <= DeConv0_weight[i+1];
                DeConv1_weight[i] <= DeConv1_weight[i+1];
            end
        end
    end
end

// ================== Module Instantiations =================
wire [31:0] pre_out_data;
wire pre_out_valid;
wire pre_done;

PreProcess u_PreProcess (
    .clk(clk),
    .rst_n(rst_n),
    .image_in_valid(image_in_valid),
    .in_data(in_data),
    .out_data(pre_out_data),
    .output_valid(pre_out_valid),
    .done(pre_done)
);

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
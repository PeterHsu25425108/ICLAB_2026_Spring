// Weights of all conv/deconv in this design are of the same dimensions
// in_img width varies
// ch = 2
// kernel width = 3
// stride = 1
module Conv2d #(parameter IN_WID= 8)(
    clk,
    rst_n,
    in_img,
    out_img,
    weight,
    pad_mode,
    input_valid, // high when a nex input pixel is sent
    output_valid, // notify the later stages a new pixel is being sent
    done // sent 
);
input clk, rst_n;
input input_valid;
input [31:0] in_img[0:2*IN_WID*IN_WID-1];
input [31:0] weight[0:35];
input pad_mode;

output [31:0] out_img[0:2*IN_WID*IN_WID-1];
output output_valid, done;

endmodule

module MaxPool#(parameter IN_WID= 8)(
    clk,
    rst_n,
    in_img,
    out_img,
    input_valid, // high when a nex input pixel is sent
    output_valid, // notify the later stages a new pixel is being sent
    done // sent 
);

endmodule

module UnPool#(parameter IN_WID= 8)(
    clk,
    rst_n,
    in_img,
    out_img,
    input_valid, // high when a nex input pixel is sent
    output_valid, // notify the later stages a new pixel is being sent
    done // sent 
);

endmodule

module ActFunc#(parameter IN_WID= 8)(
    clk,
    rst_n,
    in_img,
    out_img,
    input_valid, // high when a nex input pixel is sent
    output_valid, // notify the later stages a new pixel is being sent
    done // sent 
);

endmodule

module CDNA(
    // Input Port
    clk,
    rst_n,
    instruction_in_valid,
    image_in_valid,
    weight_in_valid,
    in_data
    
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
reg [31:0] in_image[128];
integer i;

// main counter
// instruction: 1
// weight: 144
// image: 128
reg [8:0] main_counter;

always @(posedge clk or negedge rst_n) begin : main_cnt_logic
    if(!rst_n) begin
        main_counter <= 0;
    end
    else begin
        main_counter <= (image_in_valid || instruction_in_valid || weight_in_valid) ? main_counter + 1 : main_counter;
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
        Conv0_weight <= 0;
        Conv1_weight <= 0;
        DeConv0_weight <= 0;
        DeConv1_weight <= 0;
    end
    else begin
        // raster scan order
        if(weight_in_valid) begin
            DeConv1_weight[35] <= in_data;
            DeConv0_weight[35] <= DeConv1_weight[0];
            Conv1_weight[35] <= DeConv0_weight[0];
            Conv0_weight[35] <= Conv1_weight[0];
            // Conv0
            for(i=0;i<35;i=i+1) begin
                Conv0_weight[i] <= Conv0_weight[i+1];
                Conv1_weight[i] <= Conv1_weight[i+1];
                DeConv0_weight[i] <= DeConv0_weight[i+1];
                DeConv1_weight[i] <= DeConv1_weight[i+1];
            end
        end
    end
end

always @(posedge clk or negedge rst_n) begin : image_input_block
    if(!rst_n) begin
        in_image <= 0;
    end
    else begin
        if(image_in_valid) begin
            in_image[127] <= in_data;
            for(i=0;i<127;i=i+1) begin
                in_image[i] <= in_image[i+1];
            end
        end
    end
    
end

//Example DW code
//DW_fp_add #(inst_sig_width, inst_exp_width ,inst_ieee_compliance, inst_arch_type, inst_arch, inst_faithful_round) u_add(.a(add_in_a), .b(add_in_b), .z(add_out), .status(add_status), .rnd(rnd));
//Example DW code

endmodule
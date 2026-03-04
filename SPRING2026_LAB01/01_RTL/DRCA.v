module DRCA (
    input [3:0]  drc_sel,
    input [18:0] shape0 ,
    input [18:0] shape1 ,
    input [18:0] shape2 ,
    input [18:0] shape3 ,
    input [18:0] shape4 ,
    input [18:0] shape5 ,
    input [18:0] shape6 ,
    input [18:0] shape7 ,
    input [18:0] shape8 ,
    input [18:0] shape9 ,
    input [18:0] shape10 ,
    input [18:0] shape11 ,
    input [18:0] shape12 ,
    input [18:0] shape13 ,
    input [18:0] shape14 ,
    input [18:0] shape15 ,
    output [4:0] drc_out
);


//**************************************************
// Parameter 
//**************************************************
// Rule type for rule_layer
`define CONTACT 3'd0
`define DIFF 3'd1
`define POLY 3'd2
`define M1 3'd3
`define NP 3'd4
`define PP 3'd5
`define NW 3'd6

//**************************************************
// Reg & Wire 
//**************************************************
wire [2:0] shape_type [0:15];
wire [3:0] llx [0:15];
wire [3:0] lly [0:15];
wire [3:0] urx [0:15];
wire [3:0] ury [0:15];
wire rule_type; // 0: width, 1: spacing
wire [2:0] rule_layer; // 3'd0: contact, 3'd1: diff, 3'd2: poly, 3'd3: m1, 3'd4: np, 3'd5: pp, 3'd6: nw

//**************************************************
// Design 
//**************************************************
// unpack input shapes
genvar i;
generate
    for (i = 0; i < 16; i = i + 1) begin : unpack_shapes
        assign shape_type[i] = (i == 0) ? shape0[18:16] :
                               (i == 1) ? shape1[18:16] :
                               (i == 2) ? shape2[18:16] :
                               (i == 3) ? shape3[18:16] :
                               (i == 4) ? shape4[18:16] :
                               (i == 5) ? shape5[18:16] :
                               (i == 6) ? shape6[18:16] :
                               (i == 7) ? shape7[18:16] :
                               (i == 8) ? shape8[18:16] :
                               (i == 9) ? shape9[18:16] :
                               (i == 10) ? shape10[18:16] :
                               (i == 11) ? shape11[18:16] :
                               (i == 12) ? shape12[18:16] :
                               (i == 13) ? shape13[18:16] :
                               (i == 14) ? shape14[18:16] :
                                            shape15[18:16];
        assign llx[i] = (i == 0) ? shape0[15:12] :
                        (i == 1) ? shape1[15:12] :
                        (i == 2) ? shape2[15:12] :
                        (i == 3) ? shape3[15:12] :
                        (i == 4) ? shape4[15:12] :
                        (i == 5) ? shape5[15:12] :
                        (i == 6) ? shape6[15:12] :
                        (i == 7) ? shape7[15:12] :
                        (i == 8) ? shape8[15:12] :
                        (i == 9) ? shape9[15:12] :
                        (i == 10) ? shape10[15:12] :
                        (i == 11) ? shape11[15:12] :
                        (i == 12) ? shape12[15:12] :
                        (i == 13) ? shape13[15:12] :
                        (i == 14) ? shape14[15:12] :
                                     shape15[15:12];
        assign lly[i] = (i == 0) ? shape0[11:8] :
                        (i == 1) ? shape1[11:8] :
                        (i == 2) ? shape2[11:8] :
                        (i == 3) ? shape3[11:8] :       
                        (i == 4) ? shape4[11:8] :
                        (i == 5) ? shape5[11:8] :
                        (i == 6) ? shape6[11:8] :
                        (i == 7) ? shape7[11:8] :
                        (i == 8) ? shape8[11:8] :
                        (i == 9) ? shape9[11:8] :
                        (i == 10) ? shape10[11:8] :
                        (i == 11) ? shape11[11:8] :
                        (i == 12) ? shape12[11:8] :
                        (i == 13) ? shape13[11:8] :
                        (i == 14) ? shape14[11:8] :
                                     shape15[11:8];
        assign urx[i] = (i == 0) ? shape0[7:4] :
                        (i == 1) ? shape1[7:4] :
                        (i == 2) ? shape2[7:4] :
                        (i == 3) ? shape3[7:4] :
                        (i == 4) ? shape4[7:4] :
                        (i == 5) ? shape5[7:4] :
                        (i == 6) ? shape6[7:4] :
                        (i == 7) ? shape7[7:4] :
                        (i == 8) ? shape8[7:4] :
                        (i == 9) ? shape9[7:4] :
                        (i == 10) ? shape10[7:4] :
                        (i == 11) ? shape11[7:4] :
                        (i == 12) ? shape12[7:4] :
                        (i == 13) ? shape13[7:4] :
                        (i == 14) ? shape14[7:4] :
                                     shape15[7:4];
        assign ury[i] = (i == 0) ? shape0[3:0] :
                        (i == 1) ? shape1[3:0] :
                        (i == 2) ? shape2[3:0] :
                        (i == 3) ? shape3[3:0] :
                        (i == 4) ? shape4[3:0] :
                        (i == 5) ? shape5[3:0] :
                        (i == 6) ? shape6[3:0] :    
                        (i == 7) ? shape7[3:0] :
                        (i == 8) ? shape8[3:0] :
                        (i == 9) ? shape9[3:0] :
                        (i == 10) ? shape10[3:0] :
                        (i == 11) ? shape11[3:0] :
                        (i == 12) ? shape12[3:0] :
                        (i == 13) ? shape13[3:0] :
                        (i == 14) ? shape14[3:0] :
                                     shape15[3:0];
    end
endgenerate
// unpack DRC rule
assign rule_type = drc_sel[0]; // LSB indicates rule type
assign rule_layer = drc_sel[3:1]; // MSBs indicate layer for width/spacing rules

assign drc_out = 5'b0;

endmodule